-- engine/stateManager.lua
-- Enhanced State Manager with state history tracking and transitions

local StateManager = {
    current = nil,
    history = {},
    stateCache = {}, -- Cache states to avoid reloading
    maxHistorySize = 10,
    transitioning = false,
    transitionDuration = 0.3,
    transitionTimer = 0,
    transitionType = "fade", -- "fade", "slide", etc.
    onTransitionComplete = nil,
    registeredStates = {} -- New: Registry of available states
}

-- Transition screen info
local transitionAlpha = 0

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

-- Create a state with consistent methods if any are missing
function StateManager.createState(stateModule)
    local state = stateModule or {}

    -- Ensure the state has a name
    if not state.name then
        state.name = "UnnamedState"
        print("StateManager: Warning - State has no name, using 'UnnamedState'")
    end

    -- Ensure all required methods exist
    state.enter = state.enter or function() end
    state.exit = state.exit or function() end
    state.update = state.update or function(dt) end
    state.draw = state.draw or function() end
    state.keypressed = state.keypressed or function(key) end
    state.keyreleased = state.keyreleased or function(key) end
    state.textinput = state.textinput or function(text) end
    state.resize = state.resize or function(w, h) end

    return state
end

-- Load a state module by name and cache it
function StateManager.loadState(stateName)
    -- Check if the state is already registered
    if StateManager.registeredStates[stateName] then
        return StateManager.registeredStates[stateName]
    end

    -- Check if the state is already cached
    if StateManager.stateCache[stateName] then
        return StateManager.stateCache[stateName]
    end

    -- Try to load the state module
    print("StateManager: Attempting to load state '" .. stateName .. "'")
    local status, stateModule = pcall(require, "states." .. stateName)
    if not status then
        print("StateManager: Error loading state '" .. stateName .. "': " .. tostring(stateModule))
        return nil
    end

    local state = StateManager.createState(stateModule)
    StateManager.stateCache[stateName] = state
    return state
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

-- Switch to a new state
function StateManager.switch(newStateOrName)
    print("StateManager: Switching to state: " .. tostring(newStateOrName))

    -- Allow passing state name as string for lazy loading
    local newState = newStateOrName
    if type(newStateOrName) == "string" then
        -- Check registered states first
        if StateManager.registeredStates[newStateOrName] then
            newState = StateManager.registeredStates[newStateOrName]
        else
            -- Try loading the state
            newState = StateManager.loadState(newStateOrName)
            if not newState then
                print("StateManager: Failed to switch to state '" .. newStateOrName .. "'")
                return
            end
        end
    end

    -- Start transition animation
    StateManager.startTransition(function()
        -- Execute actual state change after transition starts
        if StateManager.current and StateManager.current.exit then
            local success, err = pcall(StateManager.current.exit)
            if not success then
                print("StateManager: Error during state exit: " .. tostring(err))
            end
        end

        StateManager.pushHistory(StateManager.current)

        if newState and newState.enter then
            local success, err = pcall(newState.enter)
            if not success then
                print("StateManager: Error during state enter: " .. tostring(err))
            end
        end

        StateManager.current = newState
        print("StateManager: switched to state '" .. (newState.name or "unnamed") .. "'")
    end)
end

-- Go back to the previous state
function StateManager.back()
    if #StateManager.history > 0 then
        local prevState = table.remove(StateManager.history)
        -- Don't add to history since we're going back
        StateManager.switch(prevState)
    else
        print("StateManager: No state history available")
    end
end

-- Start a state transition effect
function StateManager.startTransition(onComplete)
    StateManager.transitioning = true
    StateManager.transitionTimer = 0
    StateManager.onTransitionComplete = onComplete
    transitionAlpha = 0

    -- Execute the completion callback immediately for now
    -- (we can restore the animation later once basic functionality works)
    if StateManager.onTransitionComplete then
        StateManager.onTransitionComplete()
        StateManager.onTransitionComplete = nil
    end

    -- Skip the transition for now
    StateManager.transitioning = false
end

-- Update the transition animation
function StateManager.updateTransition(dt)
    if StateManager.transitioning then
        StateManager.transitionTimer = StateManager.transitionTimer + dt

        -- First half: fade to black
        if StateManager.transitionTimer <= StateManager.transitionDuration / 2 then
            transitionAlpha = (StateManager.transitionTimer / (StateManager.transitionDuration / 2))

            -- At midpoint, perform the actual state change
            if transitionAlpha >= 1 and StateManager.onTransitionComplete then
                StateManager.onTransitionComplete()
                StateManager.onTransitionComplete = nil
            end
            -- Second half: fade from black
        else
            transitionAlpha = 1 - ((StateManager.transitionTimer - StateManager.transitionDuration / 2)
                    / (StateManager.transitionDuration / 2))
        end

        -- End transition if complete
        if StateManager.transitionTimer >= StateManager.transitionDuration then
            StateManager.transitioning = false
            transitionAlpha = 0
        end
    end
end

-- Draw the transition effect
function StateManager.drawTransition()
    if transitionAlpha > 0 then
        love.graphics.setColor(0, 0, 0, transitionAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Update game state and transitions
function StateManager.update(dt)
    -- Update transition animation
    StateManager.updateTransition(dt)

    -- Update current state if we have one
    if StateManager.current and StateManager.current.update then
        local success, err = pcall(StateManager.current.update, dt)
        if not success then
            print("StateManager: Error during state update: " .. tostring(err))
        end
    end
end

-- Draw the current state and transition effects
function StateManager.draw()
    -- Draw current state
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

    -- Draw transition overlay
    StateManager.drawTransition()
end

-- Forward input to current state
function StateManager.keypressed(key)
    if StateManager.current and StateManager.current.keypressed then
        local success, err = pcall(StateManager.current.keypressed, key)
        if not success then
            print("StateManager: Error during keypressed: " .. tostring(err))
        end
    end
end

function StateManager.keyreleased(key)
    if StateManager.current and StateManager.current.keyreleased then
        local success, err = pcall(StateManager.current.keyreleased, key)
        if not success then
            print("StateManager: Error during keyreleased: " .. tostring(err))
        end
    end
end

function StateManager.textinput(text)
    if StateManager.current and StateManager.current.textinput then
        local success, err = pcall(StateManager.current.textinput, text)
        if not success then
            print("StateManager: Error during textinput: " .. tostring(err))
        end
    end
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