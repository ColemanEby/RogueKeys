-- modules/player/playerModel.lua
-- Player model with improved file handling for reliable stat tracking

local FileManager = require("modules/util/fileManager")
local ConfigManager = require("engine/configManager")
local KeyboardModel = require("modules/keyboard/keyboardModel")

local PlayerModel = {}
PlayerModel.__index = PlayerModel

-- Create a new player model
function PlayerModel.new()
    local self = setmetatable({}, PlayerModel)

    -- Player economy and progression
    local startingMoney = 50
    
    -- Try to get from config, default to 50 if not available
    local configSuccess, configMoney = pcall(function() 
        return ConfigManager:get("progression.startingMoney", 50)
    end)
    
    if configSuccess and configMoney then
        startingMoney = configMoney
    end
    
    self.totalMoney = startingMoney
    self.level = 1
    self.currentRound = 1
    self.maxRoundReached = 1

    -- Player equipment - with error handling
    local keyboardSuccess, keyboard = pcall(function()
        return KeyboardModel.new("qwerty")
    end)
    
    if keyboardSuccess and keyboard then
        self.keyboard = keyboard
    else
        print("PlayerModel: Failed to create keyboard model, using minimal fallback")
        -- Create a minimal keyboard model directly
        self.keyboard = {
            layoutType = "qwerty",
            name = "Fallback Keyboard",
            description = "Fallback keyboard for error recovery",
            multiplier = 1.0,
            upgrades = {},
            
            -- Add minimal required methods
            upgradeKey = function(self, key, bonus)
                key = string.lower(key)
                self.upgrades[key] = (self.upgrades[key] or 0) + bonus
                return self.upgrades[key]
            end,
            isKeyUpgraded = function(self, key)
                key = string.lower(key)
                return self.upgrades[key] ~= nil and self.upgrades[key] > 0
            end,
            getKeyBonus = function(self, key)
                key = string.lower(key)
                return self.upgrades[key] or 0
            end,
            getTotalMultiplier = function(self)
                return self.multiplier
            end,
            serialize = function(self)
                return {
                    layoutType = self.layoutType,
                    name = self.name,
                    description = self.description,
                    multiplier = self.multiplier,
                    upgrades = self.upgrades
                }
            end
        }
        setmetatable(self.keyboard, {__index = self.keyboard})
    end
    
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
        -- Update keystroke stats with safety checks
        if sessionStats.keystrokes and type(sessionStats.keystrokes) == "number" then
            self.stats.totalKeystrokes = self.stats.totalKeystrokes + sessionStats.keystrokes
        end
        
        if sessionStats.mistakes and type(sessionStats.mistakes) == "number" then
            self.stats.totalMistakes = self.stats.totalMistakes + sessionStats.mistakes
        end
        
        if sessionStats.correct and type(sessionStats.correct) == "number" then
            self.stats.totalCorrect = self.stats.totalCorrect + sessionStats.correct
        end

        -- Log what we're recording for debugging
        print("PlayerModel: Keystrokes: " .. (sessionStats.keystrokes or 0) .. 
              ", Mistakes: " .. (sessionStats.mistakes or 0) .. 
              ", Correct: " .. (sessionStats.correct or 0))

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
        if sessionStats.moneyEarned and type(sessionStats.moneyEarned) == "number" then
            self.stats.moneyEarned = self.stats.moneyEarned + sessionStats.moneyEarned
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
    if not amount or type(amount) ~= "number" or amount <= 0 then 
        return self.totalMoney 
    end
    
    self.totalMoney = self.totalMoney + amount
    self.stats.moneyEarned = self.stats.moneyEarned + amount
    print("PlayerModel: Added " .. amount .. " money, total now: " .. self.totalMoney)
    
    -- Save after money changes
    self:save()
    
    return self.totalMoney
end

-- Spend money (returns true if successful)
function PlayerModel:spendMoney(amount)
    if not amount or type(amount) ~= "number" then
        return false
    end
    
    if self.totalMoney >= amount then
        self.totalMoney = self.totalMoney - amount
        self.stats.moneySpent = self.stats.moneySpent + amount
        print("PlayerModel: Spent " .. amount .. " money, remaining: " .. self.totalMoney)
        
        -- Save after money changes
        self:save()
        
        return true
    end
    print("PlayerModel: Not enough money to spend " .. amount)
    return false
