-- modules/ui/menuBuilder.lua
-- A flexible menu building system with positioning support.
--
-- logical = true: this module assumes logical 640x360 coordinates (see
-- modules/ui/screen.lua) -- calculatePosition centers within Screen.getWidth/
-- Height, and every size below is a logical pixel count. States that opt into
-- Screen's canvas get pixel-perfect menus for free; states that have not
-- migrated yet (shopState, statsState -- units 6/8/9 are on those in
-- parallel) will see the menu positioned/sized for a 640x360 box inside their
-- real window. That mismatch is expected until those states migrate.

local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local Widgets = require("modules/ui/widgets")

local MenuBuilder = {}
MenuBuilder.__index = MenuBuilder

-- Menu item types
MenuBuilder.TYPE_BUTTON = "button"
MenuBuilder.TYPE_TOGGLE = "toggle"
MenuBuilder.TYPE_SLIDER = "slider"
MenuBuilder.TYPE_LABEL = "label"
MenuBuilder.TYPE_SUBMENU = "submenu"
MenuBuilder.TYPE_SEPARATOR = "separator"

local function graphicsAvailable()
    return love ~= nil and love.graphics ~= nil and not _G.HEADLESS
end

-- Create a new menu builder instance
function MenuBuilder.new(title, options)
    local self = setmetatable({}, MenuBuilder)

    self.title = title or ""
    self.items = {}
    self.currentSelection = 1
    self.scrollOffset = 0

    -- Position options
    self.position = {}

    -- Styling. Sizes are logical pixels; colors and fonts always come from
    -- Theme, never a raw literal passed in here. Legacy callers still pass
    -- color/pixel-size options (backgroundColor, titleFontSize, ...) from
    -- before this rebuild -- they are accepted but ignored, since the theme
    -- and widget vocabulary now own that decision everywhere.
    options = options or {}
    self.style = {
        titleRole      = options.titleRole or "heading",
        itemRole       = options.itemRole or "body",
        padding        = options.padding or Theme.spacing.md,
        itemHeight     = options.itemHeight or (Theme.fontSizes.body + Theme.spacing.md),
        itemSpacing    = options.itemSpacing or Theme.spacing.xs,
        separatorHeight = options.separatorHeight or Theme.spacing.sm,
        width          = options.width or 400,
    }

    -- How many logical pixels of item list are allowed before the menu has to
    -- scroll. Defaults to most of the logical screen height so a menu never
    -- clips content that would otherwise fit (see calculateHeight).
    self.viewportHeight = options.viewportHeight or math.max(
        self.style.itemHeight, Screen.getHeight() - Theme.spacing.xxl)

    -- Mouse interaction state.
    self._hoverIndex = nil
    self._pressedIndex = nil
    self._draggingIndex = nil
    self._layout = nil

    -- Input handling
    self.onConfirm = nil
    self.onBack = nil
    self.onClose = nil

    return self
end

-- Set the menu position explicitly
function MenuBuilder:setPosition(x, y)
    self.position.x = x
    self.position.y = y
    return self
end

-- Add a button to the menu
function MenuBuilder:addButton(label, callback, enabled)
    enabled = (enabled ~= false) -- Default to true if not specified
    table.insert(self.items, {
        type = MenuBuilder.TYPE_BUTTON,
        label = label,
        callback = callback,
        enabled = enabled
    })
    return self
end

-- Add a toggle option to the menu
function MenuBuilder:addToggle(label, value, callback, enabled)
    enabled = (enabled ~= false) -- Default to true if not specified
    table.insert(self.items, {
        type = MenuBuilder.TYPE_TOGGLE,
        label = label,
        value = value,
        callback = callback,
        enabled = enabled
    })
    return self
end

-- Add a slider option to the menu
function MenuBuilder:addSlider(label, value, min, max, step, callback, enabled)
    enabled = (enabled ~= false) -- Default to true if not specified
    step = step or 0.1
    table.insert(self.items, {
        type = MenuBuilder.TYPE_SLIDER,
        label = label,
        value = value,
        min = min,
        max = max,
        step = step,
        callback = callback,
        enabled = enabled,
        dragActive = false
    })
    return self
