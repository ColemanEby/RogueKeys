-- engine/stateManager.lua
-- State Manager: history-tracked switching, a real fade transition, an overlay
-- stack (for things like a pause menu drawn over a dimmed round), and params
-- delivery into `enter`.
--
-- Overlay drawing: while an overlay is active, StateManager.current *is* the
-- overlay (mousepressed/keypressed/update all naturally "just work" because
-- everything reads StateManager.current). draw() is the one exception: it
-- calls StateManager.drawUnderlay() first so the state beneath the overlay
-- still renders (dimmed) before the overlay draws on top of it. Only the
-- immediate state beneath the top overlay is drawn -- deeply nested overlays
-- do not show every ancestor.

local Screen = require("modules/ui/screen")

local StateManager = {
    current = nil,
    history = {},
    overlayStack = {}, -- states beneath the active overlay(s), bottom..top
    stateCache = {}, -- Cache states to avoid reloading
    maxHistorySize = 10,
    transitioning = false,
    transitionDuration = 0.2,
    transitionTimer = 0,
    transitionType = "fade", -- "fade", "slide", etc.
    onTransitionComplete = nil,
    registeredStates = {} -- Registry of available states
}

-- Transition screen info
local transitionAlpha = 0
local transitionSwapped = false

-- Register a state with the manager
function StateManager.registerState(stateName, stateModule)
    if not stateName or not stateModule then
        print("StateManager: Cannot register nil state or module")
        return false
    end

    StateManager.registeredStates[stateName] = StateManager.createState(stateModule)
    print("StateManager: Registered state '" .. stateName .. "'")
    return true
end

-- Create a state with consistent methods if any are missing. Idempotent: safe
-- to call more than once on the same table (main.lua does, on purpose).
function StateManager.createState(stateModule)
    local state = stateModule or {}

    -- Ensure the state has a name
    if not state.name then
        state.name = "UnnamedState"
        print("StateManager: Warning - State has no name, using 'UnnamedState'")
    end

    -- Ensure all required methods exist
    state.enter = state.enter or function(params) end
    state.exit = state.exit or function() end
    state.update = state.update or function(dt) end
    state.draw = state.draw or function() end
    state.keypressed = state.keypressed or function(key) end
    state.keyreleased = state.keyreleased or function(key) end
    state.textinput = state.textinput or function(text) end
    state.resize = state.resize or function(w, h) end

    -- Deliberately NOT defaulted: `resume`. Its absence is how pop() decides
    -- between resuming an overlaid state and re-entering it from scratch.

    return state
end

-- Load a state module by name and cache it. Slash-form require to match the
-- rest of the codebase (this used to be dot-form, alone).
function StateManager.loadState(stateName)
    if StateManager.registeredStates[stateName] then
        return StateManager.registeredStates[stateName]
    end

    if StateManager.stateCache[stateName] then
        return StateManager.stateCache[stateName]
    end

    local status, stateModule = pcall(require, "states/" .. stateName)
    if not status then
        print("StateManager: Error loading state '" .. stateName .. "': " .. tostring(stateModule))
        return nil
    end

    local state = StateManager.createState(stateModule)
    StateManager.stateCache[stateName] = state
    return state
end

-- Resolve a string name (lazy-load + cache) or an already-built state table
-- (tests, and back()/pop() reusing a state pulled off a stack) into a state.
local function resolveState(nameOrState)
    if nameOrState == nil then return nil end
    if type(nameOrState) == "string" then
        return StateManager.loadState(nameOrState)
    end
    return StateManager.createState(nameOrState)
end

-- Add current state to history stack
function StateManager.pushHistory(state)
    -- Only track non-nil states
    if state then
        table.insert(StateManager.history, state)

        -- Limit history size
        if #StateManager.history > StateManager.maxHistorySize then
            table.remove(StateManager.history, 1)
        end
    end
end

-- Actually perform exit(old) -> [record history] -> current = new -> enter(new).
-- `current` is assigned before enter() runs so a throwing enter still leaves
-- the manager in a valid, usable state rather than half-updated.
local function performSwitch(newState, params, recordHistory)
    if StateManager.current and StateManager.current.exit then
        local ok, err = pcall(StateManager.current.exit)
        if not ok then
            print("StateManager: Error during state exit: " .. tostring(err))
        end
    end

    if recordHistory then
        StateManager.pushHistory(StateManager.current)
    end

    StateManager.current = newState

    if newState and newState.enter then
        local ok, err = pcall(newState.enter, params)
        if not ok then
            print("StateManager: Error during state enter: " .. tostring(err))
        end
    end
end