end

-- Change the player's keyboard
function PlayerModel:changeKeyboard(keyboardLayout)
    if not keyboardLayout then return self.keyboard end
    
    local success, keyboard = pcall(function()
        return KeyboardModel.new(keyboardLayout)
    end)
    
    if success and keyboard then
        self.selectedKeyboardLayout = keyboardLayout
        self.keyboard = keyboard
        print("PlayerModel: Changed keyboard to " .. keyboardLayout)
        
        -- Save after keyboard changes
        self:save()
        
        return self.keyboard
    else
        print("PlayerModel: Failed to change keyboard, keeping current one")
        return self.keyboard
    end
end

-- Calculate the required score for the current round
function PlayerModel:getRequiredScore()
    local baseRequirement = 20
    local scaleFactor = 1.2
    
    -- Try to get from config
    local configSuccess, configBase = pcall(function() 
        return ConfigManager:get("progression.baseRequiredScore", 20)
    end)
    
    if configSuccess and configBase then
        baseRequirement = configBase
    end
    
    local scaleSuccess, configScale = pcall(function() 
        return ConfigManager:get("progression.roundDifficultyScale", 1.2)
    end)
    
    if scaleSuccess and configScale then
        scaleFactor = configScale
    end

    return math.floor(baseRequirement * (self.currentRound ^ scaleFactor))
end

-- Advance to the next round if score is sufficient
function PlayerModel:advanceRound(score)
    if not score or type(score) ~= "number" then
        return false
    end
    
    local requiredScore = self:getRequiredScore()

    if score >= requiredScore then
        self.currentRound = self.currentRound + 1
        print("PlayerModel: Advanced to round " .. self.currentRound)

        -- Update max round reached
        if self.currentRound > self.maxRoundReached then
            self.maxRoundReached = self.currentRound
            print("PlayerModel: New max round reached: " .. self.maxRoundReached)
        end

        -- Save after advancing round
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

-- Improved save method with better error handling
function PlayerModel:save()
    -- Prepare data structure for serialization
    local data = {
        totalMoney = self.totalMoney,
        level = self.level,
        currentRound = self.currentRound,
        maxRoundReached = self.maxRoundReached,
        selectedKeyboardLayout = self.selectedKeyboardLayout,
        stats = self.stats
    }
    
    -- Safely serialize keyboard
    local keyboardSuccess, serializedKeyboard = pcall(function()
        return self.keyboard:serialize()
    end)
    
    if keyboardSuccess and serializedKeyboard then
        data.keyboard = serializedKeyboard
    else
        print("PlayerModel: Warning - Failed to serialize keyboard")
        -- Create minimal keyboard data
        data.keyboard = {
            layoutType = self.selectedKeyboardLayout or "qwerty",
            name = "Backup Keyboard",
            multiplier = 1.0,
            upgrades = {}
        }
    end

    -- Serialize to string
    local serialized = "return " .. self:serializeTable(data)

    -- Ensure save directory exists
    FileManager.ensureDirectoryExists("save")
    
    -- Try to save using FileManager
    local success = FileManager.saveToFile("save/player.lua", serialized)
    
    if not success then
        print("PlayerModel: ERROR - Failed to save player data")
        
        -- Try a last resort direct save
        local directSuccess = love.filesystem.write("save/player_backup.lua", serialized)
        if directSuccess then
            print("PlayerModel: Created backup save file instead")
            return true
        end
        
        return false
    end

    print("PlayerModel: Successfully saved player data")
    return true
end

