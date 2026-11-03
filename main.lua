-- main.lua
-- Entry point. Window and save identity are configured in conf.lua; this file
-- boots subsystems, owns the LOVE callbacks, and delegates everything else to
-- the StateManager.

local StateManager = require("engine/stateManager")
local ResourceManager = require("engine/resourceManager")
local ConfigManager = require("engine/configManager")

local Screen = require("modules/ui/screen")
local Theme = require("modules/ui/theme")
local Audio = require("modules/audio/audio")

local TextGenerator = require("modules/typing/textGenerator")
local FileManager = require("modules/util/fileManager")

-- Single source of truth for debug mode. Toggle in-game with F5.
_G.DEBUG_MODE = false

local debugTimer = 0

-- Screenshot mode: `love . --shot <stateName> [outputName]` boots normally,
-- switches to the named state, captures one frame to
-- <saveDir>/screenshots/<name>.png and quits. This is how a change to a state
-- is verified visually without a human at the keyboard.
local shotState, shotName = nil, nil
local shotFrame = 0

local function parseShotArgs()
    if type(arg) ~= "table" then return end
    for i, a in ipairs(arg) do
        if a == "--shot" then
            shotState = arg[i + 1]
            shotName = arg[i + 2]
            if shotName and shotName:sub(1, 2) == "--" then shotName = nil end
        end
    end
    if shotState then
        shotName = shotName or shotState
    end
end

-- A state opts into the 640x360 logical canvas by setting `logical = true` on
-- its module table. Un-migrated states keep drawing at window resolution.
local function usesLogicalCanvas()
    return Screen.isReady()
        and StateManager.current ~= nil
        and StateManager.current.logical == true
end

