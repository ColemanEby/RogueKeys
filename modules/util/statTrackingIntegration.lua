-- modules/util/statTrackingIntegration.lua
-- Player-stat bootstrapping and debug/reset helpers.
--
-- This module used to also expose createTrainingSession, a second "correct"
-- session pipeline (start session -> run trainer -> record stats -> save)
-- that duplicated the logic roundState implements directly. Nothing ever
-- called createTrainingSession -- roundState was, and remains, the only path
-- that actually runs a round. Keeping both would mean two competing
-- implementations of the same bookkeeping drifting apart, so the dead one was
-- deleted rather than patched up. What is left is the bootstrapping/debug
-- surface, updated to go through Context.player() instead of calling
-- PlayerModel.load() directly (three call sites used to do that, each risking
-- yet another out-of-sync player copy).

local StatTrackingIntegration = {}

local Log = require("modules/util/debugHelper").forModule("StatTracking")
local Context = require("modules/game/context")

local initialized = false
local fileSystemWorking = false

-- Initialize the stat tracking system: currently just a file-system write
-- check so callers know whether stats can persist at all.
function StatTrackingIntegration.init()
    if initialized then
        return true
    end

    fileSystemWorking = false
    local testPath = "save/stat_tracking_test.tmp"
    local success = love.filesystem.write(testPath, "Test file system")
    if success then
        fileSystemWorking = true
        love.filesystem.remove(testPath)
    else
        Log.warn("File system writes not working, stats may not persist")
    end

    initialized = true
    return true
end

-- Snapshot of the player's stats, for debug overlays / dev screens.
function StatTrackingIntegration.getDebugInfo()
    StatTrackingIntegration.init()

    local ok, player = pcall(Context.player)
    if not ok or not player then
        return {
            initialized = initialized,
            playerLoaded = false,
            error = "Failed to load player: " .. tostring(player),
        }
    end

    local stats = player.stats or {}

    return {
        initialized = initialized,
        playerLoaded = true,
        fileSystemWorking = fileSystemWorking,
        totalSessions = stats.totalSessions or 0,
        totalKeystrokes = stats.totalKeystrokes or 0,
        totalMistakes = stats.totalMistakes or 0,
        totalCorrect = stats.totalCorrect or 0,
        bestWPM = stats.bestWPM or 0,
        saveFileExists = love.filesystem.getInfo("save/player.lua") ~= nil,
    }
end

-- Reset stats on the live (Context-owned) player. Used by debug tooling.
function StatTrackingIntegration.resetStats()
    StatTrackingIntegration.init()

    if not fileSystemWorking then
        Log.warn("Cannot reset stats - file system not working")
        return false
    end

    local ok, player = pcall(Context.player)
    if not ok or not player then
        Log.warn("Failed to load player for reset: %s", tostring(player))
        return false
    end

    player.stats = {
        totalPlayTime = 0,
        totalSessions = 0,
        totalKeystrokes = 0,
        totalMistakes = 0,
        totalCorrect = 0,
        bestAPM = 0,
        bestWPM = 0,
        bestAccuracy = 0,
        bestStreak = 0,
        roundsWithoutError = 0,
        perfectRounds = 0,
        moneyEarned = 0,
        moneySpent = 0,
    }
    player.totalMoney = 50
    player.currentRound = 1
    player.maxRoundReached = 1

    local saveOk, saveSuccess = pcall(function() return player:save() end)
    if not saveOk then
        Log.warn("Error saving reset stats: %s", tostring(saveSuccess))
        return false
    end
    return saveSuccess
end

return StatTrackingIntegration