-- Switch to a new state (by name or table), through the fade transition.
-- `params` is handed to the new state's enter(params) -- e.g.
-- switch("shopState", { returnTo = "resultsState" }).
function StateManager.switch(nameOrState, params)
    local newState = resolveState(nameOrState)
    if not newState then
        print("StateManager: Failed to switch to state '" .. tostring(nameOrState) .. "'")
        return
    end

    StateManager.startTransition(function()
        performSwitch(newState, params, true)
    end)
end

-- Switch without waiting for the fade. For --shot mode and tests, where an
-- unattended frame loop can't be relied on to drive the transition forward.
function StateManager.switchImmediate(nameOrState, params)
    local newState = resolveState(nameOrState)
    if not newState then
        print("StateManager: Failed to switch to state '" .. tostring(nameOrState) .. "'")
        return
    end

    StateManager.transitioning = false
    StateManager.transitionTimer = 0
    StateManager.onTransitionComplete = nil
    transitionAlpha = 0
    transitionSwapped = false

    performSwitch(newState, params, true)
end

-- Go back to the previous state. Does NOT push the state being left back onto
-- history -- switch() already does that, and re-switching through switch()
-- here used to double-push, which made back() . back() not actually walk back
-- two entries.
function StateManager.back()
    if #StateManager.history == 0 then
        print("StateManager: No state history available")
        return
    end

    local prevState = table.remove(StateManager.history)

    StateManager.startTransition(function()
        performSwitch(prevState, nil, false)
    end)
end

-- Push an overlay state on top of the current one without exiting it (the
-- current state is parked on overlayStack instead). Used for things like a
-- pause menu, which must not restart the round underneath it.
function StateManager.push(nameOrState, params)
    local newState = resolveState(nameOrState)
    if not newState then
        print("StateManager: Failed to push state '" .. tostring(nameOrState) .. "'")
        return
    end

    table.insert(StateManager.overlayStack, StateManager.current)
    StateManager.current = newState

    if newState.enter then
        local ok, err = pcall(newState.enter, params)
        if not ok then
            print("StateManager: Error during overlay enter: " .. tostring(err))
        end
    end
end

-- Pop the active overlay and resume whatever was beneath it. Calls resume()
-- if the underlying state has one (it wasn't torn down, so re-running enter()
-- would restart it); falls back to enter() for states that don't define one.
function StateManager.pop()
    if #StateManager.overlayStack == 0 then
        print("StateManager: No overlay to pop")
        return
    end

    if StateManager.current and StateManager.current.exit then
        local ok, err = pcall(StateManager.current.exit)
        if not ok then
            print("StateManager: Error during overlay exit: " .. tostring(err))
        end
    end

    local under = table.remove(StateManager.overlayStack)
    StateManager.current = under

    if under then
        local hook = under.resume or under.enter
        if hook then
            local ok, err = pcall(hook)
            if not ok then
                print("StateManager: Error during overlay resume: " .. tostring(err))
            end
        end
    end
end

function StateManager.isOverlayActive()
    return #StateManager.overlayStack > 0
end

-- Start a fade transition. `onComplete` runs at the midpoint (screen fully
-- black), which is where the actual state swap happens so it's never visible.
function StateManager.startTransition(onComplete)
    StateManager.transitioning = true
    StateManager.transitionTimer = 0
    StateManager.onTransitionComplete = onComplete
    transitionAlpha = 0
    transitionSwapped = false
end

-- Advance the fade. Written so a single large dt (tests forcing completion in
-- one call, or a hitch) still fires the midpoint swap instead of skipping it.
function StateManager.updateTransition(dt)
    if not StateManager.transitioning then return end

    StateManager.transitionTimer = StateManager.transitionTimer + dt
    local half = math.max(StateManager.transitionDuration, 0.0001) / 2

    if not transitionSwapped and StateManager.transitionTimer >= half then
        transitionSwapped = true
        local callback = StateManager.onTransitionComplete
        StateManager.onTransitionComplete = nil
        if callback then callback() end
    end

    if StateManager.transitionTimer >= StateManager.transitionDuration then
        StateManager.transitioning = false
        transitionSwapped = false
        transitionAlpha = 0
    elseif StateManager.transitionTimer <= half then
        transitionAlpha = StateManager.transitionTimer / half
    else
        transitionAlpha = 1 - (StateManager.transitionTimer - half) / half
    end
end

