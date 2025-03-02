-- modules/keyboard/keyboardModel.lua
-- Enhanced keyboard data model with upgrade mechanics and config fallbacks

local ConfigManager = require("engine/configManager")

local KeyboardModel = {}
KeyboardModel.__index = KeyboardModel

-- Default QWERTY layout to use when config is not available
local DEFAULT_QWERTY_LAYOUT = {
    name = "QWERTY Default",
    description = "Standard QWERTY keyboard layout (fallback)",
    layout = {
        { { key = "Q", w = 1 }, { key = "W", w = 1 }, { key = "E", w = 1 }, { key = "R", w = 1 },
          { key = "T", w = 1 }, { key = "Y", w = 1 }, { key = "U", w = 1 }, { key = "I", w = 1 },
          { key = "O", w = 1 }, { key = "P", w = 1 } },
        { { key = "A", w = 1 }, { key = "S", w = 1 }, { key = "D", w = 1 }, { key = "F", w = 1 },
          { key = "G", w = 1 }, { key = "H", w = 1 }, { key = "J", w = 1 }, { key = "K", w = 1 },
          { key = "L", w = 1 } },
        { { key = "Z", w = 1 }, { key = "X", w = 1 }, { key = "C", w = 1 }, { key = "V", w = 1 },
          { key = "B", w = 1 }, { key = "N", w = 1 }, { key = "M", w = 1 } },
        { { key = ",", w = 1 }, { key = ".", w = 1 }, { key = "?", w = 1 }, { key = "!", w = 1 } },
        { { key = "Space", w = 5 } }
    }
}

-- Create a new keyboard model with the given layout type
function KeyboardModel.new(layoutType)
    local self = setmetatable({}, KeyboardModel)

    self.layoutType = layoutType or "qwerty"
    
    -- Safely get keyboard layouts from config
    local layouts = {}
    local success, result = pcall(function()
        return ConfigManager:getKeyboardLayouts()
    end)
    
    if success and result and next(result) then
        layouts = result
    else
        -- If configuration failed, use default layouts
        print("KeyboardModel: Failed to get keyboard layouts from config, using defaults")
        layouts = {
            qwerty = DEFAULT_QWERTY_LAYOUT
        }
    end

    -- Get layout data from config, or fall back to qwerty
    self.layoutData = layouts[self.layoutType] or layouts.qwerty or DEFAULT_QWERTY_LAYOUT

    self.name = self.layoutData.name or "Standard Keyboard"
    self.description = self.layoutData.description or "A standard keyboard layout"
    self.layout = self.layoutData.layout or DEFAULT_QWERTY_LAYOUT.layout
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
    
    -- Verify layout is properly defined
    if not self.layout or type(self.layout) ~= "table" then
        print("KeyboardModel: Warning - Layout is not properly defined")
        return keys
    end
    
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
    
    -- If everything is upgraded, allow re-upgrading some keys
    if #availableKeys == 0 then
        availableKeys = {"a", "e", "i", "o", "u", " "} -- Common keys as fallback
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
    if not data then
        print("KeyboardModel: Deserialization failed - no data provided")
        return KeyboardModel.new("qwerty")
    end
    
    local layoutType = data.layoutType or "qwerty"
    local keyboard = KeyboardModel.new(layoutType)
    
    if data.name then keyboard.name = data.name end
    if data.description then keyboard.description = data.description end
    if data.multiplier then keyboard.multiplier = data.multiplier end
    if data.upgrades then keyboard.upgrades = data.upgrades end
    
    return keyboard
end

return KeyboardModel