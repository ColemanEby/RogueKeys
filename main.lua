-- main.lua
-- Refactored entry point for the typing trainer roguelike

-- Import engine modules
local StateManager = require("engine/stateManager")
local ResourceManager = require("engine/resourceManager")
local ConfigManager = require("engine/configManager")

-- Import startup utilities
local TextGenerator = require("modules/typing/textGenerator")

-- Global settings
local GAME_TITLE = "Typing Trainer Roguelike"
local DEFAULT_WIDTH = 800
local DEFAULT_HEIGHT = 600

-- Debugging flag
local DEBUG_MODE = true

-- Error handler for better debugging
function love.errorhandler(msg)
    print("ERROR: " .. tostring(msg))
    print(debug.traceback())

    -- Display error on screen
    if love.graphics and love.graphics.isActive() then
        love.graphics.reset()
        love.graphics.setColor(0.3, 0.1, 0.1, 1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ERROR: " .. tostring(msg), 50, 50, love.graphics.getWidth() - 100)
        love.graphics.printf(debug.traceback(), 50, 120, love.graphics.getWidth() - 100)
        love.graphics.present()
    end

    return msg
end

function love.load()
    -- Initialize basic rendering
    love.graphics.setBackgroundColor(0.1, 0.1, 0.2)
    love.graphics.setFont(love.graphics.newFont(14))

    -- Apply window configuration
    love.window.setMode(DEFAULT_WIDTH, DEFAULT_HEIGHT, {
        fullscreen = false,
        vsync = true,
        minwidth = 800,
        minheight = 600,
        resizable = true
    })
    love.window.setTitle(GAME_TITLE)

    -- Disable key repeat to prevent multiple keypresses
    love.keyboard.setKeyRepeat(false)

    -- Initialize file management system
    print("Setting up file management system...")
    local FileManager
    local success, err = pcall(function()
        FileManager = require("modules/util/fileManager")
        FileManager.init()
        
        -- Print debug info about file system
        FileManager.printFileSystemInfo()
    end)

    if not success then
        print("ERROR initializing file management: " .. tostring(err))
        -- Create a fallback implementation to prevent further errors
        FileManager = {
            init = function() return false end,
            ensureDirectoryExists = function(dir) 
                return love.filesystem.createDirectory(dir) 
            end,
            saveToFile = function(path, data) 
                return love.filesystem.write(path, data) 
            end,
            loadFromFile = function(path) 
                return love.filesystem.read(path) 
            end,
            printFileSystemInfo = function() 
                print("File system info not available") 
            end
        }
    end

    -- Start with a loading message
    print("=== Starting Typing Trainer Roguelike ===")

    -- Try loading modules in a safe way
    print("Loading engine modules...")

    -- Initialize ConfigManager
    print("Initializing ConfigManager...")
    local success, err = pcall(function() ConfigManager:init() end)
    if not success then
        print("ERROR initializing ConfigManager: " .. tostring(err))
    end

    -- Initialize ResourceManager
    print("Initializing ResourceManager...")
    success, err = pcall(function() ResourceManager:init() end)
    if not success then
        print("ERROR initializing ResourceManager: " .. tostring(err))
    end

    -- Check if the keyboard sprite sheet was loaded
    local keyboardSprite = ResourceManager:getSprite("keyboard_sprites")
    if keyboardSprite then
        print("Keyboard sprite sheet loaded successfully")
    else
        print("Warning - Keyboard sprite sheet not found, will use fallback rendering")
    end

    -- Preload text data
    print("Preloading text data...")
    success, err = pcall(function() TextGenerator:preload() end)
    if not success then
        print("ERROR preloading text: " .. tostring(err))
    end

    -- Ensure the StateManager has the fallback state
    print("Initializing States...")
    StateManager.stateCache = StateManager.stateCache or {}

    -- Load the fallback menu state directly
    local fallbackMenu = require("states/fallbackMenuState")
    StateManager.stateCache["fallbackMenuState"] = fallbackMenu

    -- Try loading the regular menu state
    local menuState = nil
    success, menuState = pcall(require, "states/menuState")
    if success and menuState then
        print("Successfully loaded menuState")
        StateManager.stateCache["menuState"] = menuState
    else
        print("Failed to load menuState, will use fallback")
    end

    -- Switch to fallback menu initially to ensure something displays
    print("Switching to initial state...")
    if StateManager.stateCache["menuState"] then
        StateManager.switch(StateManager.stateCache["menuState"])
    else
        StateManager.switch(fallbackMenu)
    end

    print("Initialization complete")
end

function love.update(dt)
    -- Check if StateManager has a current state
    if not StateManager.current then
        print("WARNING: No current state in StateManager")
        return
    end

    -- Update the current state
    local success, err = pcall(function() StateManager.update(dt) end)
    if not success then
        print("ERROR in update: " .. tostring(err))
    end

    -- Debug info
    if DEBUG_MODE then
        if not debugTimer then debugTimer = 0 end
        debugTimer = debugTimer + dt
        if debugTimer > 5 then
            debugTimer = 0
            print("Current state: " .. (StateManager.current and StateManager.current.name or "nil"))
            print("FPS: " .. love.timer.getFPS())
        end
    end
end

function love.draw()
    -- Clear the screen
    love.graphics.clear(0.1, 0.1, 0.2)

    -- Check if StateManager has a current state
    if not StateManager.current then
        -- Draw a loading message if no state is active
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Loading...", 0, 300, love.graphics.getWidth(), "center")
        return
    end

    -- Draw the current state
    local success, err = pcall(function() StateManager.draw() end)
    if not success then
        -- Draw error message
        love.graphics.clear(0.3, 0.1, 0.1)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("ERROR: " .. tostring(err), 50, 50, love.graphics.getWidth() - 100)
    end

    -- Draw debug info if in debug mode
    if DEBUG_MODE then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
        love.graphics.print("State: " .. (StateManager.current and StateManager.current.name or "nil"), 10, 30)
        love.graphics.print("Memory: " .. string.format("%.2f MB", collectgarbage("count") / 1024), 10, 50)
    end
end

function love.keypressed(key, scancode, isrepeat)
    -- Debug key combos
    if DEBUG_MODE and key == "f1" then
        print("--- DEBUG INFO ---")
        print("FPS: " .. love.timer.getFPS())
        print("Current state: " .. (StateManager.current and StateManager.current.name or "nil"))
        print("Memory usage: " .. collectgarbage("count") .. " KB")
        return
    end

    -- Force quit (for development)
    if key == "escape" and love.keyboard.isDown("lctrl") then
        love.event.quit()
        return
    end

    -- Forward to state manager
    if StateManager.current then
        local success, err = pcall(function() StateManager.keypressed(key) end)
        if not success then
            print("ERROR in keypressed: " .. tostring(err))
        end
    end
end

function love.textinput(text)
    if StateManager.current then
        local success, err = pcall(function() StateManager.textinput(text) end)
        if not success then
            print("ERROR in textinput: " .. tostring(err))
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if StateManager.current and StateManager.current.mousepressed then
        local success, err = pcall(function()
            StateManager.current.mousepressed(x, y, button, istouch, presses)
        end)
        if not success then
            print("ERROR in mousepressed: " .. tostring(err))
        end
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if StateManager.current and StateManager.current.mousereleased then
        local success, err = pcall(function()
            StateManager.current.mousereleased(x, y, button, istouch, presses)
        end)
        if not success then
            print("ERROR in mousereleased: " .. tostring(err))
        end
    end
end

function love.resize(w, h)
    if StateManager.current and StateManager.current.resize then
        local success, err = pcall(function() StateManager.current.resize(w, h) end)
        if not success then
            print("ERROR in resize: " .. tostring(err))
        end
    end
end

function love.quit()
    -- Final file system diagnostic check before quitting
    if FileManager then
        print("Performing final file system check...")
        FileManager.printFileSystemInfo()
    end
    -- Save configuration before quitting
    local success, err = pcall(function() ConfigManager:saveAllConfigs() end)
    if not success then
        print("ERROR saving configs: " .. tostring(err))
    end
    return false
end

-- Snippet to add to main.lua to integrate the stat tracking debugging system

-- Add the DEBUG_MODE as a global variable so it can be accessed everywhere
_G.DEBUG_MODE = true

-- Add this right after the "Loading engine modules..." message in love.load()
-- to initialize our stat tracking integration

-- Initialize stat tracking integration
print("Initializing stat tracking system...")
local success, err = pcall(function()
    local StatTrackingIntegration = require("modules/util/statTrackingIntegration")
    StatTrackingIntegration.init()
    
    -- Verify system integrity if in debug mode
    if _G.DEBUG_MODE then
        print("Running stat tracking verification...")
        StatTrackingIntegration.verifySystem()
    end
end)

if not success then
    print("ERROR initializing stat tracking: " .. tostring(err))
end

-- Add a debug key handler to the love.keypressed function
-- Add this inside the existing keypressed function:

-- Debug commands for stats testing/verification
if _G.DEBUG_MODE then
    if key == "f2" then
        print("--- STATS DEBUG INFO ---")
        local StatTrackingIntegration = require("modules/util/statTrackingIntegration")
        local debugInfo = StatTrackingIntegration.getDebugInfo()
        
        for k, v in pairs(debugInfo) do
            print(k .. ": " .. tostring(v))
        end
        
        -- Verify saved stats
        local StatVerifier = require("modules/util/statVerifier")
        StatVerifier.verifySavedStats()
        
        return
    elseif key == "f3" then
        -- Reset stats (for testing)
        print("--- RESETTING STATS ---")
        local StatTrackingIntegration = require("modules/util/statTrackingIntegration")
        local success = StatTrackingIntegration.resetStats()
        print("Stats reset: " .. (success and "Success" or "Failed"))
        return
    end
end