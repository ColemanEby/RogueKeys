-- modules/keyboard/keyboardView.lua
-- Visual representation of the keyboard: lays out the current KeyboardModel's
-- layout and hands each key off to CapRenderer for the actual layered art
-- (switch housing -> keycap body -> legend -> effect overlay).
--
-- Coordinates: draw(x, y, scale) / getKeyAtPosition(x, y, baseX, baseY, scale)
-- treat x/y as whole pixels in whatever coordinate space the caller draws in
-- (the 640x360 logical canvas once the calling state opts in via
-- `logical = true`, window pixels otherwise -- see modules/ui/screen.lua).
-- Everything here is snapped to whole pixels and the keycap art is always
-- drawn at an integer multiple of its native 32px size; pixel art must never
-- be scaled by a fractional factor or it blurs.
--
-- Animation API -- nothing calls these yet; unit 15's typing trainer wires
-- them up to real key events:
--   view:activateKey(key)              key is held down right now
--   view:deactivateKey(key)            key was released
--   view:animateKeyPress(key, result)  momentary "was pressed" pulse.
--                                       result = nil | "correct" | "error":
--                                       always adds the 2px depress, and for
--                                       "correct"/"error" also a brief
--                                       colored glow ring.
--   view:setPreviewItem(item)          item = {key=, rarity=, capVariant=,
--                                       switchType=} or nil. Shows what that
--                                       key would look like with `item`
--                                       installed, e.g. while hovering a shop
--                                       offer, without touching the model.

local Theme = require("modules/ui/theme")
local CapRenderer = require("modules/keyboard/capRenderer")

local KeyboardView = {}
KeyboardView.__index = KeyboardView

local CAP_SIZE = CapRenderer.CAP_SIZE

-- Create a new keyboard view for the given keyboard model
function KeyboardView.new(keyboardModel)
    local self = setmetatable({}, KeyboardView)

    self.keyboardModel = keyboardModel
    self.layout = keyboardModel.layout

    self.activeKeys = {}   -- key -> true while physically held down
    self.animations = {}   -- {key=, type="press"|"correct"|"error", progress=, duration=}
    self.previewItem = nil -- {key=, rarity=, capVariant=, switchType=} or nil

    return self
end

-- Cross-unit note: modules/items/ (unit 13) may not exist in every worktree
-- yet. If the model exposes a per-key item, trust its rarity/capVariant/
-- switchType directly; otherwise fall back to the legacy upgrades-map float
-- and infer a rarity tier from its magnitude so an upgraded key still looks
-- distinct on old saves instead of rendering as a plain common cap.
local function bonusToRarity(bonus)
    if bonus >= 0.28 then return "legendary" end
    if bonus >= 0.20 then return "epic" end
    if bonus >= 0.12 then return "rare" end
    if bonus >= 0.05 then return "uncommon" end
    return "common"
end

function KeyboardView:resolveKeySpec(keyValue)
    local model = self.keyboardModel
    local isUpgraded = model:isKeyUpgraded(keyValue)
    local bonus = model:getKeyBonus(keyValue)

    local rarity, capVariant, switchType = "common", "plain", "linear"

    local item = nil
    if model.getKeyItem then
        local ok, result = pcall(model.getKeyItem, model, keyValue)
        if ok then item = result end
    end

    if item then
        rarity = item.rarity or rarity
        capVariant = item.capVariant or capVariant
        switchType = item.switchType or switchType
    elseif isUpgraded then
        rarity = bonusToRarity(bonus)
    end

    local isPreview = false
    if self.previewItem and self.previewItem.key == keyValue then
        isPreview = true
        rarity = self.previewItem.rarity or rarity
        capVariant = self.previewItem.capVariant or capVariant
        switchType = self.previewItem.switchType or switchType
    end

    return {
        rarity = rarity,
        capVariant = capVariant,
        switchType = switchType,
        bonus = bonus,
        isUpgraded = isUpgraded,
        isPreview = isPreview,
    }
end