end

-- Add a label (non-selectable text)
function MenuBuilder:addLabel(text)
    table.insert(self.items, {
        type = MenuBuilder.TYPE_LABEL,
        label = text,
        enabled = false
    })
    return self
end

-- Add a submenu
function MenuBuilder:addSubmenu(label, submenuBuilder, callback)
    table.insert(self.items, {
        type = MenuBuilder.TYPE_SUBMENU,
        label = label,
        submenu = submenuBuilder,
        callback = callback,
        enabled = true
    })
    return self
end

-- Add a separator line. Separators are visually a hairline, not a full item
-- row -- see itemHeightFor / calculateHeight.
function MenuBuilder:addSeparator()
    table.insert(self.items, {
        type = MenuBuilder.TYPE_SEPARATOR,
        enabled = false
    })
    return self
end

-- Set callbacks for menu navigation
function MenuBuilder:setCallbacks(onConfirm, onBack, onClose)
    self.onConfirm = onConfirm
    self.onBack = onBack
    self.onClose = onClose
    return self
end

-- The real on-screen height of one item: separators are a hairline, not a
-- full row. This is what calculateHeight and the draw layout both use, so
-- they can never disagree about how tall the menu is.
function MenuBuilder:itemHeightFor(item)
    if item.type == MenuBuilder.TYPE_SEPARATOR then
        return self.style.separatorHeight
    end
    return self.style.itemHeight
end

-- How many items starting at startIndex fit within availableHeight, using
-- each item's real height. Always returns at least 1 if any item exists, so
-- a single oversized item still renders instead of vanishing.
function MenuBuilder:visibleCountFrom(startIndex, availableHeight)
    if startIndex > #self.items then return 0 end

    local height = 0
    local count = 0
    for i = startIndex, #self.items do
        local itemH = self:itemHeightFor(self.items[i])
        local addH = itemH + (count > 0 and self.style.itemSpacing or 0)
        if count > 0 and height + addH > availableHeight then break end
        height = height + addH
        count = count + 1
    end
    return math.max(count, 1)
end

-- Get the next selectable item index
function MenuBuilder:getNextSelectableIndex(current, direction)
    if #self.items == 0 then return current end

    local index = current
    repeat
        index = index + direction
        if index < 1 then
            index = #self.items
        elseif index > #self.items then
            index = 1
        end

        -- Prevent infinite loop if no selectable items
        if index == current then
            return current
        end
    until self.items[index] and self.items[index].enabled ~= false

    return index
end

-- Update menu navigation
function MenuBuilder:update(dt)
    -- Update any active animations or effects
end

-- Handle keyboard input
function MenuBuilder:keypressed(key)
    if key == "up" then
        self.currentSelection = self:getNextSelectableIndex(self.currentSelection, -1)
        if self.currentSelection < self.scrollOffset + 1 then
            self.scrollOffset = self.currentSelection - 1
        end
    elseif key == "down" then
        local visible = self:visibleCountFrom(self.scrollOffset + 1, self.viewportHeight)
        self.currentSelection = self:getNextSelectableIndex(self.currentSelection, 1)
        if self.currentSelection > self.scrollOffset + visible then
            self.scrollOffset = self.currentSelection - visible
        end
    elseif key == "left" then
        local item = self.items[self.currentSelection]
        if item and item.type == MenuBuilder.TYPE_SLIDER and item.enabled then
            item.value = Widgets.clampSliderValue(item.value - item.step, item.min, item.max, item.step)
            if item.callback then
                item.callback(item.value)
            end
        elseif item and item.type == MenuBuilder.TYPE_TOGGLE and item.enabled then
            item.value = not item.value
            if item.callback then
                item.callback(item.value)
            end
        end
    elseif key == "right" then
        local item = self.items[self.currentSelection]
        if item and item.type == MenuBuilder.TYPE_SLIDER and item.enabled then
            item.value = Widgets.clampSliderValue(item.value + item.step, item.min, item.max, item.step)
            if item.callback then
                item.callback(item.value)
            end
        elseif item and item.type == MenuBuilder.TYPE_TOGGLE and item.enabled then
            item.value = not item.value
            if item.callback then
                item.callback(item.value)
            end
        end
    elseif key == "return" or key == "kpenter" or key == "space" then
        local item = self.items[self.currentSelection]
        if not item or not item.enabled then
            return
        end

        if item.type == MenuBuilder.TYPE_BUTTON and item.callback then
            item.callback()
        elseif item.type == MenuBuilder.TYPE_TOGGLE then
            item.value = not item.value
            if item.callback then
                item.callback(item.value)
            end
        elseif item.type == MenuBuilder.TYPE_SUBMENU then
            if self.onConfirm then
                self.onConfirm(item)
            end
        end
    elseif key == "escape" or key == "backspace" then
        if self.onBack then
            self.onBack()
        elseif self.onClose then
            self.onClose()
        end
    end
