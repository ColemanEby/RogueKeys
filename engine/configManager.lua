-- engine/configManager.lua
-- Centralized configuration management with file-based persistence

-- Add this at the top of the file
local FileManager = require("modules/util/fileManager")


local ConfigManager = {
    configs = {},
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

        -- Typing challenge difficulties
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
            upgradeMaxBonus = 0.3
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

-- Add this to the init function at the end
function ConfigManager:init()
    self.configs = deepCopy(self.defaultConfigs)
    
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

-- Replace the saveConfig function with this version
function ConfigManager:saveConfig(configName)
    if not self.configs[configName] then
        print("ConfigManager: No config named '" .. configName .. "' to save")
        return false
    end

    local configPath = "config/" .. configName .. ".lua"

    -- Convert config to serialized Lua
    local serialized = "return " .. self:serializeTable(self.configs[configName])

    -- Ensure directory exists before trying to save
    if not love.filesystem.getInfo("config") then
        local success = love.filesystem.createDirectory("config")
        print("ConfigManager: Creating config directory: " .. (success and "Success" or "Failed"))
    end

    -- Try to save directly
    local success, err = love.filesystem.write(configPath, serialized)
    
    if not success then
        print("ConfigManager: Direct save failed for '" .. configName .. "': " .. tostring(err))
        
        -- Fall back to using the FileManager
        success = FileManager.saveToFile(configPath, serialized)
    end
    
    if success then
        print("ConfigManager: Saved config '" .. configName .. "'")
        return true
    else
        -- If config saving fails, don't break the game, just log the error
        print("ConfigManager: Failed to save config '" .. configName .. "', proceeding with in-memory defaults")
        return false
    end
end

-- Replace the loadConfig function with this version
function ConfigManager:loadConfig(configName)
    local configPath = "config/" .. configName .. ".lua"

    -- Load using FileManager
    local content, error = FileManager.loadFromFile(configPath)
    
    if not content then
        print("ConfigManager: Config file '" .. configPath .. "' not found or couldn't be loaded, using defaults")
        return false
    end

    -- Try to load the file as Lua code
    local func, err = load(content)
    if not func then
        print("ConfigManager: Error parsing config file '" .. configPath .. "': " .. tostring(err))
        return false
    end

    -- Try to execute the chunk to get the config table
    local success, config = pcall(func)
    if not success then
        print("ConfigManager: Error executing config file '" .. configPath .. "': " .. tostring(config))
        return false
    end

    -- Merge with defaults to ensure all keys exist
    if self.configs[configName] == nil then
        self.configs[configName] = {}
    end

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

-- Replace the loadAllConfigs function with this version
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


-- Save all configs to files
function ConfigManager:saveAllConfigs()
    for configName, _ in pairs(self.configs) do
        self:saveConfig(configName)
    end
end

-- Get a config value with dot notation path
function ConfigManager:get(path, default)
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end

    local current = self.configs
    for i = 1, #parts - 1 do
        if type(current[parts[i]]) ~= "table" then
            return default
        end
        current = current[parts[i]]
    end

    local value = current[parts[#parts]]
    if value == nil then
        return default
    end
    return value
end

-- Set a config value with dot notation path
function ConfigManager:set(path, value)
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end

    local current = self.configs
    for i = 1, #parts - 1 do
        if type(current[parts[i]]) ~= "table" then
            current[parts[i]] = {}
        end
        current = current[parts[i]]
    end

    current[parts[#parts]] = value

    -- Save the affected config
    self:saveConfig(parts[1])
end

-- Get all available keyboard layouts
function ConfigManager:getKeyboardLayouts()
    return self.configs.keyboards
end

-- Get difficulty settings
function ConfigManager:getDifficulty(level)
    return self.configs.difficulties[level] or self.configs.difficulties.medium
end

-- Serialize a table to a string (with some formatting for readability)
function ConfigManager:serializeTable(tbl, indent)
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



return ConfigManager