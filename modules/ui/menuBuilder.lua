-- modules/ui/menuBuilder.lua
-- A flexible menu building system with positioning support

local ResourceManager = require("engine/resourceManager")

local MenuBuilder = {}
MenuBuilder.__index = MenuBuilder

-- Menu item types
MenuBuilder.TYPE_BUTTON = "button"
MenuBuilder.TYPE_TOGGLE = "toggle"
MenuBuilder.TYPE_SLIDER = "slider"
MenuBuilder.TYPE_LABEL = "label"
MenuBuilder.TYPE_SUBMENU = "submenu"
MenuBuilder.TYPE_SEPARATOR = "separator"

-- Create a new menu builder instance
function MenuBuilder.new(title, options)
    local self = setmetatable({}, MenuBuilder)

    self.title = title or ""
    self.items = {}
    self.currentSelection = 1
    self.scrollOffset = 0
    self.maxVisible = 8

    -- Position options (new)
    self.position = {}

    -- Styling options
    options = options or {}
    self.style = {
        titleFont = options.titleFont or "default",
        titleFontSize = options.titleFontSize or 24,
        itemFont = options.itemFont or "default",
        itemFontSize = options.itemFontSize or 18,
        padding = options.padding or 20,
        itemHeight = options.itemHeight or 40,
        itemSpacing = options.itemSpacing or 10,
        backgroundColor = options.backgroundColor or {0.1, 0.1, 0.1, 0.9},
        titleColor = options.titleColor or {1, 1, 1, 1},
        itemColor = options.itemColor or {1, 1, 1, 1},
        selectedColor = options.selectedColor or {1, 1, 0, 1},
        disabledColor = options.disabledColor or {0.5, 0.5, 0.5, 1},
        separatorColor = options.separatorColor or {0.3, 0.3, 0.3, 1},
        roundedCorners = options.roundedCorners or 5,
        width = options.width or 400
    }

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

-- Add a separator line
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

-- Get the next selectable item index
function MenuBuilder:getNextSelectableIndex(current, direction)
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
    until self.items[index].enabled ~= false

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
        -- Adjust scroll if needed
        if self.currentSelection < self.scrollOffset + 1 then
            self.scrollOffset = self.currentSelection - 1
        end
    elseif key == "down" then
        self.currentSelection = self:getNextSelectableIndex(self.currentSelection, 1)
        -- Adjust scroll if needed
        if self.currentSelection > self.scrollOffset + self.maxVisible then
            self.scrollOffset = self.currentSelection - self.maxVisible
        end
    elseif key == "left" then
        local item = self.items[self.currentSelection]
        if item and item.type == MenuBuilder.TYPE_SLIDER and item.enabled then
            item.value = math.max(item.min, item.value - item.step)
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
            item.value = math.min(item.max, item.value + item.step)
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

-- Calculate x and y coordinates for menu rendering
function MenuBuilder:calculatePosition()
    -- If position is explicitly set, use it
    if self.position.x and self.position.y then
        return self.position.x, self.position.y, self.style.width, self:calculateHeight()
    end

    -- Otherwise, center the menu
    local sw, sh = love.graphics.getDimensions()
    local menuWidth = self.style.width
    local menuHeight = self:calculateHeight()

    -- Center the menu on screen
    local x = (sw - menuWidth) / 2
    local y = (sh - menuHeight) / 2

    return x, y, menuWidth, menuHeight
end