end

-- Calculate x and y coordinates for menu rendering, in logical space.
function MenuBuilder:calculatePosition()
    if self.position.x and self.position.y then
        return self.position.x, self.position.y, self.style.width, self:calculateHeight()
    end

    local sw, sh = Screen.getWidth(), Screen.getHeight()
    local menuWidth = self.style.width
    local menuHeight = self:calculateHeight()

    local x = (sw - menuWidth) / 2
    local y = (sh - menuHeight) / 2

    return x, y, menuWidth, menuHeight
end

-- Calculate the total height of the menu from the real heights of whichever
-- items are currently in view (see visibleCountFrom / itemHeightFor).
function MenuBuilder:calculateHeight()
    local titleHeight = 0
    if self.title and #self.title > 0 then
        titleHeight = Theme.fontSizes[self.style.titleRole] + self.style.padding
    end

    local visibleCount = self:visibleCountFrom(self.scrollOffset + 1, self.viewportHeight)
    local contentHeight = 0
    for i = 1, visibleCount do
        local item = self.items[self.scrollOffset + i]
        if item then
            if i > 1 then contentHeight = contentHeight + self.style.itemSpacing end
            contentHeight = contentHeight + self:itemHeightFor(item)
        end
    end

    return self.style.padding * 2 + contentHeight + titleHeight
end

