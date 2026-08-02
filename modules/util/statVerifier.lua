-- modules/util/statVerifier.lua
-- Read-only sanity check: compares the raw save file on disk against what
-- PlayerModel.load() produces.
--
-- This module used to also expose testSaveAndLoad, which built a throwaway
-- player with fake stats and called player:save() to check the round trip.
-- PlayerModel:save() always writes to save/player.lua with no way to redirect
-- it to a scratch path, so that "test" silently overwrote the real player's
-- save file every time it ran -- reachable from a debug-mode button in
-- statsState. It has been removed rather than kept as a live way to destroy
-- progress. Everything below only reads the save file; it never writes it.

local StatVerifier = {}

local Log = require("modules/util/debugHelper").forModule("StatVerifier")

local STATS_KEYS = {
    "totalPlayTime", "totalSessions", "totalKeystrokes",
    "totalMistakes", "totalCorrect", "bestAPM",
    "bestWPM", "bestAccuracy", "bestStreak",
    "roundsWithoutError", "perfectRounds",
    "moneyEarned", "moneySpent",
}

-- Check that the player model's in-memory stats match what is actually on
-- disk. Read-only.
function StatVerifier.verifySavedStats()
    local reqOk, PlayerModel = pcall(require, "modules/player/playerModel")
    if not reqOk then
        Log.warn("Failed to require PlayerModel: %s", tostring(PlayerModel))
        return false
    end

    local dataPath = "save/player.lua"
    if not love.filesystem.getInfo(dataPath) then
        Log.info("No save file found at %s", dataPath)
        return false
    end

    local loadOk, chunk = pcall(love.filesystem.load, dataPath)
    if not loadOk then
        Log.warn("Error loading save file: %s", tostring(chunk))
        return false
    end

    local runOk, rawData = pcall(chunk)
    if not runOk or type(rawData) ~= "table" then
        Log.warn("Error executing save file: %s", tostring(rawData))
        return false
    end

    local playerOk, player = pcall(PlayerModel.load)
    if not playerOk then
        Log.warn("Error loading player model: %s", tostring(player))
        return false
    end

    local rawStats = rawData.stats or {}
    local loadedStats = player and player.stats or {}

    local allCorrect = true
    for _, key in ipairs(STATS_KEYS) do
        local rawValue = rawStats[key] or 0
        local loadedValue = loadedStats[key] or 0
        if rawValue ~= loadedValue then
            allCorrect = false
            Log.debug("%s mismatch - saved: %s, loaded: %s", key, tostring(rawValue), tostring(loadedValue))
        end
    end

    if (rawData.totalMoney or 0) ~= (player and player.totalMoney or 0) or
       (rawData.currentRound or 1) ~= (player and player.currentRound or 1) then
        allCorrect = false
    end

    Log.info("All stats match: %s", tostring(allCorrect))
    return allCorrect
end

-- Entry point used by debug screens. Read-only -- see the module comment.
function StatVerifier.runIntegrationTest()
    local ok, result = pcall(StatVerifier.verifySavedStats)
    if not ok then
        Log.warn("verifySavedStats raised an error: %s", tostring(result))
        return false
    end
    return result
end

return StatVerifier
