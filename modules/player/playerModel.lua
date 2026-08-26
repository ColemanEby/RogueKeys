-- modules/player/playerModel.lua
-- Player model with improved file handling for reliable stat tracking

local FileManager = require("modules/util/fileManager")
local ConfigManager = require("engine/configManager")
local KeyboardModel = require("modules/keyboard/keyboardModel")
local Serialize = require("modules/util/serialize")
local Steam = require("modules/steam/steam")

local PlayerModel = {}
PlayerModel.__index = PlayerModel

-- Stats screens and the WPM-over-time graph both want real history depth.
PlayerModel.MAX_MATCH_HISTORY = 100

local SAVE_PATH = "save/player.lua"

-- Exposed publicly so callers (and tests) that need to know which stat keys
-- exist don't have to hand-maintain a second copy of this list.
PlayerModel.STAT_FIELDS = {
    "totalPlayTime", "totalSessions", "totalKeystrokes",
    "totalMistakes", "totalCorrect", "bestAPM",
    "bestWPM", "bestAccuracy", "bestStreak",
    "roundsWithoutError", "perfectRounds",
    "moneyEarned", "moneySpent"
}

function PlayerModel.backupPathFor(path)
    return (path:gsub("%.lua$", "_backup.lua"))
end

-- Bump t[key] to value if value is present and larger than the current max.
local function bumpMax(t, key, value)
    if value and value > (t[key] or 0) then
        t[key] = value
    end
end

-- Per-run counters, distinct from the lifetime `stats` table. Reset whenever
-- a fresh roguelite run begins (see resetProgress/resetRunStats).
local function freshRunStats()
    return {
        keystrokes = 0,
        mistakes = 0,
        correct = 0,
        score = 0,
        bestStreak = 0,
        moneyEarned = 0,
        roundsPlayed = 0,
    }
end

-- Collapse a possibly-sparse matchHistory table (holes from a corrupted or
-- legacy save) into a dense, order-preserving array. Non-table entries are
-- dropped rather than allowed to throw out of PlayerModel.load.
local function loadMatchHistory(raw)
    local result = {}
    if type(raw) ~= "table" then return result end

    local function appendIfTable(match)
        if type(match) == "table" then
            result[#result + 1] = {
                timestamp = match.timestamp or 0,
                wpm = match.wpm or 0,
                accuracy = match.accuracy or 0,
                keystrokes = match.keystrokes or 0,
                mistakes = match.mistakes or 0,
                apm = match.apm or 0,
                moneyEarned = match.moneyEarned or 0,
            }
        end
    end

    -- Fast path: our own save() always writes a dense array, so a single
    -- ipairs pass covers every history this module itself produces.
    local seen = 0
    for i, match in ipairs(raw) do
        appendIfTable(match)
        seen = i
    end

    -- ipairs stops at the first hole. A corrupted or pre-migration save can
    -- still be sparse, so sweep any remaining numeric keys in order.
    local maxIndex = seen
    for k in pairs(raw) do
        if type(k) == "number" and k > maxIndex then
            maxIndex = k
        end
    end

    for i = seen + 1, maxIndex do
        appendIfTable(raw[i])
    end

    return result
end

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
    self.matchHistory = {}
    self.dirty = false
    self.savePath = SAVE_PATH

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

    -- Player stats (lifetime totals)
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

    -- Per-run stats, reset at the start of each roguelite run
    self.runStats = freshRunStats()

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