function love.errorhandler(msg)
    msg = tostring(msg)
    local trace = debug.traceback()

    print("ERROR: " .. msg)
    print(trace)

    if not love.window or not love.graphics or not love.graphics.isActive() then
        return
    end

    love.graphics.reset()
    love.graphics.setCanvas()

    return function()
        love.event.pump()
        for e, a in love.event.poll() do
            if e == "quit" then return 1 end
            if e == "keypressed" and a == "escape" then return 1 end
        end

        love.graphics.clear(0.3, 0.1, 0.1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ERROR: " .. msg, 50, 50, love.graphics.getWidth() - 100)
        love.graphics.printf(trace, 50, 120, love.graphics.getWidth() - 100)
        love.graphics.printf("Press Escape to quit.", 50, love.graphics.getHeight() - 60,
            love.graphics.getWidth() - 100)
        love.graphics.present()

        if love.timer then love.timer.sleep(0.05) end
    end
end

-- Headless test run: boot only what pure-logic tests need, then quit with the
-- failure count as the exit code.
local function runTests()
    print("[Headless test run]")

    local ok, err = pcall(function()
        FileManager.init()
        ConfigManager:init()
    end)
    if not ok then
        print("ERROR: test bootstrap failed: " .. tostring(err))
        love.event.quit(1)
        return
    end

    local Runner = require("tests/run")
    local failed = Runner.run()

    love.event.quit(failed > 0 and 1 or 0)
end

function love.load()
    if _G.HEADLESS then
        runTests()
        return
    end

    -- Save directories. conf.lua has already set the identity, so these land in
    -- the right place.
    for _, dir in ipairs({ "config", "save", "screenshots" }) do
        love.filesystem.createDirectory(dir)
    end

    Screen.init()

    local ok, err = pcall(function()
        FileManager.init()
        if _G.DEBUG_MODE then FileManager.printFileSystemInfo() end
    end)
    if not ok then
        print("ERROR initializing file management: " .. tostring(err))
        _G.FileSystemDisabled = true
    end

    ok, err = pcall(function() ConfigManager:init() end)
    if not ok then print("ERROR initializing ConfigManager: " .. tostring(err)) end

    ok, err = pcall(function() ResourceManager:init() end)
    if not ok then print("ERROR initializing ResourceManager: " .. tostring(err)) end

    ok, err = pcall(function() Audio.init() end)
    if not ok then print("ERROR initializing Audio: " .. tostring(err)) end

    ok, err = pcall(function() TextGenerator:preload() end)
    if not ok then print("ERROR preloading text: " .. tostring(err)) end

    love.graphics.setFont(Theme.font("body"))
    love.keyboard.setKeyRepeat(false)

    -- Shop offers were identical on every launch without this.
    math.randomseed(os.time())
    if love.math then love.math.setRandomSeed(os.time()) end

    StateManager.stateCache = StateManager.stateCache or {}
    StateManager.stateCache["fallbackMenuState"] =
        StateManager.createState(require("states/fallbackMenuState"))

    local loaded, menuState = pcall(require, "states/menuState")
    if loaded and menuState then
        StateManager.stateCache["menuState"] = StateManager.createState(menuState)
        StateManager.switchImmediate("menuState")
    else
        print("Failed to load menuState, using fallback: " .. tostring(menuState))
        StateManager.switchImmediate("fallbackMenuState")
    end

    parseShotArgs()
    if shotState then
        print("[Screenshot mode] target state: " .. shotState)
        local ok, err = pcall(StateManager.switchImmediate, shotState)
        if not ok then
            print("SHOT ERROR: could not switch to '" .. shotState .. "': " .. tostring(err))
            love.event.quit(1)
        end
    end
end

-- Drive the screenshot capture. Called at the end of love.draw so the frame is
-- fully composited (including Screen.pop) before it is captured.
local function updateShotMode()
    if not shotState then return end

    shotFrame = shotFrame + 1

    -- Capture around the 1s mark so entry animations (fades, counters) have
    -- settled; several states ramp alpha from 0 over the first ~0.7s.
    if shotFrame == 60 then
        love.graphics.captureScreenshot(function(imageData)
            local path = "screenshots/" .. shotName .. ".png"
            local ok, err = pcall(function()
                love.filesystem.write(path, imageData:encode("png"))
            end)
            if ok then
                print("SHOT OK: " .. love.filesystem.getSaveDirectory() .. "/" .. path)
            else
                print("SHOT ERROR: failed to write " .. path .. ": " .. tostring(err))
            end
        end)
    elseif shotFrame >= 75 then
        love.event.quit(0)
    end
end

function love.update(dt)
    if _G.HEADLESS then return end

    local ok, err = pcall(StateManager.update, dt)
    if not ok then print("ERROR in update: " .. tostring(err)) end

    Audio.update(dt)

    if _G.DEBUG_MODE then
        debugTimer = debugTimer + dt
        if debugTimer > 5 then
            debugTimer = 0
            print(string.format("state=%s fps=%d mem=%.2fMB",
                StateManager.current and StateManager.current.name or "nil",
                love.timer.getFPS(),
                collectgarbage("count") / 1024))
        end
    end
end

function love.draw()
    if _G.HEADLESS then return end

    local logical = usesLogicalCanvas()

    if logical then
        Screen.push(Theme.color("base"))
    else
        love.graphics.clear(Theme.color("base"))
    end

    if StateManager.current then
        local ok, err = pcall(StateManager.draw)
        if not ok then
            love.graphics.clear(0.3, 0.1, 0.1)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("ERROR: " .. tostring(err), 50, 50,
                (logical and Screen.getWidth() or love.graphics.getWidth()) - 100)
        end
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Loading...", 0, 160,
            logical and Screen.getWidth() or love.graphics.getWidth(), "center")
    end

    if logical then
        Screen.pop()
    end

    if _G.DEBUG_MODE then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.setFont(Theme.font("small"))
        love.graphics.print("FPS: " .. love.timer.getFPS(), 4, 4)
        love.graphics.print("State: " ..
            (StateManager.current and StateManager.current.name or "nil"), 4, 16)
        love.graphics.print(string.format("Mem: %.2f MB", collectgarbage("count") / 1024), 4, 28)
        if _G.FileSystemDisabled then
            love.graphics.setColor(1, 0.5, 0.5, 0.7)
            love.graphics.print("FILE SYSTEM: DISABLED", 4, 40)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    updateShotMode()
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f5" then
        _G.DEBUG_MODE = not _G.DEBUG_MODE
        print("DEBUG_MODE = " .. tostring(_G.DEBUG_MODE))
        return
    end

    if key == "f11" then
        local full = love.window.getFullscreen()
        love.window.setFullscreen(not full, "desktop")
        Screen.resize(love.graphics.getDimensions())
        return
    end

    if key == "escape" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        love.event.quit()
        return
    end

    local ok, err = pcall(StateManager.keypressed, key, scancode, isrepeat)
    if not ok then print("ERROR in keypressed: " .. tostring(err)) end
end

function love.keyreleased(key, scancode)
    local ok, err = pcall(StateManager.keyreleased, key, scancode)
    if not ok then print("ERROR in keyreleased: " .. tostring(err)) end
end

function love.textinput(text)
    local ok, err = pcall(StateManager.textinput, text)
    if not ok then print("ERROR in textinput: " .. tostring(err)) end
end

-- Mouse coordinates are translated into logical space for migrated states.
local function mouseCoords(x, y)
    if usesLogicalCanvas() then
        return Screen.toGame(x, y)
    end
    return x, y
end

function love.mousepressed(x, y, button, istouch, presses)
    local gx, gy = mouseCoords(x, y)
    StateManager.mousepressed(gx, gy, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    local gx, gy = mouseCoords(x, y)
    StateManager.mousereleased(gx, gy, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    local gx, gy = mouseCoords(x, y)

    local scale = Screen.getScale()
    if usesLogicalCanvas() and scale > 0 then
        dx, dy = dx / scale, dy / scale
    end

    StateManager.mousemoved(gx, gy, dx, dy, istouch)
end

function love.wheelmoved(dx, dy)
    StateManager.wheelmoved(dx, dy)
end

function love.resize(w, h)
    Screen.resize(w, h)

    local ok, err = pcall(StateManager.resize, w, h)
    if not ok then print("ERROR in resize: " .. tostring(err)) end
end

function love.quit()
    if not _G.HEADLESS then
        local ok, err = pcall(function() ConfigManager:saveAllConfigs() end)
        if not ok then print("ERROR saving configs: " .. tostring(err)) end
    end
    return false
end
