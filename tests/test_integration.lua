-- tests/test_integration.lua
-- Regressions for defects that only appeared once the parallel work units were
-- merged together. Each one passed in isolation and broke in combination, so
-- they are covered here rather than in any single unit's suite.

local H = require("tests/helpers")

local KeyboardModel = require("modules/keyboard/keyboardModel")
local KeySpriteMapper = require("modules/keyboard/keySpriteMapper")
local ResourceManager = require("engine/resourceManager")
local TypingTrainer = require("modules/typing/trainer")

local T = {}

local function itemOn(key, kind, value)
    return {
        id = "test_" .. kind .. "_" .. key,
        name = "Test " .. kind,
        key = key,
        rarity = "common",
        capVariant = "plain",
        switchType = "linear",
        effect = { kind = kind, value = value },
        cost = 10,
    }
end

--------------------------------------------------------------------------
-- Cloning a board must not alias the original
--------------------------------------------------------------------------

function T.serialize_does_not_alias_the_live_upgrades_table()
    local kb = KeyboardModel.new("qwerty")
    kb:upgradeKey("e", 0.20)

    local data = kb:serialize()
    data.upgrades["e"] = 99
    data.upgrades["z"] = 42

    H.near(kb:getKeyBonus("e"), 0.20, 1e-6,
        "mutating serialized data changed the live keyboard")
    H.equal(kb:getKeyBonus("z"), 0, "a key was added to the live keyboard")
end

function T.deserialize_does_not_alias_its_source_data()
    local original = KeyboardModel.new("qwerty")
    original:upgradeKey("a", 0.10)

    local clone = KeyboardModel.deserialize(original:serialize())
    clone:upgradeKey("a", 0.50)
    clone:upgradeKey("b", 0.30)

    H.near(original:getKeyBonus("a"), 0.10, 1e-6,
        "the clone mutated its source keyboard -- this is the shop preview bug")
    H.equal(original:getKeyBonus("b"), 0)
end

function T.serialize_does_not_alias_installed_items()
    local kb = KeyboardModel.new("qwerty")
    kb:installItem(itemOn("e", "flat", 0.15))

    local data = kb:serialize()
    data.installedItems[1].effect.value = 99

    H.near(kb:getInstalled()[1].effect.value, 0.15, 1e-6,
        "mutating serialized items changed the installed board")
end

function T.installed_items_are_copied_from_the_caller()
    local kb = KeyboardModel.new("qwerty")
    local offer = itemOn("e", "flat", 0.15)

    kb:installItem(offer)
    offer.effect.value = 99
    offer.key = "z"

    local installed = kb:getInstalled()[1]
    H.near(installed.effect.value, 0.15, 1e-6, "the shop offer table aliased installed state")
    H.equal(installed.key, "e")
end

--------------------------------------------------------------------------
-- grace / protect only fire on a miss, so they need computeKeyError
--------------------------------------------------------------------------

local function trainerFor(keyboard, text)
    return TypingTrainer.new({ text = text or "aaaa", keyboardModel = keyboard })
end

function T.grace_forgives_the_first_miss_on_its_key()
    local kb = KeyboardModel.new("qwerty")
    kb:installItem(itemOn("a", "grace", 1))

    local trainer = trainerFor(kb)
    trainer:handleInput("x") -- wrong: expected "a", grace should forgive it

    H.equal(trainer.mistakes, 0, "grace did not forgive the first miss")
end

function T.grace_is_consumed_after_one_miss()
    local kb = KeyboardModel.new("qwerty")
    kb:installItem(itemOn("a", "grace", 1))

    local trainer = trainerFor(kb)
    trainer:handleInput("x")
    trainer:handleInput("x")

    H.equal(trainer.mistakes, 1, "grace forgave more than one miss in a round")
end

function T.protect_keeps_the_streak_through_a_miss_on_its_key()
    local kb = KeyboardModel.new("qwerty")
    kb:installItem(itemOn("a", "protect", 1))

    -- The miss lands where "a" was expected, which is the protected key.
    local trainer = trainerFor(kb, "aaa")
    trainer:handleInput("a")
    H.equal(trainer.currentStreak, 1)

    trainer:handleInput("q")
    H.equal(trainer.currentStreak, 1, "protect did not preserve the streak")
    H.equal(trainer.mistakes, 1, "protect should preserve the streak, not the mistake count")
end

function T.protect_does_not_cover_other_keys()
    local kb = KeyboardModel.new("qwerty")
    kb:installItem(itemOn("a", "protect", 1))

    -- The miss lands where "x" was expected; the protect item is on "a".
    local trainer = trainerFor(kb, "aaxa")
    trainer:handleInput("a")
    trainer:handleInput("a")
    H.equal(trainer.currentStreak, 2)

    trainer:handleInput("q")
    H.equal(trainer.currentStreak, 0, "a miss on an unprotected key kept the streak")
end

function T.a_plain_miss_still_costs_a_mistake_and_the_streak()
    local kb = KeyboardModel.new("qwerty")

    local trainer = trainerFor(kb, "aaaa")
    trainer:handleInput("a")
    H.equal(trainer.currentStreak, 1)

    trainer:handleInput("x")
    H.equal(trainer.mistakes, 1, "an unmodified miss was silently forgiven")
    H.equal(trainer.currentStreak, 0)
end

function T.trainer_works_with_a_keyboard_lacking_computeKeyError()
    -- Legacy/stub models must not break the miss path.
    local stub = {
        getKeyBonus = function() return 0 end,
        getTotalMultiplier = function() return 1 end,
    }

    local trainer = trainerFor(stub, "aaaa")
    H.succeeds(function() trainer:handleInput("x") end)
    H.equal(trainer.mistakes, 1)
end

--------------------------------------------------------------------------
-- Missing-asset placeholder vs. a caller that genuinely wants nil
--------------------------------------------------------------------------

function T.sprite_mapper_load_is_headless_safe()
    -- getSprite now substitutes a magenta placeholder for a missing asset, so
    -- a nil check alone no longer stops load() from slicing quads out of it.
    local mapper = KeySpriteMapper.new()
    H.isFalse(H.succeeds(function() return mapper:load() end),
        "load() must fail gracefully with no graphics context")
end

function T.get_sprite_or_nil_still_returns_nil()
    H.equal(ResourceManager:getSpriteOrNil("definitely_not_a_real_sprite"), nil)
end

return T