-- End the current session and record stats. Does not save to disk itself --
-- callers finish a batch of mutations (endSession + addMoney is the common
-- pair) and then call save() once. Use saveIfDirty() as a safety net.
function PlayerModel:endSession(sessionStats)
    if not self.isInSession then
        print("PlayerModel: Warning - endSession called when not in session")
        return false
    end

    self.isInSession = false
    local sessionTime = love.timer.getTime() - self.sessionStartTime

    self.stats.totalPlayTime = (self.stats.totalPlayTime or 0) + sessionTime
    self.stats.totalSessions = (self.stats.totalSessions or 0) + 1
    if self.stats.totalSessions == 100 then
        Steam.unlockAchievement("HUNDRED_SESSIONS")
    end

    if sessionStats then
        local matchData = {}

        if type(sessionStats.keystrokes) == "number" then
            self.stats.totalKeystrokes = (self.stats.totalKeystrokes or 0) + sessionStats.keystrokes
            self.runStats.keystrokes = (self.runStats.keystrokes or 0) + sessionStats.keystrokes
            matchData.keystrokes = sessionStats.keystrokes
        end

        if type(sessionStats.mistakes) == "number" then
            self.stats.totalMistakes = (self.stats.totalMistakes or 0) + sessionStats.mistakes
            self.runStats.mistakes = (self.runStats.mistakes or 0) + sessionStats.mistakes
            matchData.mistakes = sessionStats.mistakes
        end

        if type(sessionStats.correct) == "number" then
            self.stats.totalCorrect = (self.stats.totalCorrect or 0) + sessionStats.correct
            self.runStats.correct = (self.runStats.correct or 0) + sessionStats.correct
        end

        if sessionStats.apm then matchData.apm = sessionStats.apm end
        bumpMax(self.stats, "bestAPM", sessionStats.apm)

        if sessionStats.wpm then matchData.wpm = sessionStats.wpm end
        local oldBestWPM = self.stats.bestWPM or 0
        bumpMax(self.stats, "bestWPM", sessionStats.wpm)
        local newBestWPM = self.stats.bestWPM or 0
        if oldBestWPM < 60 and newBestWPM >= 60 then
            Steam.unlockAchievement("WPM_60")
        end
        if oldBestWPM < 100 and newBestWPM >= 100 then
            Steam.unlockAchievement("WPM_100")
        end
        if oldBestWPM < 150 and newBestWPM >= 150 then
            Steam.unlockAchievement("WPM_150")
        end

        if sessionStats.accuracy then matchData.accuracy = sessionStats.accuracy end
        bumpMax(self.stats, "bestAccuracy", sessionStats.accuracy)

        bumpMax(self.stats, "bestStreak", sessionStats.longestStreak)
        bumpMax(self.runStats, "bestStreak", sessionStats.longestStreak)

        if sessionStats.score and type(sessionStats.score) == "number" then
            self.runStats.score = (self.runStats.score or 0) + sessionStats.score
        end

        -- Accuracy surgeon: 100% accuracy over 100+ keystrokes in one round.
        if sessionStats.accuracy == 100 and (sessionStats.keystrokes or 0) >= 100 then
            Steam.unlockAchievement("ACCURACY_SURGEON")
        end

        -- Perfect round: no mistakes across at least one keystroke.
        if sessionStats.mistakes == 0 and (sessionStats.keystrokes or 0) > 0 then
            self.stats.roundsWithoutError = (self.stats.roundsWithoutError or 0) + 1
            self.stats.perfectRounds = (self.stats.perfectRounds or 0) + 1
            Steam.unlockAchievement("PERFECT_ROUND")
            if self.stats.perfectRounds >= 5 then
                Steam.unlockAchievement("FIVE_PERFECT_ROUNDS")
            end
        end

        if type(sessionStats.moneyEarned) == "number" then
            matchData.moneyEarned = sessionStats.moneyEarned
            local oldMoneyEarned = self.stats.moneyEarned or 0
            self.stats.moneyEarned = (self.stats.moneyEarned or 0) + sessionStats.moneyEarned
            self.runStats.moneyEarned = (self.runStats.moneyEarned or 0) + sessionStats.moneyEarned
            if oldMoneyEarned < 1000 and self.stats.moneyEarned >= 1000 then
                Steam.unlockAchievement("MONEY_1000")
            end
        end

        self.runStats.roundsPlayed = (self.runStats.roundsPlayed or 0) + 1

        matchData.timestamp = os.time()
        self:addMatchToHistory(matchData)
    else
        print("PlayerModel: Warning - No session stats provided")
    end

    Steam.store()
    self:markDirty()
    return true
end

