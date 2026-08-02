-- engine/configManager.lua
-- Centralized configuration management with file-based persistence

local FileManager = require("modules/util/fileManager")
local Serialize = require("modules/util/serialize")


local ConfigManager = {
    configs = {},
    -- Configs with pending writes since the last save. set() only marks a
    -- config dirty instead of saving immediately -- see flush()/saveAllConfigs().
    dirty = {},
    defaultConfigs = {
        -- Game settings
        game = {
            windowWidth = 800,
            windowHeight = 600,
            fullscreen = false,
            vsync = true,
            showFPS = false,
            volume = 0.7,
            musicVolume = 0.5,
            sfxVolume = 0.8,
            transitionDuration = 0.3
        },

        -- Audio settings. This is the config Audio (modules/audio/audio.lua)
        -- actually reads; `game.volume`/`musicVolume`/`sfxVolume` above are
        -- kept for backwards compatibility but are no longer authoritative.
        audio = {
            masterVolume = 1.0,
            sfxVolume = 0.8,
            musicVolume = 0.5
        },

        -- Video / display settings
        video = {
            fullscreen = false,
            scaleMode = "integer",
            crt = false,
            vsync = true
        },

        -- Gameplay settings
        gameplay = {
            layout = "qwerty",
            showKeyboard = true
        },

        -- Keyboard layouts
        keyboards = {
            qwerty = {
                name = "QWERTY",
                description = "Standard QWERTY keyboard layout",
                layout = {
                    { { key = "Q", w = 1 }, { key = "W", w = 1 }, { key = "E", w = 1 }, { key = "R", w = 1 },
                      { key = "T", w = 1 }, { key = "Y", w = 1 }, { key = "U", w = 1 }, { key = "I", w = 1 },
                      { key = "O", w = 1 }, { key = "P", w = 1 } },
                    { { key = "A", w = 1 }, { key = "S", w = 1 }, { key = "D", w = 1 }, { key = "F", w = 1 },
                      { key = "G", w = 1 }, { key = "H", w = 1 }, { key = "J", w = 1 }, { key = "K", w = 1 },
                      { key = "L", w = 1 } },
                    { { key = "Z", w = 1 }, { key = "X", w = 1 }, { key = "C", w = 1 }, { key = "V", w = 1 },
                      { key = "B", w = 1 }, { key = "N", w = 1 }, { key = "M", w = 1 } },
                    { { key = ",", w = 1 }, { key = ".", w = 1 }, { key = "?", w = 1 }, { key = "!", w = 1 } },
                    { { key = "Space", w = 5 } }
                }
            },
            dvorak = {
                name = "Dvorak",
                description = "Dvorak simplified keyboard layout",
                layout = {
                    { { key = "'", w = 1 }, { key = ",", w = 1 }, { key = ".", w = 1 }, { key = "P", w = 1 },
                      { key = "Y", w = 1 }, { key = "F", w = 1 }, { key = "G", w = 1 }, { key = "C", w = 1 },
                      { key = "R", w = 1 }, { key = "L", w = 1 } },
                    { { key = "A", w = 1 }, { key = "O", w = 1 }, { key = "E", w = 1 }, { key = "U", w = 1 },
                      { key = "I", w = 1 }, { key = "D", w = 1 }, { key = "H", w = 1 }, { key = "T", w = 1 },
                      { key = "N", w = 1 }, { key = "S", w = 1 } },
                    { { key = ";", w = 1 }, { key = "Q", w = 1 }, { key = "J", w = 1 }, { key = "K", w = 1 },
                      { key = "X", w = 1 }, { key = "B", w = 1 }, { key = "M", w = 1 }, { key = "W", w = 1 },
                      { key = "V", w = 1 }, { key = "Z", w = 1 } },
                    { { key = "?", w = 1 }, { key = "!", w = 1 } },
                    { { key = "Space", w = 5 } }
                }
            }
        },

        -- Typing challenge difficulties. maxWordSize/timeLimit/baseScorePerChar
        -- are not read anywhere yet; other units are wiring them up.
        difficulties = {
            easy = {
                name = "Easy",
                sentenceLength = 8,
                maxWordSize = 6,
                timeLimit = 60,
                baseScorePerChar = 1
            },
            medium = {
                name = "Medium",
                sentenceLength = 12,
                maxWordSize = 8,
                timeLimit = 45,
                baseScorePerChar = 1.5
            },
            hard = {
                name = "Hard",
                sentenceLength = 16,
                maxWordSize = 12,
                timeLimit = 30,
                baseScorePerChar = 2
            }
        },

        -- Game progression settings
        progression = {
            startingMoney = 50,
            moneyMultiplier = 1.0,
            roundDifficultyScale = 1.2,
            upgradeBaseCost = 20,
            upgradeMinBonus = 0.05,
            upgradeMaxBonus = 0.3,
            baseRequiredScore = 20
        }
    }
}

-- Helper function: deep copy a table
local function deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for origKey, origValue in next, orig, nil do
            copy[deepCopy(origKey)] = deepCopy(origValue)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Helper function: merge tables
