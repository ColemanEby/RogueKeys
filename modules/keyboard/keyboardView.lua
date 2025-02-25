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

            -- Draw key using sprite or shapes
            if self.useSprites then
                -- Choose appropriate sprite
                local spriteKey = "key_normal"
                if isUpgraded then
                    spriteKey = "key_upgraded"
                end
                if isActive then
                    spriteKey = "key_highlight"
                end
                if keyDisplay == "Space" then
                    spriteKey = "key_space"
                end

                local sprite = self.keySprites[spriteKey]

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

                -- Draw the sprite with scaling
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                        sprite.texture,
                        rowX + keyWidth/2,
                        rowY + keyHeight/2,
                        0,  -- rotation
                        keyWidth/sprite:getWidth() * animScale,
                        keyHeight/sprite:getHeight() * animScale,
                        sprite:getWidth()/2,
                        sprite:getHeight()/2
                )
            else
                -- Draw key using rectangles and shapes

                -- Determine colors based on state
                local keyColor = self.style.keyColor
                if isUpgraded then
                    keyColor = self.style.keyUpgradedColor
                end
                if isActive then
                    keyColor = self.style.keyHighlightColor
                end

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

                -- Calculate key position with animation scaling
                local keyX = rowX + (keyWidth - keyWidth * animScale) / 2
                local keyY = rowY + (keyHeight - keyHeight * animScale) / 2
                keyWidth = keyWidth * animScale
                keyHeight = keyHeight * animScale

                -- Draw key shadow
                love.graphics.setColor(self.style.keyShadowColor)
                love.graphics.rectangle(
                        "fill",
                        keyX + self.style.keyShadowOffset,
                        keyY + self.style.keyShadowOffset,
                        keyWidth,
                        keyHeight,
                        self.style.keyCornerRadius * dims.scale
                )

                -- Draw key background
                love.graphics.setColor(keyColor)
                love.graphics.rectangle(
                        "fill",
                        keyX,
                        keyY,
                        keyWidth,
                        keyHeight,
                        self.style.keyCornerRadius * dims.scale
                )

                -- Draw key border
                love.graphics.setColor(self.style.keyStrokeColor)
                love.graphics.rectangle(
                        "line",
                        keyX,
                        keyY,
                        keyWidth,
                        keyHeight,
                        self.style.keyCornerRadius * dims.scale
                )
            end

            -- Draw key label regardless of sprite/shape mode
            love.graphics.setColor(self.style.keyTextColor)
            local textWidth = font:getWidth(keyDisplay)
            local textHeight = font:getHeight()
            love.graphics.print(
                    keyDisplay,
                    rowX + (keyWidth - textWidth) / 2,
                    rowY + (keyHeight - textHeight) / 2
            )

            -- Draw upgrade indicator if upgraded
            if isUpgraded then
                love.graphics.setColor(self.style.upgradeIndicatorColor)
                local bonusText = string.format("+%.0f%%", upgradeLevel * 100)
                local bonusWidth = font:getWidth(bonusText)
                love.graphics.print(
                        bonusText,
                        rowX + keyWidth - bonusWidth - 5,
                        rowY + keyHeight - textHeight - 2
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