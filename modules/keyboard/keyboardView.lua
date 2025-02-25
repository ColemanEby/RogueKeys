-- modules/keyboard/keyboardView.lua
-- Visual representation of keyboard with key sprites and animations

local ResourceManager = require("engine/resourceManager")
local KeySpriteMapper = require("modules/keyboard/keySpriteMapper")

local KeyboardView = {}
KeyboardView.__index = KeyboardView

-- Create a new keyboard view for the given keyboard model
function KeyboardView.new(keyboardModel)
    local self = setmetatable({}, KeyboardView)

    self.keyboardModel = keyboardModel
    self.layout = keyboardModel.layout

    -- Styling options with defaults
    self.style = {
        keyWidth = 50,
        keyHeight = 50,
        keySpacing = 5,
        keyCornerRadius = 5,
        keyColor = {0.2, 0.2, 0.2, 1.0},
        keyTextColor = {1.0, 1.0, 1.0, 1.0},
        keyUpgradedColor = {0.3, 0.6, 0.3, 1.0},
        keyHighlightColor = {0.8, 0.8, 0.0, 1.0},
        keyStrokeColor = {0.3, 0.3, 0.3, 1.0},
        keyShadowColor = {0.0, 0.0, 0.0, 0.3},
        keyShadowOffset = 2,
        fontName = "default",
        fontSize = 18,
        upgradeIndicatorColor = {1.0, 0.8, 0.0, 1.0}
    }

    -- Active keys for highlighting during typing
    self.activeKeys = {}
    self.animations = {}

    -- Initialize key sprite mapper
    self.spriteMapper = KeySpriteMapper.new()
    self.useSprites = self.spriteMapper:load()

    return self
end

-- Calculate keyboard dimensions
function KeyboardView:calculateDimensions(x, y, scale)
    scale = scale or 1.0
    local totalWidth = 0
    local totalHeight = 0

    local rowWidths = {}
    local rowHeight = (self.style.keyHeight + self.style.keySpacing) * scale

    -- Calculate width of each row
    for i, row in ipairs(self.layout) do
        local rowWidth = 0
        for _, keyData in ipairs(row) do
            local width = (self.style.keyWidth * (keyData.w or 1) + self.style.keySpacing) * scale
            rowWidth = rowWidth + width
        end
        rowWidths[i] = rowWidth
        totalWidth = math.max(totalWidth, rowWidth)
    end

    totalHeight = #self.layout * rowHeight

    return {
        x = x,
        y = y,
        width = totalWidth,
        height = totalHeight,
        rowWidths = rowWidths,
        rowHeight = rowHeight,
        scale = scale
    }
end

-- Activate a key (for highlighting)
function KeyboardView:activateKey(key)
    key = string.lower(key)
    self.activeKeys[key] = true

    -- Add a "press" animation
    self:animateKeyPress(key)
end

-- Deactivate a key
function KeyboardView:deactivateKey(key)
    key = string.lower(key)
    self.activeKeys[key] = nil
end

-- Animate a key press
function KeyboardView:animateKeyPress(key)
    local animation = {
        key = key,
        type = "press",
        progress = 0,
        duration = 0.2,
        maxScale = 1.2
    }

    table.insert(self.animations, animation)
end

-- Update animations
function KeyboardView:update(dt)
    -- Update existing animations
    for i = #self.animations, 1, -1 do
        local anim = self.animations[i]
        anim.progress = anim.progress + dt

        -- Remove completed animations
        if anim.progress >= anim.duration then
            table.remove(self.animations, i)
        end
    end
end