-- Insert newest-first and trim from the tail (oldest) once over the cap.
function PlayerModel:addMatchToHistory(matchData)
    table.insert(self.matchHistory, 1, matchData)

    while #self.matchHistory > PlayerModel.MAX_MATCH_HISTORY do
        table.remove(self.matchHistory)
    end
end

-- Mark the model as having unsaved changes. save() clears this; saveIfDirty()
-- checks it so a caller that forgets to save explicitly doesn't lose data.
function PlayerModel:markDirty()
    self.dirty = true
end

-- Add money to the player's total
function PlayerModel:addMoney(amount)
    if not amount or type(amount) ~= "number" or amount <= 0 then
        return self.totalMoney
    end

    self.totalMoney = self.totalMoney + amount
    self.stats.moneyEarned = (self.stats.moneyEarned or 0) + amount
    self:markDirty()

    return self.totalMoney
end

-- Spend money (returns true if successful)
function PlayerModel:spendMoney(amount)
    if not amount or type(amount) ~= "number" then
        return false
    end

    if self.totalMoney >= amount then
        self.totalMoney = self.totalMoney - amount
        self.stats.moneySpent = (self.stats.moneySpent or 0) + amount
        self:markDirty()

        return true
    end
    return false
end

-- Change the player's keyboard, carrying existing upgrades across the swap.
-- KeyboardModel.new() always starts with empty upgrades, so without this a
-- layout change silently destroyed every key upgrade the player owned.
function PlayerModel:changeKeyboard(keyboardLayout)
    if not keyboardLayout then return self.keyboard end

    local previousUpgrades = self.keyboard and self.keyboard.upgrades

    local success, keyboard = pcall(function()
        return KeyboardModel.new(keyboardLayout)
    end)

    if success and keyboard then
        if type(previousUpgrades) == "table" then
            for key, bonus in pairs(previousUpgrades) do
                keyboard.upgrades[key] = bonus
            end
        end

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

        -- Update max round reached
        if self.currentRound > self.maxRoundReached then
            self.maxRoundReached = self.currentRound
        end

        -- Save after advancing round
        self:save()
        return true
    end

    return false
end

-- Reset progress (e.g., after game over) and start a fresh run's stats.
function PlayerModel:resetProgress()
    self.currentRound = 1
    self:resetRunStats()
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

-- Get complete lifetime stats
function PlayerModel:getStats()
    return self.stats
end

function PlayerModel:getMatchHistory()
    return self.matchHistory
end

-- Per-run stats: reset at the start of a run, consumed by the run summary /
-- game-over screen and the run mutator system.
function PlayerModel:getRunStats()
    return self.runStats
end

function PlayerModel:resetRunStats()
    self.runStats = freshRunStats()
    return self.runStats
end

