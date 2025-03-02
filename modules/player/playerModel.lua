-- modules/player/playerModel.lua
-- Add required modules at the top
local FileManager = require("modules/util/fileManager")
local ConfigManager = require("engine/configManager")
local KeyboardModel = require("modules/keyboard/keyboardModel")

-- Fix for the PlayerModel class to ensure proper stats persistence

local PlayerModel = {}
PlayerModel.__index = PlayerModel

-- Create a new player model
function PlayerModel.new()
    local self = setmetatable({}, PlayerModel)

    -- Player economy and progression
    self.totalMoney = ConfigManager:get("progression.startingMoney", 50)
    self.level = 1
    self.currentRound = 1
    self.maxRoundReached = 1

    -- Player equipment
    self.keyboard = KeyboardModel.new("qwerty")  -- Default keyboard
    self.selectedKeyboardLayout = "qwerty"

    -- Player stats
    self.stats = {
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

    -- Session tracking
    self.sessionStartTime = 0
    self.isInSession = false

    return self
end

-- Start tracking a new typing session
function PlayerModel:startSession()
    self.isInSession = true
    self.sessionStartTime = love.timer.getTime()
    print("PlayerModel: Started new session")
end

-- End the current session and record stats
function PlayerModel:endSession(sessionStats)
    if not self.isInSession then 
        print("PlayerModel: Warning - endSession called when not in session")
        return 
    end

    self.isInSession = false
    local sessionTime = love.timer.getTime() - self.sessionStartTime

    -- Update stats
    self.stats.totalPlayTime = self.stats.totalPlayTime + sessionTime
    self.stats.totalSessions = self.stats.totalSessions + 1

    -- Add session-specific stats if provided
    if sessionStats then
        print("PlayerModel: Recording session stats")
        
        -- Update keystroke stats
        self.stats.totalKeystrokes = self.stats.totalKeystrokes + (sessionStats.keystrokes or 0)
        self.stats.totalMistakes = self.stats.totalMistakes + (sessionStats.mistakes or 0)
        self.stats.totalCorrect = self.stats.totalCorrect + (sessionStats.correct or 0)

        -- Log what we're recording for debugging
        print("PlayerModel: Keystrokes: " .. (sessionStats.keystrokes or 0) .. 
              ", Mistakes: " .. (sessionStats.mistakes or 0) .. 
              ", Correct: " .. (sessionStats.correct or 0))

        -- Update best values
        if sessionStats.apm and sessionStats.apm > self.stats.bestAPM then
            self.stats.bestAPM = sessionStats.apm
            print("PlayerModel: New best APM: " .. self.stats.bestAPM)
        end

        if sessionStats.wpm and sessionStats.wpm > self.stats.bestWPM then
            self.stats.bestWPM = sessionStats.wpm
            print("PlayerModel: New best WPM: " .. self.stats.bestWPM)
        end

        if sessionStats.accuracy and sessionStats.accuracy > self.stats.bestAccuracy then
            self.stats.bestAccuracy = sessionStats.accuracy
            print("PlayerModel: New best accuracy: " .. self.stats.bestAccuracy)
        end

        if sessionStats.longestStreak and sessionStats.longestStreak > self.stats.bestStreak then
            self.stats.bestStreak = sessionStats.longestStreak
            print("PlayerModel: New best streak: " .. self.stats.bestStreak)
        end

        -- Check for perfect round
        if sessionStats.mistakes == 0 and sessionStats.keystrokes > 0 then
            self.stats.roundsWithoutError = self.stats.roundsWithoutError + 1
            self.stats.perfectRounds = self.stats.perfectRounds + 1
            print("PlayerModel: Perfect round achieved!")
        end

        -- Record money earned
        if sessionStats.moneyEarned then
            self.stats.moneyEarned = self.stats.moneyEarned + sessionStats.moneyEarned
            print("PlayerModel: Money earned: " .. sessionStats.moneyEarned)
        end
    else
        print("PlayerModel: Warning - No session stats provided")
    end

    -- Save player data immediately after updating stats
    local saveSuccess = self:save()
    print("PlayerModel: Session stats saved: " .. (saveSuccess and "Success" or "Failed"))
    
    return saveSuccess
end

-- Add money to the player's total
function PlayerModel:addMoney(amount)
    if amount <= 0 then return self.totalMoney end
    
    self.totalMoney = self.totalMoney + amount
    self.stats.moneyEarned = self.stats.moneyEarned + amount
    print("PlayerModel: Added " .. amount .. " money, total now: " .. self.totalMoney)
    return self.totalMoney
end

-- Spend money (returns true if successful)
function PlayerModel:spendMoney(amount)
    if self.totalMoney >= amount then
        self.totalMoney = self.totalMoney - amount
        self.stats.moneySpent = self.stats.moneySpent + amount
        print("PlayerModel: Spent " .. amount .. " money, remaining: " .. self.totalMoney)
        return true
    end
    print("PlayerModel: Not enough money to spend " .. amount)
    return false
end

-- Change the player's keyboard
function PlayerModel:changeKeyboard(keyboardLayout)
    self.selectedKeyboardLayout = keyboardLayout
    self.keyboard = KeyboardModel.new(keyboardLayout)
    print("PlayerModel: Changed keyboard to " .. keyboardLayout)
    return self.keyboard
end

-- Calculate the required score for the current round
function PlayerModel:getRequiredScore()
    local baseRequirement = ConfigManager:get("progression.baseRequiredScore", 20)
    local scaleFactor = ConfigManager:get("progression.roundDifficultyScale", 1.2)

    return math.floor(baseRequirement * (self.currentRound ^ scaleFactor))
end

-- Advance to the next round if score is sufficient
function PlayerModel:advanceRound(score)
    local requiredScore = self:getRequiredScore()

    if score >= requiredScore then
        self.currentRound = self.currentRound + 1
        print("PlayerModel: Advanced to round " .. self.currentRound)

        -- Update max round reached
        if self.currentRound > self.maxRoundReached then
            self.maxRoundReached = self.currentRound
            print("PlayerModel: New max round reached: " .. self.maxRoundReached)
        end

        -- Save after advancing
        self:save()
        return true
    end

    return false
end

-- Reset progress (e.g., after game over)
function PlayerModel:resetProgress()
    self.currentRound = 1
    print("PlayerModel: Progress reset")
    self:save()
    return self.currentRound
end

-- Get difficulty based on current round
function PlayerModel:getCurrentDifficulty()
    if self.currentRound < 3 then
        return "easy"
    elseif self.currentRound < 7 then
        return "medium"
    else
        return "hard"
    end
end

-- Get complete stats
function PlayerModel:getStats()
    return self.stats
end

-- Replace the save method with this version
function PlayerModel:save()
    local data = {
        totalMoney = self.totalMoney,
        level = self.level,
        currentRound = self.currentRound,
        maxRoundReached = self.maxRoundReached,
        selectedKeyboardLayout = self.selectedKeyboardLayout,
        keyboard = self.keyboard:serialize(),
        stats = self.stats
    }

    local serialized = "return " .. self:serializeTable(data)

    -- Ensure save directory exists and save using FileManager
    FileManager.ensureDirectoryExists("save")
    local success = FileManager.saveToFile("save/player.lua", serialized)
    
    if not success then
        print("PlayerModel: Failed to save player data")
        return false
    end

    print("PlayerModel: Successfully saved player data")
    
    -- Debug print stats that were saved
    print("PlayerModel: Saved stats - Total sessions: " .. self.stats.totalSessions .. 
          ", Total keystrokes: " .. self.stats.totalKeystrokes)
          
    return true
end

function PlayerModel.load()
    local dataPath = "save/player.lua"
    
    -- Load data using FileManager
    local content, error = FileManager.loadFromFile(dataPath)
    
    if not content then
        print("PlayerModel: No save data found or couldn't be loaded, creating new player")
        return PlayerModel.new()
    end

    -- Parse the Lua code
    local func, err = load(content)
    if not func then
        print("PlayerModel: Error parsing save file: " .. tostring(err))
        return PlayerModel.new()
    end

    -- Execute the function to get the data table
    local success, data = pcall(func)
    if not success then
        print("PlayerModel: Error executing save file: " .. tostring(data))
        return PlayerModel.new()
    end

    -- Create a new player model
    local player = PlayerModel.new()

    -- Apply saved data with safety checks
    player.totalMoney = data.totalMoney or player.totalMoney
    player.level = data.level or player.level
    player.currentRound = data.currentRound or player.currentRound
    player.maxRoundReached = data.maxRoundReached or player.maxRoundReached
    player.selectedKeyboardLayout = data.selectedKeyboardLayout or player.selectedKeyboardLayout

    -- Load keyboard data
    if data.keyboard then
        player.keyboard = KeyboardModel.deserialize(data.keyboard)
    end

    -- Load stats with safety checks
    if data.stats then
        for k, v in pairs(data.stats) do
            player.stats[k] = v
        end
    end

    print("PlayerModel: Loaded player data")
    
    -- Debug print loaded stats
    print("PlayerModel: Loaded stats - Total sessions: " .. player.stats.totalSessions .. 
          ", Total keystrokes: " .. player.stats.totalKeystrokes)
          
    return player
end

-- Serialize a table to a string
function PlayerModel:serializeTable(tbl, indent)
    if not indent then indent = 0 end
    local result = "{\n"

    for k, v in pairs(tbl) do
        result = result .. string.rep("    ", indent + 1)

        -- Handle the key
        if type(k) == "number" then
            -- Array index
            result = result .. ""
        elseif type(k) == "string" then
            -- String key needs quotes if not a valid identifier
            if k:match("^[%a_][%w_]*$") then
                result = result .. k .. " = "
            else
                result = result .. "[\"" .. k .. "\"] = "
            end
        else
            -- Other key types in brackets
            result = result .. "[" .. tostring(k) .. "] = "
        end

        -- Handle the value
        if type(v) == "table" then
            result = result .. self:serializeTable(v, indent + 1)
        elseif type(v) == "string" then
            result = result .. "\"" .. v .. "\""
        else
            result = result .. tostring(v)
        end

        result = result .. ",\n"
    end

    -- Close the table
    result = result .. string.rep("    ", indent) .. "}"
    return result
end

return PlayerModel