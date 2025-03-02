-- modules/util/statTrackingIntegration.lua
-- This module integrates all stat-tracking components and provides a high-level API
-- Enhanced with better error handling and fallbacks

local StatTrackingIntegration = {}

-- Dependencies
local PlayerModel = nil -- Late-require to avoid circular dependencies
local TextGenerator = nil
local TypingTrainer = nil
local StatVerifier = nil
local FileManager = nil

-- Flag to track if the module has been initialized
local initialized = false

-- Flag to track if file system operations are working
local fileSystemWorking = false

-- Safely require a module and handle errors
local function safeRequire(modulePath)
    local success, module = pcall(require, modulePath)
    if not success then
        print("StatTrackingIntegration: Error requiring " .. modulePath .. ": " .. tostring(module))
        return nil
    end
    return module
end

-- Initialize the stat tracking system
function StatTrackingIntegration.init()
    if initialized then
        return true
    end
    
    -- Load dependencies
    PlayerModel = safeRequire("modules/player/playerModel")
    TextGenerator = safeRequire("modules/typing/textGenerator")
    TypingTrainer = safeRequire("modules/typing/trainer")
    StatVerifier = safeRequire("modules/util/statVerifier")
    FileManager = safeRequire("modules/util/fileManager")
    
    -- Check if all required dependencies were loaded
    if not PlayerModel or not TextGenerator or not TypingTrainer then
        print("StatTrackingIntegration: Failed to load required dependencies")
        return false
    end
    
    -- Check if file system is working
    fileSystemWorking = false
    if FileManager then
        local testPath = "save/stat_tracking_test.tmp"
        local success = love.filesystem.write(testPath, "Test file system")
        if success then
            fileSystemWorking = true
            love.filesystem.remove(testPath)
            print("StatTrackingIntegration: File system checks passed")
        else
            print("StatTrackingIntegration: WARNING - File system writes not working, stats may not persist")
        end
    end
    
    print("StatTrackingIntegration: Initialized")
    initialized = true
    return true
end

-- Test if the file system is working
function StatTrackingIntegration.verifySystem()
    if not initialized then
        StatTrackingIntegration.init()
    end
    
    -- Check file system operations
    if FileManager then
        local testPath = "save/stat_verification.tmp"
        local writeSuccess = love.filesystem.write(testPath, "Verification test")
        
        if writeSuccess then
            love.filesystem.remove(testPath)
            print("StatTrackingIntegration: File system verification passed")
            
            -- Run more detailed verification if StatVerifier is available
            if StatVerifier then
                local verifyResult = StatVerifier.runIntegrationTest()
                print("StatTrackingIntegration: In-depth verification " .. 
                      (verifyResult and "passed" or "failed"))
                return verifyResult
            end
            
            return true
        else
            print("StatTrackingIntegration: File system verification failed - cannot write files")
            return false
        end
    end
    
    return false
end