-- Draw the transition effect. Covers the logical 640x360 canvas when the
-- state on screen is one that draws in logical space (main.lua will have
-- pushed that canvas already), otherwise covers the real window.
function StateManager.drawTransition()
    if transitionAlpha <= 0 then return end
    -- Headless test runs deliberately have no window; calling LÖVE's drawing
    -- functions in that configuration is unsafe, but state draw() should still run.
    if rawget(_G, "HEADLESS") then return end

    local w, h
    if StateManager.current and StateManager.current.logical and Screen.isReady() then
        w, h = Screen.getWidth(), Screen.getHeight()
    else
        w, h = love.graphics.getWidth(), love.graphics.getHeight()
    end

    love.graphics.setColor(0, 0, 0, transitionAlpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw the state directly beneath the active overlay, dimmed, so an overlay
-- (pause menu) reads as sitting on top of the paused game rather than on a
-- blank background. No-op when no overlay is active.
function StateManager.drawUnderlay()
    local under = StateManager.overlayStack[#StateManager.overlayStack]
    if not under then return end

    if under.draw then
        local ok, err = pcall(under.draw)
        if not ok then
            print("StateManager: Error during underlay draw: " .. tostring(err))
        end
    end

    local w, h
    if under.logical and Screen.isReady() then
        w, h = Screen.getWidth(), Screen.getHeight()
    else
        w, h = love.graphics.getWidth(), love.graphics.getHeight()
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Update game state and transitions
function StateManager.update(dt)
    StateManager.updateTransition(dt)

    if StateManager.current and StateManager.current.update then
        local success, err = pcall(StateManager.current.update, dt)
        if not success then
            print("StateManager: Error during state update: " .. tostring(err))
        end
    end
end

-- Draw the current state (and, if an overlay is active, the dimmed state
-- beneath it first) plus the transition fade.
function StateManager.draw()
    if StateManager.isOverlayActive() then
        StateManager.drawUnderlay()
    end

    if StateManager.current and StateManager.current.draw then
        local success, err = pcall(StateManager.current.draw)
        if not success then
            print("StateManager: Error during state draw: " .. tostring(err))
            -- Draw a fallback message
            love.graphics.clear(0.2, 0.1, 0.1)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("Error drawing state: " .. tostring(err),
                    50, 50, love.graphics.getWidth() - 100)
        end
    else
        -- Draw a message if no state is active
        love.graphics.clear(0.1, 0.1, 0.1)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("No active state", 0, love.graphics.getHeight() / 2,
                love.graphics.getWidth(), "center")
    end

    StateManager.drawTransition()
end

-- Forward input to current state. Dropped entirely while transitioning so a
-- keypress can't land on a state that's only half swapped-in.
function StateManager.keypressed(key)
    if StateManager.transitioning then return end
    if StateManager.current and StateManager.current.keypressed then
        local success, err = pcall(StateManager.current.keypressed, key)
        if not success then
            print("StateManager: Error during keypressed: " .. tostring(err))
        end
    end
end

function StateManager.keyreleased(key)
    if StateManager.transitioning then return end
    if StateManager.current and StateManager.current.keyreleased then
        local success, err = pcall(StateManager.current.keyreleased, key)
        if not success then
            print("StateManager: Error during keyreleased: " .. tostring(err))
        end
    end
end

function StateManager.textinput(text)
    if StateManager.transitioning then return end
    if StateManager.current and StateManager.current.textinput then
        local success, err = pcall(StateManager.current.textinput, text)
        if not success then
            print("StateManager: Error during textinput: " .. tostring(err))
        end
    end
end

-- Mouse and wheel input go through the manager for the same reason keyboard
-- input does: so the transition guard applies to every input path, not just
-- the keyboard. main.lua translates coordinates into logical space first.
local function forwardMouse(callback, ...)
    if StateManager.transitioning then return end
    local state = StateManager.current
    if not state or not state[callback] then return end

    local success, err = pcall(state[callback], ...)
    if not success then
        print("StateManager: Error during " .. callback .. ": " .. tostring(err))
    end
end

function StateManager.mousepressed(x, y, button, istouch, presses)
    forwardMouse("mousepressed", x, y, button, istouch, presses)
end

function StateManager.mousereleased(x, y, button, istouch, presses)
    forwardMouse("mousereleased", x, y, button, istouch, presses)
end

function StateManager.mousemoved(x, y, dx, dy, istouch)
    forwardMouse("mousemoved", x, y, dx, dy, istouch)
end

function StateManager.wheelmoved(dx, dy)
    forwardMouse("wheelmoved", dx, dy)
end

-- Handle window resize
function StateManager.resize(w, h)
    if StateManager.current and StateManager.current.resize then
        local success, err = pcall(StateManager.current.resize, w, h)
        if not success then
            print("StateManager: Error during resize: " .. tostring(err))
        end
    end
end

-- Handle window focus change
function StateManager.focus(focused)
    if StateManager.current and StateManager.current.focus then
        local success, err = pcall(StateManager.current.focus, focused)
        if not success then
            print("StateManager: Error during focus change: " .. tostring(err))
        end
    end
end

return StateManager