-- Draw the keyboard at the specified position with optional scaling
function KeyboardView:draw(x, y, scale)
    local dims = self:calculateDimensions(x, y, scale)

    -- Draw keyboard background/border if needed
    love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
    love.graphics.rectangle("fill", dims.x - 10, dims.y - 10,
            dims.width + 20, dims.height + 20,
            10, 10)

    local font = ResourceManager:getFont(self.style.fontName, self.style.fontSize * dims.scale)
    love.graphics.setFont(font)

    -- Draw each row of keys
    local rowY = dims.y
    for i, row in ipairs(self.layout) do
        -- Center the row horizontally
        local rowX = dims.x + (dims.width - dims.rowWidths[i]) / 2

        -- Draw each key in the row
        for _, keyData in ipairs(row) do
            local keyWidth = self.style.keyWidth * (keyData.w or 1) * dims.scale
            local keyHeight = self.style.keyHeight * dims.scale

            -- Determine key value (for matching with active/upgraded status)
            local keyDisplay = keyData.key
            local keyValue = string.lower(keyDisplay)
            if keyDisplay == "Space" then keyValue = " " end

            -- Check if key is active or upgraded
            local isActive = self.activeKeys[keyValue] ~= nil
            local isUpgraded = self.keyboardModel:isKeyUpgraded(keyValue)
            local upgradeLevel = self.keyboardModel:getKeyBonus(keyValue)

            -- Apply any active animations
            local animScale = 1.0
            for _, anim in ipairs(self.animations) do
                if anim.key == keyValue and anim.type == "press" then
                    local t = anim.progress / anim.duration
                    -- Ease out animation curve
                    t = 1 - (1 - t) * (1 - t)
                    animScale = 1 + (anim.maxScale - 1) * (1 - t)
                    break
                end
            end

            -- Draw key using sprite or shapes
            if self.useSprites and self.spriteMapper then
                -- Try to draw the key using sprite mapper
                local isDark = isUpgraded or isActive
                
                -- Calculate key position with animation scaling
                local keyX = rowX + (keyWidth - keyWidth * animScale) / 2
                local keyY = rowY + (keyHeight - keyHeight * animScale) / 2
                keyWidth = keyWidth * animScale
                keyHeight = keyHeight * animScale
                
                -- Attempt to draw with sprite mapper first
                local success = self.spriteMapper:drawKey(keyValue, keyX, keyY, keyWidth, keyHeight, isDark)
                
                -- If sprite drawing fails, fall back to shape-based rendering
                if not success then
                    self:drawKeyAsShape(keyX, keyY, keyWidth, keyHeight, keyDisplay, isUpgraded, isActive, animScale)
                end
            else
                -- Draw key using rectangles and shapes (fallback method)
                self:drawKeyAsShape(rowX, rowY, keyWidth, keyHeight, keyDisplay, isUpgraded, isActive, animScale)
            end

            -- Draw upgrade indicator if upgraded
            if isUpgraded then
                love.graphics.setColor(self.style.upgradeIndicatorColor)
                local bonusText = string.format("+%.0f%%", upgradeLevel * 100)
                local bonusWidth = font:getWidth(bonusText)
                love.graphics.print(
                        bonusText,
                        rowX + keyWidth - bonusWidth - 5,
                        rowY + keyHeight - font:getHeight() - 2
                )
            end

            -- Move to next key position
            rowX = rowX + keyWidth + self.style.keySpacing * dims.scale
        end

        -- Move to next row
        rowY = rowY + dims.rowHeight
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Helper method for drawing keys with shapes
function KeyboardView:drawKeyAsShape(x, y, width, height, keyDisplay, isUpgraded, isActive, animScale)
    -- Determine colors based on state
    local keyColor = self.style.keyColor
    if isUpgraded then
        keyColor = self.style.keyUpgradedColor
    end
    if isActive then
        keyColor = self.style.keyHighlightColor
    end

    -- Calculate key position with animation scaling if not already applied
    local keyX = x
    local keyY = y
    if animScale and animScale ~= 1.0 then
        keyX = x + (width - width * animScale) / 2
        keyY = y + (height - height * animScale) / 2
        width = width * animScale
        height = height * animScale
    end

    -- Draw key shadow
    love.graphics.setColor(self.style.keyShadowColor)
    love.graphics.rectangle(
            "fill",
            keyX + self.style.keyShadowOffset,
            keyY + self.style.keyShadowOffset,
            width,
            height,
            self.style.keyCornerRadius
    )

    -- Draw key background
    love.graphics.setColor(keyColor)
    love.graphics.rectangle(
            "fill",
            keyX,
            keyY,
            width,
            height,
            self.style.keyCornerRadius
    )

    -- Draw key border
    love.graphics.setColor(self.style.keyStrokeColor)
    love.graphics.rectangle(
            "line",
            keyX,
            keyY,
            width,
            height,
            self.style.keyCornerRadius
    )

    -- Draw key label
    love.graphics.setColor(self.style.keyTextColor)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(keyDisplay)
    local textHeight = font:getHeight()
    love.graphics.print(
            keyDisplay,
            keyX + (width - textWidth) / 2,
            keyY + (height - textHeight) / 2
    )
end

-- Find which key was clicked
function KeyboardView:getKeyAtPosition(x, y, baseX, baseY, scale)
    local dims = self:calculateDimensions(baseX, baseY, scale)
    local rowY = dims.y

    for i, row in ipairs(self.layout) do
        -- Row horizontal centering
        local rowX = dims.x + (dims.width - dims.rowWidths[i]) / 2
        local rowHeight = dims.rowHeight

        -- Check if y is within this row
        if y >= rowY and y < rowY + rowHeight then
            for _, keyData in ipairs(row) do
                local keyWidth = self.style.keyWidth * (keyData.w or 1) * dims.scale

                -- Check if x is within this key
                if x >= rowX and x < rowX + keyWidth then
                    local keyDisplay = keyData.key
                    local keyValue = string.lower(keyDisplay)
                    if keyDisplay == "Space" then keyValue = " " end

                    return keyValue, keyDisplay
                end

                rowX = rowX + keyWidth + self.style.keySpacing * dims.scale
            end
        end

        rowY = rowY + dims.rowHeight
    end

    return nil
end

return KeyboardView