-- modules/statemanager.lua
local StateManager = {}
StateManager.current = nil

function StateManager.switch(newState)
    -- (Optional) Clear the old state reference first.
    StateManager.current = nil

    if newState and newState.enter then
         newState.enter()
    end
    print("StateManager: switching to state '" .. (newState.name or "unnamed") .. "'")
    StateManager.current = newState
end

function StateManager.update(dt)
    if StateManager.current and StateManager.current.update then
         StateManager.current.update(dt)
    end
end

function StateManager.draw()
    if StateManager.current and StateManager.current.draw then
         StateManager.current.draw()
    end
end

function StateManager.keypressed(key)
    if StateManager.current and StateManager.current.keypressed then
         StateManager.current.keypressed(key)
    end
end

function StateManager.textinput(text)
    if StateManager.current and StateManager.current.textinput then
         StateManager.current.textinput(text)
    end
end

return StateManager
