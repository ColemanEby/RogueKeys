-- tests/test_steam.lua
-- The dev/CI environment has no Steamworks SDK and no steam_appid.txt, so
-- luasteam never loads here. This suite locks down the property that matters
-- most: every call is a safe no-op in that state, so game code never has to
-- guard calls behind Steam.isAvailable().

local H = require("tests/helpers")
local Steam = require("modules/steam/steam")
local TypingTrainer = require("modules/typing/trainer")
local PlayerModel = require("modules/player/playerModel")

local T = {}

function T.init_reports_unavailable_when_luasteam_is_absent()
    -- Headless tests run with no window and no Steamworks SDK -- init must
    -- report false, not raise.
    local ok = Steam.init()
    H.isFalse(ok, "Steam.init() must return false with no luasteam module present")
    H.isFalse(Steam.isAvailable())
end

function T.all_calls_are_safe_noops_when_unavailable()
    H.succeeds(function() Steam.unlockAchievement("FIRST_RUN") end)
    H.succeeds(function() Steam.setStat("rounds_played", 1) end)
    H.succeeds(function() Steam.store() end)
    H.succeeds(function() Steam.update() end)
    H.succeeds(function() Steam.shutdown() end)
end

function T.unlock_achievement_ignores_nil_id()
    H.succeeds(function() Steam.unlockAchievement(nil) end)
end

function T.set_stat_ignores_nil_name()
    H.succeeds(function() Steam.setStat(nil, 5) end)
end

function T.repeated_unlocks_of_the_same_achievement_are_cheap_and_safe()
    for _ = 1, 5 do
        H.succeeds(function() Steam.unlockAchievement("PERFECT_ROUND") end)
    end
end

-- Stat-threshold achievement triggers --------------------------------------

function T.first_correct_keystroke_unlocks_first_keystroke()
    Steam.shutdown()
    local trainer = TypingTrainer.new({ text = "ab" })
    trainer:handleInput("a")
    H.isTrue(Steam.isAchievementSent("FIRST_KEYSTROKE"))
end

function T.streak_of_50_unlocks_in_the_zone()
    Steam.shutdown()
    local trainer = TypingTrainer.new({ text = string.rep("a", 50) })
    for i = 1, 50 do
        trainer:handleInput("a")
    end
    H.isTrue(Steam.isAchievementSent("STREAK_50"))
    H.isFalse(Steam.isAchievementSent("STREAK_200"))
end

function T.streak_of_200_unlocks_unbroken()
    Steam.shutdown()
    local trainer = TypingTrainer.new({ text = string.rep("a", 200) })
    for i = 1, 200 do
        trainer:handleInput("a")
    end
    H.isTrue(Steam.isAchievementSent("STREAK_200"))
end

function T.perfect_round_unlocks_flawless()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 10, mistakes = 0, correct = 10, accuracy = 100, wpm = 0 })
    H.isTrue(Steam.isAchievementSent("PERFECT_ROUND"))
    H.isFalse(Steam.isAchievementSent("FIVE_PERFECT_ROUNDS"))
end

function T.five_perfect_rounds_unlocks_precision_machine()
    Steam.shutdown()
    local player = PlayerModel.new()
    for i = 1, 5 do
        player:startSession()
        player:endSession({ keystrokes = 10, mistakes = 0, correct = 10, accuracy = 100, wpm = 0 })
    end
    H.isTrue(Steam.isAchievementSent("PERFECT_ROUND"))
    H.isTrue(Steam.isAchievementSent("FIVE_PERFECT_ROUNDS"))
end

function T.wpm_60_unlocks_speed_typer()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 60, mistakes = 0, correct = 60, accuracy = 100, wpm = 60 })
    H.isTrue(Steam.isAchievementSent("WPM_60"))
    H.isFalse(Steam.isAchievementSent("WPM_100"))
end

function T.wpm_100_unlocks_triple_digit()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 100, mistakes = 0, correct = 100, accuracy = 100, wpm = 100 })
    H.isTrue(Steam.isAchievementSent("WPM_60"))
    H.isTrue(Steam.isAchievementSent("WPM_100"))
    H.isFalse(Steam.isAchievementSent("WPM_150"))
end

function T.wpm_150_unlocks_inhuman()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 150, mistakes = 0, correct = 150, accuracy = 100, wpm = 150 })
    H.isTrue(Steam.isAchievementSent("WPM_60"))
    H.isTrue(Steam.isAchievementSent("WPM_100"))
    H.isTrue(Steam.isAchievementSent("WPM_150"))
end

function T.perfect_accuracy_over_100_keystrokes_unlocks_accuracy_surgeon()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 100, mistakes = 0, correct = 100, accuracy = 100, wpm = 0 })
    H.isTrue(Steam.isAchievementSent("ACCURACY_SURGEON"))
end

return T
