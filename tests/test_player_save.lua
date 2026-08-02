-- tests/test_player_save.lua
-- Save/load integrity tests for modules/player/playerModel.lua.
--
-- IMPORTANT: love.filesystem's save directory is the real, shared LOVE save
-- dir for the "RogueKeys" identity (see conf.lua) -- the same one the actual
-- game reads and writes. Every test here uses a scratch path distinct from
-- save/player.lua and cleans it (and its backup) up afterward, so running
-- this suite never touches a real player's progress.

local H = require("tests/helpers")
local PlayerModel = require("modules/player/playerModel")
local Serialize = require("modules/util/serialize")

local T = {}

local function scratchPath(name)
    return "save/test_player_save_" .. name .. ".lua"
end

local function cleanup(path)
    love.filesystem.remove(path)
    love.filesystem.remove(PlayerModel.backupPathFor(path))
end

-- Runs fn(path) with a fresh scratch path, guaranteeing cleanup runs even if
-- the test body raises.
local function withScratch(name, fn)
    local path = scratchPath(name)
    cleanup(path)
    local ok, err = pcall(fn, path)
    cleanup(path)
    if not ok then error(err, 0) end
end

function T.save_load_round_trip_preserves_core_fields()
    withScratch("roundtrip", function(path)
        local player = PlayerModel.new()
        player:addMoney(500)
        player.currentRound = 4
        player.maxRoundReached = 4
        player.keyboard:upgradeKey("e", 0.3)
        player.stats.totalKeystrokes = 1234
        player.stats.bestWPM = 87

        H.isTrue(player:save(path), "save should report success")

        local loaded = PlayerModel.load(path)

        H.equal(loaded.totalMoney, player.totalMoney, "money did not round-trip")
        H.equal(loaded.currentRound, 4, "round did not round-trip")
        H.equal(loaded.maxRoundReached, 4, "maxRoundReached did not round-trip")
        H.near(loaded.keyboard:getKeyBonus("e"), 0.3, 1e-6, "keyboard upgrade did not round-trip")
        H.equal(loaded.stats.totalKeystrokes, 1234, "stat did not round-trip")
        H.equal(loaded.stats.bestWPM, 87, "stat did not round-trip")
    end)
end