-- Calculate keyboard layout geometry for a given draw origin/scale. Pure
-- math -- safe to call headless (used by getKeyAtPosition too).
function KeyboardView:calculateDimensions(x, y, scale)
    scale = scale or 1.0

    -- `scale` is an approximate target multiplier of the 32px native cap art
    -- (scale=1.0 -> capScale=2, the pack's intended "chunky 2x" look); round
    -- *down* to the nearest whole number so the art is never drawn at a
    -- fractional scale (which is what made the old 16px-on-45px sprites
    -- blurry) and so a caller passing a shrink factor below 1.0 -- still the
    -- common case until every caller has migrated to the logical canvas --
    -- gets a smaller, safer board rather than one rounded back up to 2x.
    local capScale = math.max(1, math.floor(scale * 2 + 1e-6))
    local keyUnit = CAP_SIZE * capScale
    local spacing = capScale

    local rowWidths = {}
    local totalWidth = 0
    for i, row in ipairs(self.layout) do
        local rowWidth = 0
        for _, keyData in ipairs(row) do
            rowWidth = rowWidth + keyUnit * (keyData.w or 1) + spacing
        end
        rowWidths[i] = rowWidth
        totalWidth = math.max(totalWidth, rowWidth)
    end

    local rowHeight = keyUnit + spacing
    local totalHeight = #self.layout * rowHeight

    return {
        x = math.floor(x),
        y = math.floor(y),
        width = totalWidth,
        height = totalHeight,
        rowWidths = rowWidths,
        rowHeight = rowHeight,
        capScale = capScale,
        keyUnit = keyUnit,
        spacing = spacing,
        scale = scale,
    }
end

-- Key is held down right now (physical depress, no timeout).
function KeyboardView:activateKey(key)
    key = string.lower(key)
    self.activeKeys[key] = true
end

function KeyboardView:deactivateKey(key)
    key = string.lower(key)
    self.activeKeys[key] = nil
end

-- Momentary press pulse. result = nil | "correct" | "error".
function KeyboardView:animateKeyPress(key, result)
    key = string.lower(key)
    table.insert(self.animations, { key = key, type = "press", progress = 0, duration = 0.12 })
    if result == "correct" or result == "error" then
        table.insert(self.animations, { key = key, type = result, progress = 0, duration = 0.35 })
    end
end

-- Live-preview an item on its target key (e.g. a hovered shop offer) without
-- touching the model. Pass nil to clear.
function KeyboardView:setPreviewItem(item)
    if not item or not item.key then
        self.previewItem = nil
        return
    end
    self.previewItem = {
        key = string.lower(item.key),
        rarity = item.rarity,
        capVariant = item.capVariant,
        switchType = item.switchType,
    }
end

function KeyboardView:update(dt)
    for i = #self.animations, 1, -1 do
        local anim = self.animations[i]
        anim.progress = anim.progress + dt
        if anim.progress >= anim.duration then
            table.remove(self.animations, i)
        end
    end
end

-- Draw the keyboard at the specified position with optional scaling.
function KeyboardView:draw(x, y, scale)
    if _G.HEADLESS or not love.graphics then return end

    local dims = self:calculateDimensions(x, y, scale)

    Theme.setColor("panel", 0.9)
    love.graphics.rectangle("fill",
        dims.x - dims.spacing * 2, dims.y - dims.spacing * 2,
        dims.width + dims.spacing * 4, dims.height + dims.spacing * 4)

    local font = Theme.font("small")
    if font then love.graphics.setFont(font) end

    local rowY = dims.y
    for i, row in ipairs(self.layout) do
        local rowX = dims.x + math.floor((dims.width - dims.rowWidths[i]) / 2)

        for _, keyData in ipairs(row) do
            local keyDisplay = keyData.key
            local keyValue = string.lower(keyDisplay)
            if keyDisplay == "Space" then keyValue = " " end

            local keyWidth = dims.keyUnit * (keyData.w or 1)
            local keyHeight = dims.keyUnit

            local info = self:resolveKeySpec(keyValue)
            local isHeld = self.activeKeys[keyValue] ~= nil

            local pressed = isHeld
            local glow = nil
            for _, anim in ipairs(self.animations) do
                if anim.key == keyValue and anim.progress < anim.duration then
                    if anim.type == "press" then
                        pressed = true
                    elseif anim.type == "correct" or anim.type == "error" then
                        glow = anim.type
                    end
                end
            end

            local spec = {
                char = keyValue,
                display = keyDisplay,
                rarity = info.rarity,
                capVariant = info.capVariant,
                switchType = info.switchType,
                pressed = pressed,
                active = info.isPreview,
                glow = glow,
                bonus = info.isUpgraded and info.bonus or nil,
            }

            local ok = pcall(CapRenderer.draw, rowX, rowY, keyWidth, keyHeight, spec)
            if not ok then
                self:drawKeyAsShape(rowX, rowY, keyWidth, keyHeight, keyDisplay, info.isUpgraded, isHeld)
            end

            rowX = rowX + keyWidth + dims.spacing
        end

        rowY = rowY + dims.rowHeight
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Defensive fallback if CapRenderer itself fails (e.g. image generation
-- rejected by the driver) -- plain flat-shaded rectangles, still themed.
function KeyboardView:drawKeyAsShape(x, y, width, height, keyDisplay, isUpgraded, isActive)
    local fillName = isActive and "accent" or (isUpgraded and "success" or "panelLight")
    Theme.setColor(fillName)
    love.graphics.rectangle("fill", x, y, width, height)

    Theme.setColor("border")
    love.graphics.rectangle("line", x, y, width, height)

    local label = keyDisplay ~= "Space" and keyDisplay or nil
    if label then
        local font = Theme.font("small")
        if font then
            love.graphics.setFont(font)
            Theme.setColor("text")
            local textWidth = font:getWidth(label)
            local textHeight = font:getHeight()
            love.graphics.print(label, x + (width - textWidth) / 2, y + (height - textHeight) / 2)
        end
    end
end

-- Find which key is at (x, y) given the same origin/scale draw() was called
-- with. Pure math -- safe to call headless.
function KeyboardView:getKeyAtPosition(x, y, baseX, baseY, scale)
    local dims = self:calculateDimensions(baseX, baseY, scale)
    local rowY = dims.y

    for i, row in ipairs(self.layout) do
        local rowX = dims.x + math.floor((dims.width - dims.rowWidths[i]) / 2)

        if y >= rowY and y < rowY + dims.rowHeight then
            for _, keyData in ipairs(row) do
                local keyWidth = dims.keyUnit * (keyData.w or 1)

                if x >= rowX and x < rowX + keyWidth then
                    local keyDisplay = keyData.key
                    local keyValue = string.lower(keyDisplay)
                    if keyDisplay == "Space" then keyValue = " " end

                    return keyValue, keyDisplay
                end

                rowX = rowX + keyWidth + dims.spacing
            end
        end

        rowY = rowY + dims.rowHeight
    end

    return nil
end

return KeyboardView
