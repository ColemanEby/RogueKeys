-- modules/keyboard/keyboardModel.lua
-- Enhanced keyboard data model with upgrade mechanics

local ConfigManager = require("engine/configManager")

local KeyboardModel = {}
KeyboardModel.__index = KeyboardModel

-- Create a new keyboard model with the given layout type
function KeyboardModel.new(layoutType)
    local self = setmetatable({}, KeyboardModel)

    self.layoutType = layoutType or "qwerty"
    local layouts = ConfigManager:getKeyboardLayouts()

    -- Get layout data from config, or fall back to qwerty
    self.layoutData = layouts[self.layoutType] or layouts.qwerty

    self.name = self.layoutData.name or "Standard Keyboard"
    self.description = self.layoutData.description or "A standard keyboard layout"
    self.layout = self.layoutData.layout
    self.multiplier = 1.0  -- Global score multiplier
    self.upgrades = {}     -- Per-key upgrades: key (lowercase) -> bonus value

    return self
end

-- Add an upgrade to a specific key
function KeyboardModel:upgradeKey(key, bonus)
    key = string.lower(key) -- Ensure consistency with lowercase
    self.upgrades[key] = (self.upgrades[key] or 0) + bonus
    return self.upgrades[key]
end

-- Check if a key has been upgraded
function KeyboardModel:isKeyUpgraded(key)
    key = string.lower(key)
    return self.upgrades[key] ~= nil and self.upgrades[key] > 0
end

-- Get the bonus value for a key
function KeyboardModel:getKeyBonus(key)
    key = string.lower(key)
    return self.upgrades[key] or 0
end

-- Get the total score multiplier (base + upgrades)
function KeyboardModel:getTotalMultiplier()
    return self.multiplier
end

-- Get a flattened list of all keys in the layout
function KeyboardModel:getAllKeys()
    local keys = {}
    for _, row in ipairs(self.layout) do
        for _, keyData in ipairs(row) do
            -- Handle space key and other special keys
            local key = keyData.key
            if key == "Space" then key = " " end

            table.insert(keys, {
                display = keyData.key,
                value = string.lower(key), -- Store lowercase for comparison
                width = keyData.w or 1,
                upgraded = self:isKeyUpgraded(key),
                bonus = self:getKeyBonus(key)
            })
        end
    end
    return keys
end

-- Generate random upgrade offers
function KeyboardModel:generateUpgradeOffers(count, minCost, maxCost, minBonus, maxBonus)
    count = count or 5
    minCost = minCost or 20
    maxCost = maxCost or 70
    minBonus = minBonus or 0.05
    maxBonus = maxBonus or 0.30

    -- List of possible keys for upgrade
    local possibleKeys = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        ",", ".", "?", "!", " "
    }

    -- Build list of keys not yet upgraded
    local availableKeys = {}
    for _, key in ipairs(possibleKeys) do
        if not self.upgrades[key] then
            table.insert(availableKeys, key)
        end
    end

    -- Shuffle the available keys
    for i = #availableKeys, 2, -1 do
        local j = math.random(i)
        availableKeys[i], availableKeys[j] = availableKeys[j], availableKeys[i]
    end

    -- Create offers
    local offers = {}
    for i = 1, math.min(count, #availableKeys) do
        local key = availableKeys[i]
        -- Special display name for space
        local displayKey = key
        if key == " " then displayKey = "Space" end

        table.insert(offers, {
            key = key,
            displayKey = displayKey,
            cost = math.random(minCost, maxCost),
            bonus = math.random(minBonus * 100, maxBonus * 100) / 100 -- Convert to decimal, e.g. 0.05 to 0.30
        })
    end

    return offers
end

-- Serialize the keyboard model for saving
function KeyboardModel:serialize()
    return {
        layoutType = self.layoutType,
        name = self.name,
        description = self.description,
        multiplier = self.multiplier,
        upgrades = self.upgrades
    }
end

-- Deserialize and return a new keyboard model
function KeyboardModel.deserialize(data)
    local keyboard = KeyboardModel.new(data.layoutType)
    keyboard.name = data.name
    keyboard.description = data.description
    keyboard.multiplier = data.multiplier
    keyboard.upgrades = data.upgrades or {}
    return keyboard
end

return KeyboardModel