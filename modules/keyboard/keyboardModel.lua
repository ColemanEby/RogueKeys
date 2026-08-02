-- modules/keyboard/keyboardModel.lua
-- Enhanced keyboard data model with upgrade mechanics and config fallbacks

local ConfigManager = require("engine/configManager")
local Effects = require("modules/items/effects")
local ItemDefs = require("modules/items/itemDefs")
local Rarity = require("modules/items/rarity")

local KeyboardModel = {}
KeyboardModel.__index = KeyboardModel

-- Small, additive global-multiplier reward for owning higher-rarity gear.
-- This is what getTotalMultiplier() actually reflects now -- previously
-- self.multiplier was initialised to 1.0 and never touched again.
local MULTIPLIER_BONUS_BY_RARITY = {
    common = 0, uncommon = 0.01, rare = 0.02, epic = 0.04, legendary = 0.08,
}

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
    self.multiplier = 1.0  -- Global score multiplier (see updateMultiplier)
    self.upgrades = {}     -- Legacy per-key upgrades: key (lowercase) -> bonus value

    self.installedItems = {} -- Items installed via installItem(), the new item system
    self.roundState = {}     -- Per-round bookkeeping handed to Effects (grace, echo bank...)
    self._adjacency = nil    -- Lazily built physical neighbour map, cached per instance

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

            local value = string.lower(key)
            table.insert(keys, {
                display = keyData.key,
                value = value, -- Store lowercase for comparison
                width = keyData.w or 1,
                upgraded = self:isKeyUpgraded(key),
                bonus = self:getKeyBonus(key),
                installedItems = self:getItemsOnKey(value), -- additive: safe for callers that ignore it
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

    -- Shuffle the available keys. love.math.random, not math.random: the
    -- global Lua RNG here was never seeded, so every launch produced the
    -- exact same "random" offers.
    for i = #availableKeys, 2, -1 do
        local j = love.math.random(i)
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
            cost = love.math.random(minCost, maxCost),
            bonus = love.math.random(minBonus * 100, maxBonus * 100) / 100 -- Convert to decimal, e.g. 0.05 to 0.30
        })
    end

    return offers
end