-- Build (or rebuild) the panel + per-item rects for the current scroll
-- position. Shared by draw() and every mouse handler so hit-testing can never
-- drift from what was actually drawn.
function MenuBuilder:computeLayout()
    local x, y, w, h = self:calculatePosition()

    local titleHeight = 0
    if self.title and #self.title > 0 then
        titleHeight = Theme.fontSizes[self.style.titleRole] + self.style.padding
    end

    local visibleCount = self:visibleCountFrom(self.scrollOffset + 1, self.viewportHeight)
    local rects = {}
    local itemY = y + self.style.padding + titleHeight

    for i = 1 + self.scrollOffset, math.min(#self.items, self.scrollOffset + visibleCount) do
        local item = self.items[i]
        local itemH = self:itemHeightFor(item)
        rects[#rects + 1] = {
            index = i,
            item = item,
            x = x + self.style.padding,
            y = itemY,
            w = w - self.style.padding * 2,
            h = itemH,
        }
        itemY = itemY + itemH + self.style.itemSpacing
    end

    self._layout = { x = x, y = y, w = w, h = h, titleHeight = titleHeight, rects = rects, visibleCount = visibleCount }
    self.maxVisible = visibleCount
    return self._layout
end

function MenuBuilder:rectForIndex(index, layout)
    layout = layout or self._layout
    if not layout then return nil end
    for _, rect in ipairs(layout.rects) do
        if rect.index == index then return rect end
    end
    return nil
end

-- Resolve the widget state (see Widgets.button) for one row: disabled beats
-- an active drag/press, which beats keyboard selection, which beats hover.
function MenuBuilder:stateFor(rect)
    local item = rect.item
    if item.enabled == false then return "disabled" end
    if self._pressedIndex == rect.index then return "pressed" end
    if self.currentSelection == rect.index then return "selected" end
    if self._hoverIndex == rect.index then return "hover" end
    return "normal"
end

-- Track rect for a slider row: label on the left ~40%, value text reserved on
-- the right, track fills the middle. Shared by drawing and drag math.
function MenuBuilder:sliderTrackRect(rect)
    local pad = self.style.padding
    local labelW = rect.w * 0.4
    local valueW = 50
    local trackX = rect.x + labelW
    local trackW = math.max(rect.w - labelW - valueW - pad, 10)
    local trackH = 6
    local trackY = rect.y + (rect.h - trackH) / 2
    return trackX, trackY, trackW, trackH
end

function MenuBuilder:drawItem(rect)
    local item = rect.item

    if item.type == MenuBuilder.TYPE_SEPARATOR then
        Theme.setColor("border")
        local ly = rect.y + rect.h / 2
        love.graphics.line(rect.x, ly, rect.x + rect.w, ly)
        return
    end

    if item.type == MenuBuilder.TYPE_LABEL then
        local ty = rect.y + (rect.h - Widgets.textHeight(self.style.itemRole)) / 2
        Widgets.label(rect.x, ty, rect.w, item.label or "", {
            role = self.style.itemRole, color = "textMuted", align = "left",
        })
        return
    end

    local state = self:stateFor(rect)
    local pad = self.style.padding

    if item.type == MenuBuilder.TYPE_BUTTON then
        Widgets.button(rect.x, rect.y, rect.w, rect.h, item.label or "", {
            state = state, role = self.style.itemRole,
        })
        return
    end

    -- Toggle / slider / submenu share a plain row background with custom
    -- label layout on top of it.
    Widgets.button(rect.x, rect.y, rect.w, rect.h, "", { state = state })

    local textColor = (item.enabled == false) and "textDim" or (state == "selected" and "base" or "text")
    local ty = rect.y + (rect.h - Widgets.textHeight(self.style.itemRole)) / 2

    if item.type == MenuBuilder.TYPE_TOGGLE then
        Widgets.label(rect.x + pad, ty, rect.w - pad * 2, item.label or "", {
            role = self.style.itemRole, color = textColor, align = "left",
        })
        Widgets.label(rect.x + pad, ty, rect.w - pad * 2, item.value and "ON" or "OFF", {
            role = self.style.itemRole, color = textColor, align = "right",
        })
    elseif item.type == MenuBuilder.TYPE_SLIDER then
        Widgets.label(rect.x + pad, ty, rect.w * 0.4 - pad, item.label or "", {
            role = self.style.itemRole, color = textColor, align = "left",
        })

        local trackX, trackY, trackW, trackH = self:sliderTrackRect(rect)
        Widgets.slider(trackX, trackY, trackW, item.value, item.min, item.max, {
            h = trackH,
            state = item.dragActive and "pressed" or (state == "hover" and "hover" or "normal"),
        })

        Widgets.label(rect.x, ty, rect.w - pad, string.format("%.1f", item.value), {
            role = self.style.itemRole, color = textColor, align = "right",
        })
    elseif item.type == MenuBuilder.TYPE_SUBMENU then
        Widgets.label(rect.x + pad, ty, rect.w - pad * 2, item.label or "", {
            role = self.style.itemRole, color = textColor, align = "left",
        })
        Widgets.label(rect.x + pad, ty, rect.w - pad * 2, ">", {
            role = self.style.itemRole, color = textColor, align = "right",
        })
    end
end

function MenuBuilder:drawScrollbar(layout)
    local total = #self.items
    local visible = layout.visibleCount
    if total <= visible then return end

    local trackX = layout.x + layout.w - self.style.padding
    local trackY = layout.y + self.style.padding
    local trackH = layout.h - self.style.padding * 2

    Theme.setColor("baseAlt")
    love.graphics.rectangle("fill", trackX, trackY, 3, trackH)

    local maxScroll = math.max(total - visible, 1)
    local thumbH = math.max(6, trackH * (visible / total))
    local thumbY = trackY + (trackH - thumbH) * (self.scrollOffset / maxScroll)

    Theme.setColor("borderLight")
    love.graphics.rectangle("fill", trackX, thumbY, 3, thumbH)
end

-- Draw the menu
function MenuBuilder:draw()
    if not graphicsAvailable() then return end

    local layout = self:computeLayout()

    Widgets.panel(layout.x, layout.y, layout.w, layout.h, { variant = "panel" })

    if self.title and #self.title > 0 then
        Widgets.label(layout.x + self.style.padding, layout.y + self.style.padding,
            layout.w - self.style.padding * 2, self.title, {
                align = "center", role = self.style.titleRole, color = "accent",
            })
    end

    for _, rect in ipairs(layout.rects) do
        self:drawItem(rect)
    end

    self:drawScrollbar(layout)
end

-- ---------------------------------------------------------------------------
-- Mouse support. Coordinates are logical (main.lua translates window mouse
-- events into logical space for states that set `logical = true`).

local function isInteractive(item)
    return item.enabled ~= false
        and item.type ~= MenuBuilder.TYPE_SEPARATOR
        and item.type ~= MenuBuilder.TYPE_LABEL
end

function MenuBuilder:mousemoved(x, y, dx, dy)
    local layout = self:computeLayout()
    self._hoverIndex = nil

    for _, rect in ipairs(layout.rects) do
        if isInteractive(rect.item) and Widgets.hit(x, y, rect.x, rect.y, rect.w, rect.h) then
            self._hoverIndex = rect.index
        end
    end

    if self._draggingIndex then
        local item = self.items[self._draggingIndex]
        local rect = self:rectForIndex(self._draggingIndex, layout)
        if item and rect and item.type == MenuBuilder.TYPE_SLIDER then
            local trackX, _, trackW = self:sliderTrackRect(rect)
            local newValue = Widgets.sliderValueFromX(x, trackX, trackW, item.min, item.max, item.step)
            if newValue ~= item.value then
                item.value = newValue
                if item.callback then item.callback(item.value) end
            end
        end
    end
end

function MenuBuilder:mousepressed(x, y, button)
    if button ~= 1 then return end
    local layout = self:computeLayout()
    self._pressedIndex = nil

    for _, rect in ipairs(layout.rects) do
        if isInteractive(rect.item) and Widgets.hit(x, y, rect.x, rect.y, rect.w, rect.h) then
            self.currentSelection = rect.index
            self._pressedIndex = rect.index
            self._hoverIndex = rect.index

            if rect.item.type == MenuBuilder.TYPE_SLIDER then
                rect.item.dragActive = true
                self._draggingIndex = rect.index
                local trackX, _, trackW = self:sliderTrackRect(rect)
                rect.item.value = Widgets.sliderValueFromX(x, trackX, trackW, rect.item.min, rect.item.max, rect.item.step)
                if rect.item.callback then rect.item.callback(rect.item.value) end
            end
            break
        end
    end
end

function MenuBuilder:mousereleased(x, y, button)
    if button ~= 1 then return end
    local layout = self:computeLayout()

    for _, item in ipairs(self.items) do
        if item.type == MenuBuilder.TYPE_SLIDER then
            item.dragActive = false
        end
    end
    self._draggingIndex = nil

    local pressedIndex = self._pressedIndex
    self._pressedIndex = nil
    if not pressedIndex then return end

    local rect = self:rectForIndex(pressedIndex, layout)
    if not rect or not Widgets.hit(x, y, rect.x, rect.y, rect.w, rect.h) then return end

    local item = rect.item
    if item.enabled == false then return end

    if item.type == MenuBuilder.TYPE_BUTTON and item.callback then
        item.callback()
    elseif item.type == MenuBuilder.TYPE_TOGGLE then
        item.value = not item.value
        if item.callback then item.callback(item.value) end
    elseif item.type == MenuBuilder.TYPE_SUBMENU then
        if self.onConfirm then self.onConfirm(item) end
    end
end

return MenuBuilder