-- Calculate the total height of the menu
function MenuBuilder:calculateHeight()
    local visibleItems = math.min(#self.items, self.maxVisible)
    local titleHeight = (self.title and #self.title > 0) and (self.style.titleFontSize + self.style.padding) or 0

    return self.style.padding * 2 +
            self.style.itemHeight * visibleItems +
            self.style.itemSpacing * (visibleItems - 1) +
            titleHeight
end

-- Draw the menu
function MenuBuilder:draw()
    local x, y, menuWidth, menuHeight = self:calculatePosition()

    -- Draw menu background
    love.graphics.setColor(unpack(self.style.backgroundColor))
    love.graphics.rectangle("fill", x, y, menuWidth, menuHeight, self.style.roundedCorners, self.style.roundedCorners)

    -- Draw title if there is one
    if self.title and #self.title > 0 then
        local titleFont = ResourceManager:getFont(self.style.titleFont, self.style.titleFontSize)
        love.graphics.setFont(titleFont)
        love.graphics.setColor(unpack(self.style.titleColor))
        love.graphics.printf(self.title, x + self.style.padding, y + self.style.padding,
                menuWidth - self.style.padding * 2, "center")

        -- Adjust y position for items to come after title
        y = y + self.style.padding + self.style.titleFontSize
    end

    -- Draw menu items
    local itemFont = ResourceManager:getFont(self.style.itemFont, self.style.itemFontSize)
    love.graphics.setFont(itemFont)

    local itemY = y + self.style.padding

    for i = 1 + self.scrollOffset, math.min(#self.items, self.scrollOffset + self.maxVisible) do
        local item = self.items[i]

        -- Determine item color
        local itemColor
        if not item.enabled then
            itemColor = self.style.disabledColor
        elseif i == self.currentSelection then
            itemColor = self.style.selectedColor
        else
            itemColor = self.style.itemColor
        end

        -- Draw the item based on its type
        if item.type == MenuBuilder.TYPE_SEPARATOR then
            -- Draw a separator line
            love.graphics.setColor(unpack(self.style.separatorColor))
            love.graphics.line(x + self.style.padding, itemY + self.style.itemHeight / 2,
                    x + menuWidth - self.style.padding, itemY + self.style.itemHeight / 2)
        else
            -- Draw the item label
            love.graphics.setColor(unpack(itemColor))
            love.graphics.printf(item.label or "", x + self.style.padding, itemY + (self.style.itemHeight - itemFont:getHeight()) / 2,
                    menuWidth - self.style.padding * 2, "left")

            -- Draw additional elements based on type
            if item.type == MenuBuilder.TYPE_TOGGLE then
                local toggleText = item.value and "ON" or "OFF"
                love.graphics.printf(toggleText, x + self.style.padding, itemY + (self.style.itemHeight - itemFont:getHeight()) / 2,
                        menuWidth - self.style.padding * 2, "right")
            elseif item.type == MenuBuilder.TYPE_SLIDER then
                -- Draw slider track
                local sliderWidth = menuWidth / 3
                local sliderX = x + menuWidth - self.style.padding - sliderWidth
                local sliderY = itemY + self.style.itemHeight / 2

                -- Draw track
                love.graphics.setColor(0.3, 0.3, 0.3, 1)
                love.graphics.rectangle("fill", sliderX, sliderY - 2, sliderWidth, 4)

                -- Draw filled portion
                love.graphics.setColor(unpack(itemColor))
                local fillWidth = (item.value - item.min) / (item.max - item.min) * sliderWidth
                love.graphics.rectangle("fill", sliderX, sliderY - 2, fillWidth, 4)

                -- Draw handle
                love.graphics.circle("fill", sliderX + fillWidth, sliderY, 6)

                -- Draw value text
                local valueText = string.format("%.1f", item.value)
                love.graphics.printf(valueText, x + self.style.padding, itemY + (self.style.itemHeight - itemFont:getHeight()) / 2,
                        menuWidth - self.style.padding * 4 - sliderWidth, "right")
            elseif item.type == MenuBuilder.TYPE_SUBMENU then
                love.graphics.printf(">", x + self.style.padding, itemY + (self.style.itemHeight - itemFont:getHeight()) / 2,
                        menuWidth - self.style.padding * 2, "right")
            end
        end

        itemY = itemY + self.style.itemHeight + self.style.itemSpacing
    end

    -- Draw scrollbar if needed
    if #self.items > self.maxVisible then
        local scrollbarHeight = menuHeight - self.style.padding * 2
        local scrollbarThumbHeight = scrollbarHeight * (self.maxVisible / #self.items)
        local scrollbarThumbY = y + self.style.padding +
                (scrollbarHeight - scrollbarThumbHeight) * (self.scrollOffset / (#self.items - self.maxVisible))

        -- Draw scrollbar track
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + menuWidth - 10, y + self.style.padding,
                5, scrollbarHeight)

        -- Draw scrollbar thumb
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle("fill", x + menuWidth - 10, scrollbarThumbY, 5, scrollbarThumbHeight)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return MenuBuilder