-- ============================================================================
-- Item system (rarity, effects, physical adjacency). generateUpgradeOffers
-- above is kept working for anything that still calls it (e.g. a shop state
-- that hasn't picked up generateOffers yet); this is the real system it is
-- being superseded by.
-- ============================================================================

-- Physical neighbour map, derived from the *actual* layout rows rather than a
-- hardcoded QWERTY table -- Dvorak (or any future layout) gets correct
-- adjacency for free. Same-row neighbours are the key to either side; between
-- rows we approximate real keyboard stagger by pairing each key with the one
-- at the same column index and the one at column-1 in the row below.
function KeyboardModel:getAdjacency()
    if self._adjacency then return self._adjacency end

    local adjacency = {}
    local function addPair(a, b)
        if not a or not b or a == b then return end
        adjacency[a] = adjacency[a] or {}
        adjacency[a][b] = true
        adjacency[b] = adjacency[b] or {}
        adjacency[b][a] = true
    end

    local function keyValue(keyData)
        local k = keyData.key
        if k == "Space" then return " " end
        return string.lower(k)
    end

    local rows = {}
    for _, row in ipairs(self.layout or {}) do
        local values = {}
        for _, keyData in ipairs(row) do
            values[#values + 1] = keyValue(keyData)
        end
        rows[#rows + 1] = values
    end

    for r, row in ipairs(rows) do
        for i, key in ipairs(row) do
            addPair(key, row[i - 1])
            addPair(key, row[i + 1])

            local nextRow = rows[r + 1]
            if nextRow then
                addPair(key, nextRow[i])
                addPair(key, nextRow[i - 1])
            end
        end
    end

    self._adjacency = adjacency
    return adjacency
end

-- Whether two characters are physical neighbours on this keyboard's layout.
-- A nil argument (e.g. no previous character yet) is simply not adjacent.
function KeyboardModel:isAdjacent(a, b)
    if not a or not b then return false end
    a, b = string.lower(a), string.lower(b)
    local adjacency = self:getAdjacency()
    return adjacency[a] ~= nil and adjacency[a][b] == true
end

-- Recompute the global multiplier from installed gear. This is the "wire it
-- to something real" fix: previously self.multiplier was set once in .new()
-- and never touched again, so getTotalMultiplier() always returned 1.0.
-- Owning higher-rarity items now nudges every keystroke on the whole board,
-- which is a small but real reward for chasing rarity beyond the per-key
-- effect itself.
function KeyboardModel:updateMultiplier()
    local bonus = 0
    for _, item in ipairs(self:getInstalled()) do
        bonus = bonus + (MULTIPLIER_BONUS_BY_RARITY[item.rarity] or 0)
    end
    self.multiplier = 1.0 + bonus
end

-- Install an item onto its key. Stacking rule: a key may carry any number of
-- items as long as they have different effect kinds (a keycap can be flat AND
-- streak AND crit at once, say), but installing a second item of a kind that
-- key already has REPLACES the old one rather than stacking -- there is only
-- one physical keycap/switch slot per kind, so two "flat" items on the same
-- key would otherwise be a free-stacking exploit.
function KeyboardModel:installItem(item)
    assert(item and item.key and item.effect and item.effect.kind,
        "KeyboardModel:installItem requires an item with key + effect.kind")

    self.installedItems = self.installedItems or {}
    local key = string.lower(item.key)

    for i = #self.installedItems, 1, -1 do
        local existing = self.installedItems[i]
        if existing.key == key and existing.effect.kind == item.effect.kind then
            table.remove(self.installedItems, i)
        end
    end

    -- Shallow-copy the item (and its effect table one level deep) so that
    -- whatever produced it -- a shop offer table, a deserialized save row --
    -- can't reach in and mutate installed board state later.
    local installed = {}
    for k, v in pairs(item) do installed[k] = v end
    installed.key = key

    if type(item.effect) == "table" then
        local effectCopy = {}
        for k, v in pairs(item.effect) do
            if type(v) == "table" then
                local nested = {}
                for i, vv in ipairs(v) do nested[i] = vv end
                effectCopy[k] = nested
            else
                effectCopy[k] = v
            end
        end
        installed.effect = effectCopy
    end

    table.insert(self.installedItems, installed)

    self:updateMultiplier()
    return installed
end

function KeyboardModel:getInstalled()
    return self.installedItems or {}
end

function KeyboardModel:getItemsOnKey(key)
    key = string.lower(key)
    local result = {}
    for _, item in ipairs(self:getInstalled()) do
        if item.key == key then
            result[#result + 1] = item
        end
    end
    return result
end

function KeyboardModel:getInstalledIdSet()
    local set = {}
    for _, item in ipairs(self:getInstalled()) do
        set[item.id] = true
    end
    return set
end

-- The scoring hook the trainer calls once per correct keystroke.
-- ctx = { streak, prevChar, round, isVowel }; returns points, procs.
--
-- Base score is Effects.BASE_SCORE (1.0) plus any legacy flat `upgrades`
-- bonus (old saves, or keys nobody has installed a new-system item on yet),
-- plus every installed item's own effect on this key, summed. procs
-- aggregates the flags juice/audio (unit 16) care about across every item
-- that fired, not just one.
function KeyboardModel:computeKeyScore(char, ctx)
    ctx = ctx or {}
    local key = string.lower(char)

    local points = Effects.BASE_SCORE + self:getKeyBonus(key)

    local effectCtx = {
        streak = ctx.streak or 0,
        prevChar = ctx.prevChar,
        round = ctx.round or 1,
        isVowel = ctx.isVowel or false,
        adjacentToPrev = self:isAdjacent(key, ctx.prevChar),
        isError = false,
    }

    self.roundState = self.roundState or {}
    local state = self.roundState
    state.installedIds = self:getInstalledIdSet()

    local procs = { crit = false, coins = 0, echo = false, set = false }

    for _, item in ipairs(self:getItemsOnKey(key)) do
        local itemPoints, itemProcs = Effects.compute(item.effect.kind, item, effectCtx, state)
        points = points + (itemPoints or 0)

        if itemProcs then
            if itemProcs.coins then procs.coins = procs.coins + itemProcs.coins end
            if itemProcs.crit then procs.crit = true end
            if itemProcs.echo then procs.echo = true end
            if itemProcs.set then procs.set = true end
        end
    end

    points = points * self:getTotalMultiplier()
    return points, procs
end

-- Companion to computeKeyScore for the error path: grace and protect only
-- mean anything on an incorrect keystroke, which computeKeyScore never sees
-- (the shared contract calls it only on correct keystrokes). Not part of that
-- contract -- the trainer (unit 15) should call this on a miss if it wants
-- grace/protect to do anything; see PR description.
function KeyboardModel:computeKeyError(char, ctx)
    ctx = ctx or {}
    local key = string.lower(char)

    local effectCtx = {
        streak = ctx.streak or 0,
        prevChar = ctx.prevChar,
        round = ctx.round or 1,
        isVowel = ctx.isVowel or false,
        isError = true,
    }

    self.roundState = self.roundState or {}
    local state = self.roundState

    local result = { forgiven = false, protected = false }
    for _, item in ipairs(self:getItemsOnKey(key)) do
        local kind = item.effect.kind
        if kind == "grace" or kind == "protect" then
            local _, procs = Effects.compute(kind, item, effectCtx, state)
            if procs.forgiven then result.forgiven = true end
            if procs.protected then result.protected = true end
        end
    end
    return result
end

-- All lowercase key values on this layout, for feeding into generateOffers.
function KeyboardModel:getKeyPool()
    local pool = {}
    for _, k in ipairs(self:getAllKeys()) do
        pool[#pool + 1] = k.value
    end
    return pool
end

-- Roll `count` concrete shop offers for the given round. opts.luck is passed
-- through to Rarity.roll; opts.keyPool overrides the default (this
-- keyboard's own keys).
function KeyboardModel:generateOffers(count, round, opts)
    count = count or 5
    round = round or 1
    opts = opts or {}

    local keyPool = opts.keyPool or self:getKeyPool()
    local offers = {}
    for _ = 1, count do
        local rarity = Rarity.roll(round, opts.luck)
        local offer = ItemDefs.generateOffer(round, rarity, keyPool)
        if offer then table.insert(offers, offer) end
    end
    return offers
end

-- Serialize the keyboard model for saving. installedItems is the new-system
-- data; upgrades is kept alongside it for the legacy flat-bonus map so old
-- saves round-trip unchanged even after a player also starts buying items.
function KeyboardModel:serialize()
    local installed = {}
    for i, item in ipairs(self:getInstalled()) do
        installed[i] = item
    end

    return {
        layoutType = self.layoutType,
        name = self.name,
        description = self.description,
        multiplier = self.multiplier,
        upgrades = self.upgrades,
        installedItems = installed,
    }
end

-- Deserialize and return a new keyboard model. A save with only `upgrades`
-- (every save before this unit) loads exactly as before -- computeKeyScore
-- honours self.upgrades directly, no migration needed. A save with
-- installedItems replays each one through installItem() so stacking rules
-- and the derived multiplier are recomputed rather than trusted blindly.
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

    if data.installedItems and type(data.installedItems) == "table" then
        for _, item in ipairs(data.installedItems) do
            -- One malformed row (hand-edited save, future format change)
            -- should not cost the player every other item on the board.
            local ok, err = pcall(function() keyboard:installItem(item) end)
            if not ok then
                print("KeyboardModel: skipped malformed installed item: " .. tostring(err))
            end
        end
    end

    return keyboard
end

return KeyboardModel