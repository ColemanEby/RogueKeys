-- modules/util/statVerifier.lua
-- Utility for verifying that stats are being properly saved and loaded
-- Updated with error handling

local StatVerifier = {}

-- Check if player model stats are correctly loaded from save file
function StatVerifier.verifySavedStats()
    local success, PlayerModel = pcall(require, "modules/player/playerModel")
    if not success then
        print("StatVerifier: Failed to require PlayerModel: " .. tostring(PlayerModel))
        return false
    end
    
    print("StatVerifier: Starting saved stats verification")
    
    -- Try to load the save file directly
    local dataPath = "save/player.lua"
    
    -- Check if file exists
    if not love.filesystem.getInfo(dataPath) then
        print("StatVerifier: No save file found at " .. dataPath)
        return false
    end
    
    -- Load raw save data
    local success, chunk = pcall(love.filesystem.load, dataPath)
    if not success then
        print("StatVerifier: Error loading save file: " .. tostring(chunk))
        return false
    end
    
    -- Execute chunk to get the data table
    local success, rawData = pcall(chunk)
    if not success then
        print("StatVerifier: Error executing save file: " .. tostring(rawData))
        return false
    end
    
    -- Load the player model normally
    local success, player = pcall(PlayerModel.load)
    if not success then
        print("StatVerifier: Error loading player model: " .. tostring(player))
        return false
    end
    
    -- Compare key stats between raw data and loaded player model
    print("StatVerifier: Comparing saved stats with loaded stats")
    
    local rawStats = rawData.stats or {}
    local loadedStats = player and player.stats or {}
    
    -- Check key stats
    local keysToCheck = {
        "totalPlayTime", "totalSessions", "totalKeystrokes", 
        "totalMistakes", "totalCorrect", "bestAPM", 
        "bestWPM", "bestAccuracy", "bestStreak",
        "roundsWithoutError", "perfectRounds", 
        "moneyEarned", "moneySpent"
    }
    
    local allCorrect = true
    
    for _, key in ipairs(keysToCheck) do
        local rawValue = rawStats[key] or 0
        local loadedValue = loadedStats[key] or 0
        
        print(string.format("StatVerifier: %s - Saved: %s, Loaded: %s, Match: %s", 
            key, tostring(rawValue), tostring(loadedValue), tostring(rawValue == loadedValue)))
            
        if rawValue ~= loadedValue then
            allCorrect = false
        end
    end
    
    -- Check other player properties
    print(string.format("StatVerifier: totalMoney - Saved: %s, Loaded: %s, Match: %s",
        tostring(rawData.totalMoney or 0), tostring(player and player.totalMoney or 0), 
        tostring((rawData.totalMoney or 0) == (player and player.totalMoney or 0))))
        
    print(string.format("StatVerifier: currentRound - Saved: %s, Loaded: %s, Match: %s",
        tostring(rawData.currentRound or 1), tostring(player and player.currentRound or 1), 
        tostring((rawData.currentRound or 1) == (player and player.currentRound or 1))))
        
    if (rawData.totalMoney or 0) ~= (player and player.totalMoney or 0) or 
       (rawData.currentRound or 1) ~= (player and player.currentRound or 1) then
        allCorrect = false
    end
    
    print("StatVerifier: All stats match: " .. tostring(allCorrect))
    return allCorrect
end

-- Force a test save and load to verify functionality
function StatVerifier.testSaveAndLoad()
    local success, PlayerModel = pcall(require, "modules/player/playerModel")
    if not success then
        print("StatVerifier: Failed to require PlayerModel: " .. tostring(PlayerModel))
        return false
    end
    
    print("StatVerifier: Starting save and load test")
    
    -- Create a new player with some test stats
    local player = PlayerModel.new()
    player.stats.totalKeystrokes = 100
    player.stats.totalCorrect = 95
    player.stats.totalMistakes = 5
    player.stats.bestWPM = 50
    player.stats.bestAccuracy = 95
    player.totalMoney = 150
    
    -- Save the player data
    local saveSuccess = player:save()
    print("StatVerifier: Save result: " .. (saveSuccess and "Success" or "Failed"))
    
    if not saveSuccess then
        return false
    end
    
    -- Load the player data
    local loadSuccess, loadedPlayer
    loadSuccess, loadedPlayer = pcall(PlayerModel.load)
    if not loadSuccess then
        print("StatVerifier: Failed to load player: " .. tostring(loadedPlayer))
        return false
    end
    
    -- Compare key stats
    print("StatVerifier: Comparing test stats after save and load")
    print(string.format("totalKeystrokes: Original: %d, Loaded: %d", 
        player.stats.totalKeystrokes, loadedPlayer.stats.totalKeystrokes))
    print(string.format("totalCorrect: Original: %d, Loaded: %d", 
        player.stats.totalCorrect, loadedPlayer.stats.totalCorrect))
    print(string.format("bestWPM: Original: %f, Loaded: %f", 
        player.stats.bestWPM, loadedPlayer.stats.bestWPM))
    print(string.format("totalMoney: Original: %d, Loaded: %d", 
        player.totalMoney, loadedPlayer.totalMoney))
        
    -- Check if all key stats match
    local allMatch = (
        player.stats.totalKeystrokes == loadedPlayer.stats.totalKeystrokes and
        player.stats.totalCorrect == loadedPlayer.stats.totalCorrect and
        player.stats.bestWPM == loadedPlayer.stats.bestWPM and
        player.totalMoney == loadedPlayer.totalMoney
    )
    
    print("StatVerifier: All test stats match: " .. tostring(allMatch))
    return allMatch
end

-- Add an integration test entry point that can be called from debugging screens
function StatVerifier.runIntegrationTest()
    print("StatVerifier: Starting integration test")
    
    local success, testResult = pcall(StatVerifier.testSaveAndLoad)
    if not success then
        print("StatVerifier: Test save/load failed with error: " .. tostring(testResult))
        testResult = false
    end
    
    local success, verifyResult = pcall(StatVerifier.verifySavedStats)
    if not success then
        print("StatVerifier: Verify existing save failed with error: " .. tostring(verifyResult))
        verifyResult = false
    end
    
    print("StatVerifier: Integration test complete")
    print("StatVerifier: Test save/load: " .. (testResult and "PASSED" or "FAILED"))
    print("StatVerifier: Verify existing save: " .. (verifyResult and "PASSED" or "FAILED"))
    
    return testResult and verifyResult
end

return StatVerifier