-- Enhanced load method with improved error handling
function PlayerModel.load()
    local dataPath = "save/player.lua"
    local backupPath = "save/player_backup.lua"
    
    -- First try to load the primary save file
    local content = FileManager.loadFromFile(dataPath)
    
    -- If primary save failed, try the backup
    if not content then
        print("PlayerModel: Primary save not found, trying backup...")
        content = FileManager.loadFromFile(backupPath)
    end
    
    -- If no save data found, create a new player
    if not content then
        print("PlayerModel: No save data found, creating new player")
        return PlayerModel.new()
    end

    -- Parse the Lua code with error handling
    local func, err = load(content)
    if not func then
        print("PlayerModel: Error parsing save file: " .. tostring(err))
        return PlayerModel.new()
    end

    -- Execute the function to get the data table
    local success, data = pcall(func)
    if not success or type(data) ~= "table" then
        print("PlayerModel: Error executing save file: " .. tostring(data))
        return PlayerModel.new()
    end

    -- Create a new player model
    local player = PlayerModel.new()

    -- Apply saved data with safety checks
    if data.totalMoney and type(data.totalMoney) == "number" then
        player.totalMoney = data.totalMoney
    end
    
    if data.level and type(data.level) == "number" then
        player.level = data.level
    end
    
    if data.currentRound and type(data.currentRound) == "number" then
        player.currentRound = data.currentRound
    end
    
    if data.maxRoundReached and type(data.maxRoundReached) == "number" then
        player.maxRoundReached = data.maxRoundReached
    end
    
    if data.selectedKeyboardLayout and type(data.selectedKeyboardLayout) == "string" then
        player.selectedKeyboardLayout = data.selectedKeyboardLayout
    end

    -- Load keyboard data with error handling
    if data.keyboard and type(data.keyboard) == "table" then
        local keyboardSuccess, keyboard = pcall(function()
            return KeyboardModel.deserialize(data.keyboard)
        end)
        
        if keyboardSuccess and keyboard then
            player.keyboard = keyboard
        else
            print("PlayerModel: Failed to deserialize keyboard, using default")
            player.keyboard = KeyboardModel.new(player.selectedKeyboardLayout)
        end
    end

    -- Load stats with safety checks
    if data.stats and type(data.stats) == "table" then
        -- Process each stat individually for safety
        local statsList = {
            "totalPlayTime", "totalSessions", "totalKeystrokes",
            "totalMistakes", "totalCorrect", "bestAPM",
            "bestWPM", "bestAccuracy", "bestStreak",
            "roundsWithoutError", "perfectRounds",
            "moneyEarned", "moneySpent"
        }
        
        for _, statName in ipairs(statsList) do
            if data.stats[statName] and type(data.stats[statName]) == "number" then
                player.stats[statName] = data.stats[statName]
            end
        end
    end

    print("PlayerModel: Successfully loaded player data")
    
    -- Debug print loaded stats
    print("PlayerModel: Loaded stats - Total sessions: " .. player.stats.totalSessions .. 
          ", Total keystrokes: " .. player.stats.totalKeystrokes)
          
    return player
end

-- Serialize a table to a string (more robust version)
function PlayerModel:serializeTable(tbl, indent)
    if not tbl then return "{}" end
    if not indent then indent = 0 end
    
    local result = "{\n"
    
    -- Use pcall to catch any serialization errors
    local success, serialized = pcall(function()
        local innerResult = ""
        for k, v in pairs(tbl) do
            innerResult = innerResult .. string.rep("    ", indent + 1)
    
            -- Handle the key
            if type(k) == "number" then
                -- Array index
                innerResult = innerResult .. ""
            elseif type(k) == "string" then
                -- String key needs quotes if not a valid identifier
                if k:match("^[%a_][%w_]*$") then
                    innerResult = innerResult .. k .. " = "
                else
                    innerResult = innerResult .. "[\"" .. k .. "\"] = "
                end
            else
                -- Other key types in brackets
                innerResult = innerResult .. "[" .. tostring(k) .. "] = "
            end
    
            -- Handle the value based on type
            if type(v) == "table" then
                innerResult = innerResult .. self:serializeTable(v, indent + 1)
            elseif type(v) == "string" then
                innerResult = innerResult .. "\"" .. v:gsub("\"", "\\\"") .. "\""
            elseif type(v) == "number" or type(v) == "boolean" then
                innerResult = innerResult .. tostring(v)
            else
                innerResult = innerResult .. "\"" .. tostring(v) .. "\""
            end
    
            innerResult = innerResult .. ",\n"
        end
        return innerResult
    end)
    
    if success then
        result = result .. serialized
    else
        print("PlayerModel: Error during serialization: " .. tostring(serialized))
        result = result .. string.rep("    ", indent + 1) .. "-- Serialization error\n"
    end

    -- Close the table
    result = result .. string.rep("    ", indent) .. "}"
    return result
end

return PlayerModel