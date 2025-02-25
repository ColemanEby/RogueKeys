-- modules/player/playerModel.lua
-- Enhanced player model with progression and statistics tracking

local KeyboardModel = require("modules/keyboard/keyboardModel")
local ConfigManager = require("engine/configManager")

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
end

-- End the current session and record stats
function PlayerModel:endSession(sessionStats)
    if not self.isInSession then return end

    self.isInSession = false
    local sessionTime = love.timer.getTime() - self.sessionStartTime

    -- Update stats
    self.stats.totalPlayTime = self.stats.totalPlayTime + sessionTime
    self.stats.totalSessions = self.stats.totalSessions + 1

    -- Add session-specific stats if provided
    if sessionStats then
        self.stats.totalKeystrokes = self.stats.totalKeystrokes + (sessionStats.keystrokes or 0)
        self.stats.totalMistakes = self.stats.totalMistakes + (sessionStats.mistakes or 0)
        self.stats.totalCorrect = self.stats.totalCorrect + (sessionStats.correct or 0)

        -- Update best values
        if sessionStats.apm and sessionStats.apm > self.stats.bestAPM then
            self.stats.bestAPM = sessionStats.apm
        end

        if sessionStats.wpm and sessionStats.wpm > self.stats.bestWPM then
            self.stats.bestWPM = sessionStats.wpm
        end

        if sessionStats.accuracy and sessionStats.accuracy > self.stats.bestAccuracy then
            self.stats.bestAccuracy = sessionStats.accuracy
        end

        if sessionStats.longestStreak and sessionStats.longestStreak > self.stats.bestStreak then
            self.stats.bestStreak = sessionStats.longestStreak
        end

        -- Check for perfect round
        if sessionStats.mistakes == 0 and sessionStats.keystrokes > 0 then
            self.stats.roundsWithoutError = self.stats.roundsWithoutError + 1
            self.stats.perfectRounds = self.stats.perfectRounds + 1
        end

        -- Record money earned
        if sessionStats.moneyEarned then
            self.stats.moneyEarned = self.stats.moneyEarned + sessionStats.moneyEarned
            self.totalMoney = self.totalMoney + sessionStats.moneyEarned
        end
    end

    -- Save player data
    self:save()
end

-- Add money to the player's total
function PlayerModel:addMoney(amount)
    self.totalMoney = self.totalMoney + amount
    self.stats.moneyEarned = self.stats.moneyEarned + amount
    return self.totalMoney
end

-- Spend money (returns true if successful)
function PlayerModel:spendMoney(amount)
    if self.totalMoney >= amount then
        self.totalMoney = self.totalMoney - amount
        self.stats.moneySpent = self.stats.moneySpent + amount
        return true
    end
    return false
end

-- Change the player's keyboard
function PlayerModel:changeKeyboard(keyboardLayout)
    self.selectedKeyboardLayout = keyboardLayout
    self.keyboard = KeyboardModel.new(keyboardLayout)
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

        -- Update max round reached
        if self.currentRound > self.maxRoundReached then
            self.maxRoundReached = self.currentRound
        end

        return true
    end

    return false
end

-- Reset progress (e.g., after game over)
function PlayerModel:resetProgress()
    self.currentRound = 1
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

-- Save player data to file
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

    -- Create save directory if it doesn't exist
    if not love.filesystem.getInfo("save") then
        love.filesystem.createDirectory("save")
    end

    -- Write to file
    local success, message = love.filesystem.write("save/player.lua", serialized)
    if not success then
        print("PlayerModel: Failed to save player data: " .. tostring(message))
        return false
    end

    return true
end

-- Load player data from file
function PlayerModel.load()
    local dataPath = "save/player.lua"

    -- Check if file exists
    if not love.filesystem.getInfo(dataPath) then
        print("PlayerModel: No save data found, creating new player")
        return PlayerModel.new()
    end

    -- Try to load the file
    local success, chunk = pcall(love.filesystem.load, dataPath)
    if not success then
        print("PlayerModel: Error loading save file: " .. tostring(chunk))
        return PlayerModel.new()
    end

    -- Try to execute the chunk to get the data table
    local success, data = pcall(chunk)
    if not success then
        print("PlayerModel: Error executing save file: " .. tostring(data))
        return PlayerModel.new()
    end

    -- Create a new player model
    local player = PlayerModel.new()

    -- Apply saved data
    player.totalMoney = data.totalMoney or player.totalMoney
    player.level = data.level or player.level
    player.currentRound = data.currentRound or player.currentRound
    player.maxRoundReached = data.maxRoundReached or player.maxRoundReached
    player.selectedKeyboardLayout = data.selectedKeyboardLayout or player.selectedKeyboardLayout

    -- Load keyboard data
    if data.keyboard then
        player.keyboard = KeyboardModel.deserialize(data.keyboard)
    end

    -- Load stats
    if data.stats then
        for k, v in pairs(data.stats) do
            player.stats[k] = v
        end
    end

    print("PlayerModel: Loaded player data")
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