local function mergeTable(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            mergeTable(target[k], v)
        else
            target[k] = v
        end
    end
    return target
end

function ConfigManager:init()
    self.configs = deepCopy(self.defaultConfigs)
    self.dirty = {}

    -- Initialize the FileManager
    FileManager.init()

    -- Now load configs
    self:loadAllConfigs()

    -- If this is the first run, save the default configs
    for configName, _ in pairs(self.defaultConfigs) do
        if not love.filesystem.getInfo("config/" .. configName .. ".lua") then
            self:saveConfig(configName)
        end
    end

    print("ConfigManager: Initialization complete")
end

-- Save a single config to disk immediately.
function ConfigManager:saveConfig(configName)
    if not self.configs[configName] then
        print("ConfigManager: No config named '" .. configName .. "' to save")
        return false
    end

    local configPath = "config/" .. configName .. ".lua"

    local serialized, err = Serialize.encode(self.configs[configName])
    if not serialized then
        print("ConfigManager: Failed to serialize config '" .. configName .. "': " .. tostring(err))
        return false
    end

    -- Ensure directory exists before trying to save
    if not love.filesystem.getInfo("config") then
        local success = love.filesystem.createDirectory("config")
        print("ConfigManager: Creating config directory: " .. (success and "Success" or "Failed"))
    end

    -- Try to save directly
    local success = love.filesystem.write(configPath, serialized)

    if not success then
        print("ConfigManager: Direct save failed for '" .. configName .. "'")

        -- Fall back to using the FileManager
        success = FileManager.saveToFile(configPath, serialized)
    end

    if success then
        print("ConfigManager: Saved config '" .. configName .. "'")
        self.dirty[configName] = nil
        return true
    else
        -- If config saving fails, don't break the game, just log the error
        print("ConfigManager: Failed to save config '" .. configName .. "', proceeding with in-memory defaults")
        return false
    end
end

-- Load a single config from disk, merging it over the defaults. If the file
-- is present but fails to parse, this logs the failure, resets that config to
-- its defaults, and rewrites the file immediately -- a corrupt config used to
-- stay corrupt forever, since it is only ever (re)written when absent.
function ConfigManager:loadConfig(configName)
    local configPath = "config/" .. configName .. ".lua"

    local content = FileManager.loadFromFile(configPath)
    if not content then
        print("ConfigManager: Config file '" .. configPath .. "' not found or couldn't be loaded, using defaults")
        return false
    end

    local config, err = Serialize.decode(content)
    if not config then
        print("ConfigManager: Corrupt config file '" .. configPath .. "' (" .. tostring(err) ..
            "), resetting to defaults and rewriting")
        self.configs[configName] = deepCopy(self.defaultConfigs[configName] or {})
        self:saveConfig(configName)
        return false
    end

    -- Merge with defaults to ensure all keys exist (e.g. newly-added settings).
    if self.defaultConfigs[configName] then
        local merged = deepCopy(self.defaultConfigs[configName])
        mergeTable(merged, config)
        self.configs[configName] = merged
    else
        self.configs[configName] = config
    end

    print("ConfigManager: Loaded config '" .. configName .. "'")
    return true
end

function ConfigManager:loadAllConfigs()
    -- Ensure config directory exists
    FileManager.ensureDirectoryExists("config")

    -- Load all default configs first
    for configName, _ in pairs(self.defaultConfigs) do
        self:loadConfig(configName)
    end

    -- Try to load any additional config files that might exist
    if love.filesystem.getInfo("config") then
        local files = love.filesystem.getDirectoryItems("config")
        for _, file in ipairs(files) do
            local configName = file:match("^(.+)%.lua$")
            if configName and not self.configs[configName] then
                self:loadConfig(configName)
            end
        end
    end
end

-- Save every loaded config to disk, regardless of dirty state. Called from
-- love.quit so nothing pending is lost even if flush() was never called.
function ConfigManager:saveAllConfigs()
    for configName, _ in pairs(self.configs) do
        self:saveConfig(configName)
    end
end

-- Save only the configs touched by set() since the last save. Prefer this
-- over saveAllConfigs() for frequent callers (e.g. a settings screen slider)
-- so every tweak doesn't force a full disk write.
function ConfigManager:flush()
    for configName in pairs(self.dirty) do
        self:saveConfig(configName)
    end
end

-- Get a config value with dot notation path
function ConfigManager:get(path, default)
    if type(path) ~= "string" then return default end

    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    if #parts == 0 then return default end

    local current = self.configs
    for i = 1, #parts - 1 do
        if type(current) ~= "table" or type(current[parts[i]]) ~= "table" then
            return default
        end
        current = current[parts[i]]
    end

    if type(current) ~= "table" then return default end

    local value = current[parts[#parts]]
    if value == nil then
        return default
    end
    return value
end

-- Set a config value with dot notation path. Marks the top-level config dirty
-- rather than saving immediately -- call flush() or saveAllConfigs() to persist.
function ConfigManager:set(path, value)
    if type(path) ~= "string" then return end

    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    if #parts == 0 then return end

    local current = self.configs
    for i = 1, #parts - 1 do
        if type(current[parts[i]]) ~= "table" then
            current[parts[i]] = {}
        end
        current = current[parts[i]]
    end

    current[parts[#parts]] = value
    self.dirty[parts[1]] = true
end

-- Get all available keyboard layouts (unordered map of id -> layout data).
function ConfigManager:getKeyboardLayouts()
    return self.configs.keyboards
end

-- Get keyboard layout ids in a stable, sorted order. Iterating
-- getKeyboardLayouts() with pairs() is non-deterministic across runs; callers
-- that render layout tabs/lists should use this instead.
function ConfigManager:getKeyboardLayoutIds()
    local ids = {}
    for id in pairs(self.configs.keyboards or {}) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end

-- Get difficulty settings
function ConfigManager:getDifficulty(level)
    return self.configs.difficulties[level] or self.configs.difficulties.medium
end

return ConfigManager