function T.match_history_preserves_order_newest_first()
    withScratch("order", function(path)
        local player = PlayerModel.new()
        for i = 1, 5 do
            player:addMatchToHistory({ timestamp = 1000 + i, wpm = i * 10 })
        end

        H.isTrue(player:save(path))
        local loaded = PlayerModel.load(path)
        local history = loaded:getMatchHistory()

        H.equal(#history, 5, "history length changed across save/load")
        -- addMatchToHistory inserts at position 1, so the last one added
        -- (timestamp 1005) must be first, and order must be strictly descending.
        for i = 1, 5 do
            H.equal(history[i].timestamp, 1000 + (5 - i + 1), "history order lost at index " .. i)
        end
    end)
end

function T.match_history_capped_and_oldest_dropped()
    withScratch("cap", function(path)
        local player = PlayerModel.new()
        for i = 1, PlayerModel.MAX_MATCH_HISTORY + 5 do
            player:addMatchToHistory({ timestamp = i })
        end

        H.equal(#player.matchHistory, PlayerModel.MAX_MATCH_HISTORY, "history was not capped")
        H.equal(player.matchHistory[1].timestamp, PlayerModel.MAX_MATCH_HISTORY + 5,
            "newest entry should be at the front")

        for _, entry in ipairs(player.matchHistory) do
            H.isTrue(entry.timestamp > 5, "an entry older than the cap survived")
        end

        H.isTrue(player:save(path))
        local loaded = PlayerModel.load(path)
        H.equal(#loaded:getMatchHistory(), PlayerModel.MAX_MATCH_HISTORY,
            "cap was not preserved across save/load")
    end)
end

function T.legacy_format_save_is_migrated_without_losing_data()
    withScratch("legacy", function(path)
        -- Mimics a pre-serpent save. It's plain, valid Lua -- the old
        -- hand-rolled serializer's bug was silent misindexing, not invalid
        -- syntax -- so to deterministically exercise the "decode fails,
        -- legacy load succeeds" fallback we reference real globals
        -- (tostring/tonumber) that resolve under an unsandboxed load() but
        -- not under Serialize.decode's empty sandbox environment. That is
        -- exactly the gap the fallback covers.
        local legacyContent = [[
return {
    totalMoney = tonumber(tostring(275)),
    currentRound = 4,
    maxRoundReached = 4,
    selectedKeyboardLayout = "qwerty",
    matchHistory = {
        { timestamp = 1000, wpm = 42, accuracy = 91, keystrokes = 200, mistakes = 5, apm = 60, moneyEarned = 12 },
    },
    stats = {
        totalKeystrokes = 900,
        totalSessions = 3,
    },
    keyboard = {
        layoutType = "qwerty",
        name = "Legacy Keyboard",
        multiplier = 1.0,
        upgrades = { e = 0.2, t = 0.1 },
    },
}
]]

        H.isTrue(Serialize.decode(legacyContent) == nil,
            "test setup is broken: legacy content must NOT decode under the sandbox")

        love.filesystem.write(path, legacyContent)

        local player = PlayerModel.load(path)

        H.equal(player.totalMoney, 275, "legacy totalMoney lost")
        H.equal(player.currentRound, 4, "legacy currentRound lost")
        H.equal(player.stats.totalKeystrokes, 900, "legacy stat lost")
        H.near(player.keyboard:getKeyBonus("e"), 0.2, 1e-6, "legacy upgrade lost")
        H.equal(#player.matchHistory, 1, "legacy match history lost")
        H.equal(player.matchHistory[1].wpm, 42, "legacy match history content lost")

        -- The migration must have rewritten the file in the new, decodable format.
        local resaved = love.filesystem.read(path)
        local decoded = Serialize.decode(resaved)
        H.isTrue(decoded ~= nil, "migrated save was not rewritten in the new format")
        H.equal(decoded.totalMoney, 275)
    end)
end

function T.corrupt_or_truncated_save_falls_back_to_fresh_player()
    withScratch("corrupt", function(path)
        love.filesystem.write(path, "return { totalMoney = 50, keyboard = { upgrades = ")

        local player = H.succeeds(function() return PlayerModel.load(path) end,
            "a corrupt save file must not throw out of PlayerModel.load")

        H.isTrue(player ~= nil)
        H.equal(player.currentRound, 1, "fresh player should start at round 1")
        H.equal(type(player.totalMoney), "number")
    end)
end

function T.hostile_strings_round_trip()
    withScratch("hostile", function(path)
        local player = PlayerModel.new()
        player.keyboard.name = 'He said "hi"\nwith a\\backslash'
        player.keyboard.description = "line1\r\nline2\\tab? ]]==]"

        H.isTrue(player:save(path))
        local loaded = PlayerModel.load(path)

        H.equal(loaded.keyboard.name, player.keyboard.name, "quotes/newline/backslash string corrupted")
        H.equal(loaded.keyboard.description, player.keyboard.description, "hostile string corrupted")
    end)
end

function T.changeKeyboard_preserves_existing_upgrades()
    withScratch("changekb", function(path)
        -- PlayerModel.load binds savePath to `path` even when the file
        -- doesn't exist yet, so changeKeyboard's internal save() lands on
        -- the scratch file rather than save/player.lua.
        local player = PlayerModel.load(path)
        player.keyboard:upgradeKey("e", 0.25)
        player.keyboard:upgradeKey("t", 0.10)

        local newKeyboard = player:changeKeyboard("dvorak")

        H.equal(player.selectedKeyboardLayout, "dvorak")
        H.near(newKeyboard:getKeyBonus("e"), 0.25, 1e-6, "upgrade wiped by layout change")
        H.near(newKeyboard:getKeyBonus("t"), 0.10, 1e-6, "upgrade wiped by layout change")
    end)
end

function T.stat_reads_survive_a_save_missing_fields_entirely()
    withScratch("missingfields", function(path)
        -- A save written by a much older build that predates several stat
        -- fields and has no matchHistory/keyboard block at all.
        local minimal = Serialize.encode({ totalMoney = 10 })
        love.filesystem.write(path, minimal)

        local player = H.succeeds(function() return PlayerModel.load(path) end,
            "a save missing fields must not throw")

        H.equal(player.totalMoney, 10)
        for _, statName in ipairs(PlayerModel.STAT_FIELDS) do
            H.equal(player.stats[statName], 0, "missing stat field did not default to 0: " .. statName)
        end
        H.equal(#player:getMatchHistory(), 0)

        -- Reading through the public accessors and doing arithmetic on the
        -- result must not raise even though the save omitted these fields.
        H.succeeds(function()
            return (player:getStats().moneyEarned or 0) + (player:getStats().moneySpent or 0)
        end)
    end)
end

return T