-- Create a new training session with proper callbacks for stat tracking
function StatTrackingIntegration.createTrainingSession(options)
    local initSuccess = StatTrackingIntegration.init()
    if not initSuccess then
        print("StatTrackingIntegration: Failed to initialize, cannot create training session")
        return nil
    end
    
    options = options or {}
    
    -- Get player model
    local player
    local success, result = pcall(function()
        return options.player or PlayerModel.load()
    end)
    
    if success and result then
        player = result
    else
        print("StatTrackingIntegration: Failed to load player model: " .. tostring(result))
        print("StatTrackingIntegration: Creating new player model")
        player = PlayerModel.new()
    end
    
    -- Start session tracking in player model
    player:startSession()
    
    -- Get text from generator with appropriate difficulty
    local difficulty = options.difficulty or player:getCurrentDifficulty()
    local text = options.text
    
    if not text then
        local success, result = pcall(function()
            return TextGenerator:getRandomText(difficulty)
        end)
        
        if success and result then
            text = result
        else
            text = "The quick brown fox jumps over the lazy dog."
            print("StatTrackingIntegration: Using fallback text")
        end
    end
    
    -- Create a function to handle session completion
    local onCompleteWrapper = function(stats)
        print("StatTrackingIntegration: Session completed")
        print("StatTrackingIntegration: Stats - Keystrokes: " .. stats.keystrokes .. 
              ", Correct: " .. stats.correct .. ", Mistakes: " .. stats.mistakes)
        
        -- Calculate money earned based on score
        local moneyEarned = math.floor(stats.score * 0.5)
        stats.moneyEarned = moneyEarned
        
        -- Record session stats to player model with error handling
        local success, result = pcall(function()
            return player:endSession(stats)
        end)
        
        if not success then
            print("StatTrackingIntegration: Error updating player with session stats: " .. tostring(result))
            -- Try to handle the error by updating critical stats directly
            if player and player.stats then
                player.stats.totalKeystrokes = (player.stats.totalKeystrokes or 0) + (stats.keystrokes or 0)
                player.stats.totalCorrect = (player.stats.totalCorrect or 0) + (stats.correct or 0)
                player.stats.totalMistakes = (player.stats.totalMistakes or 0) + (stats.mistakes or 0)
            end
        end
        
        -- Add money to player
        local success, result = pcall(function()
            return player:addMoney(moneyEarned)
        end)
        
        if not success then
            print("StatTrackingIntegration: Error adding money to player: " .. tostring(result))
            -- Try direct money update if method failed
            if player then
                player.totalMoney = (player.totalMoney or 0) + moneyEarned
            end
        end
        
        -- Save player data with error handling
        local success, saveSuccess = pcall(function()
            return player:save()
        end)
        
        if not success then
            print("StatTrackingIntegration: Error saving player data: " .. tostring(saveSuccess))
            saveSuccess = false
        end
        
        print("StatTrackingIntegration: Save result: " .. (saveSuccess and "Success" or "Failed"))
        
        -- Call the original onComplete if provided
        if options.onComplete then
            pcall(options.onComplete, stats)
        end
        
        -- Verify stats if in debug mode and file system is working
        if _G and _G.DEBUG_MODE and StatVerifier and fileSystemWorking then
            print("StatTrackingIntegration: Verifying stats after session")
            pcall(StatVerifier.verifySavedStats)
        end
    end
    
    -- Create trainer with appropriate callbacks
    local trainerOptions = {
        text = text,
        difficulty = difficulty,
        displayName = options.displayName or ("Round " .. player.currentRound),
        keyboardModel = player.keyboard,
        onComplete = onCompleteWrapper,
        
        -- Forward other callbacks
        onKeyPressed = options.onKeyPressed,
        onKeyMissed = options.onKeyMissed,
        
        -- Forward UI options
        uiStyle = options.uiStyle
    }
    
    -- Create the trainer
    local trainer
    local success, result = pcall(function()
        return TypingTrainer.new(trainerOptions)
    end)
    
    if success then
        trainer = result
    else
        print("StatTrackingIntegration: Failed to create trainer: " .. tostring(result))
        return nil, player
    end
    
    return trainer, player
end

-- Get debug information about the stat tracking system
function StatTrackingIntegration.getDebugInfo()
    local initSuccess = StatTrackingIntegration.init()
    if not initSuccess then
        return {
            initialized = false,
            error = "Failed to initialize stat tracking system"
        }
    end
    
    local player
    local success, result = pcall(function()
        return PlayerModel.load()
    end)
    
    if success then
        player = result
    else
        return {
            initialized = true,
            playerLoaded = false,
            error = "Failed to load player: " .. tostring(result)
        }
    end
    
    local stats = player and player.stats or {}
    
    local debugInfo = {
        initialized = true,
        playerLoaded = (player ~= nil),
        fileSystemWorking = fileSystemWorking,
        totalSessions = stats.totalSessions or 0,
        totalKeystrokes = stats.totalKeystrokes or 0,
        totalMistakes = stats.totalMistakes or 0,
        totalCorrect = stats.totalCorrect or 0,
        bestWPM = stats.bestWPM or 0,
        saveFileExists = love.filesystem.getInfo("save/player.lua") ~= nil
    }
    
    return debugInfo
end

-- Reset the stat tracking system (for testing)
function StatTrackingIntegration.resetStats()
    local initSuccess = StatTrackingIntegration.init()
    if not initSuccess then
        print("StatTrackingIntegration: Failed to initialize, cannot reset stats")
        return false
    end
    
    -- Verify file system is working
    if not fileSystemWorking then
        print("StatTrackingIntegration: Cannot reset stats - file system not working")
        return false
    end
    
    local player
    local success, result = pcall(function()
        return PlayerModel.load()
    end)
    
    if success then
        player = result
    else
        print("StatTrackingIntegration: Failed to load player for reset: " .. tostring(result))
        
        -- Create a new player
        local success, result = pcall(function()
            return PlayerModel.new()
        end)
        
        if success then
            player = result
        else
            print("StatTrackingIntegration: Failed to create new player: " .. tostring(result))
            return false
        end
    end
    
    -- Reset stats
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
        moneySpent = 0
    }
    
    -- Reset other player attributes
    player.totalMoney = 50
    player.currentRound = 1
    player.maxRoundReached = 1
    
    -- Save the reset stats
    local saveSuccess
    local success, result = pcall(function()
        return player:save()
    end)
    
    if success then
        saveSuccess = result
    else
        print("StatTrackingIntegration: Error saving reset stats: " .. tostring(result))
        saveSuccess = false
    end
    
    return saveSuccess
end

return StatTrackingIntegration