-- Save method. Callers invoke this explicitly after a batch of mutations;
-- addMoney/spendMoney only mark the model dirty so a completed round does not
-- trigger multiple full serializations + disk writes.
-- `path` is an optional one-off override; normally this writes to whatever
-- path the player was loaded from (self.savePath), so callers never need to
-- thread a path through every mutator that happens to save.
function PlayerModel:save(path)
    path = path or self.savePath or SAVE_PATH

    -- Prepare data structure for serialization
    local data = {
        totalMoney = self.totalMoney,
        level = self.level,
        currentRound = self.currentRound,
        maxRoundReached = self.maxRoundReached,
        selectedKeyboardLayout = self.selectedKeyboardLayout,
        matchHistory = self.matchHistory,
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

    -- Serialize to string. Unlike the old hand-rolled serializer, a failure
    -- here does NOT get papered over with a partial write -- it fails loudly
    -- and leaves the on-disk save untouched.
    local serialized, encodeErr = Serialize.encode(data)
    if not serialized then
        print("PlayerModel: ERROR - Failed to serialize player data: " .. tostring(encodeErr))
        return false
    end

    -- Ensure save directory exists
    FileManager.ensureDirectoryExists("save")

    -- Try to save using FileManager
    local success = FileManager.saveToFile(path, serialized)

    if not success then
        print("PlayerModel: ERROR - Failed to save player data")

        -- Try a last resort direct save
        local directSuccess = love.filesystem.write(PlayerModel.backupPathFor(path), serialized)
        if directSuccess then
            print("PlayerModel: Created backup save file instead")
            self.dirty = false
            return true
        end

        return false
    end

    self.dirty = false
    return true
end

-- Safety net for callers that mutate the model (addMoney/spendMoney) without
-- following up with an explicit save() -- no data is lost, but a run of
-- mutations still only costs one disk write.
function PlayerModel:saveIfDirty(path)
    if not self.dirty then return true end
    return self:save(path)
end

-- Enhanced load method with improved error handling
function PlayerModel.load(path)
    path = path or SAVE_PATH

    -- First try to load the primary save file
    local content = FileManager.loadFromFile(path)

    -- If primary save failed, try the backup
    if not content then
        content = FileManager.loadFromFile(PlayerModel.backupPathFor(path))
    end

    -- If no save data found, create a new player. Still bind savePath so any
    -- future save() from this instance lands at the path it was asked for.
    if not content then
        local player = PlayerModel.new()
        player.savePath = path
        return player
    end

    -- Current format: a sandboxed, serpent-produced chunk.
    local data = Serialize.decode(content)
    local migrated = false

    if not data then
        -- Fall back to the legacy hand-rolled format (a plain, unsandboxed
        -- Lua chunk) so an old save is never lost. Re-saved below so this
        -- only ever has to happen once per file.
        local func, loadErr = load(content)
        if func then
            local ok, legacyData = pcall(func)
            if ok and type(legacyData) == "table" then
                data = legacyData
                migrated = true
            else
                print("PlayerModel: Error executing legacy save file: " .. tostring(legacyData))
            end
        else
            print("PlayerModel: Error parsing save file: " .. tostring(loadErr))
        end
    end

    -- Corrupt or truncated save: fall back to a fresh player rather than
    -- throwing out of PlayerModel.load.
    if type(data) ~= "table" then
        print("PlayerModel: Save file is unreadable, starting a fresh player")
        local player = PlayerModel.new()
        player.savePath = path
        return player
    end

    -- Create a new player model
    local player = PlayerModel.new()
    player.savePath = path

    -- Apply saved data with safety checks
    if type(data.totalMoney) == "number" then
        player.totalMoney = data.totalMoney
    end

    if type(data.level) == "number" then
        player.level = data.level
    end

    if type(data.currentRound) == "number" then
        player.currentRound = data.currentRound
    end

    if type(data.maxRoundReached) == "number" then
        player.maxRoundReached = data.maxRoundReached
    end

    if type(data.selectedKeyboardLayout) == "string" then
        player.selectedKeyboardLayout = data.selectedKeyboardLayout
    end

    -- Load keyboard data with error handling
    if type(data.keyboard) == "table" then
        local keyboardSuccess, keyboard = pcall(function()
            return KeyboardModel.deserialize(data.keyboard)
        end)

        if keyboardSuccess and keyboard then
            player.keyboard = keyboard
        else
            print("PlayerModel: Failed to deserialize keyboard, using default")
            player.keyboard = KeyboardModel.new(player.selectedKeyboardLayout)
        end
    elseif player.selectedKeyboardLayout ~= "qwerty" then
        -- No keyboard block saved, but a non-default layout was selected --
        -- rebuild it rather than silently keep the qwerty default.
        local success, keyboard = pcall(KeyboardModel.new, player.selectedKeyboardLayout)
        if success and keyboard then
            player.keyboard = keyboard
        end
    end

    -- Load stats with safety checks -- fields missing from an older save
    -- keep whatever PlayerModel.new() already initialized them to.
    if type(data.stats) == "table" then
        for _, statName in ipairs(PlayerModel.STAT_FIELDS) do
            if type(data.stats[statName]) == "number" then
                player.stats[statName] = data.stats[statName]
            end
        end
    end

    player.matchHistory = loadMatchHistory(data.matchHistory)

    if migrated then
        print("PlayerModel: Migrated legacy save format")
        player.dirty = true
        player:save()
    end

    return player
end

return PlayerModel
