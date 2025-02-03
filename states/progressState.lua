-- states/progressState.lua
local StateManager  = require("modules.statemanager")
-- local roundState    = require("states/roundState")
-- local mainMenuState = require("states.mainMenuState")

local progressState = {}

-- Local variables to hold the round’s data.
local data = nil
local passed = false

-- Called by roundState to set the data before switching.
function progressState.setData(sessionStats, didPass)
    data = sessionStats
    passed = didPass
end

function progressState.enter()
    -- Nothing additional to set up.
end

function progressState.update(dt)
end

function progressState.draw()
    love.graphics.clear(0.15, 0.15, 0.15)
    love.graphics.setColor(1, 1, 1)
    
    local title = ""
    if passed then
        title = "Round " .. data.roundNumber .. " PASSED!"
    else
        title = "Round " .. data.roundNumber .. " FAILED. GAME OVER."
    end
    love.graphics.printf(title, 0, 50, love.graphics.getWidth(), "center")
    
    -- Display detailed round stats.
    local statsLines = {
       string.format("Your Accuracy: %.2f%% (Required: %.2f%%)", data.accuracy, data.requiredAccuracy),
       string.format("Your Score: %.2f (Required: %.2f)", data.roundScore, data.requiredScore),
       string.format("APM: %.2f", data.apm),
       string.format("Time: %.2fs", data.time),
       string.format("Longest Streak: %d", data.longestStreak),
    }
    local y = 100
    for _, line in ipairs(statsLines) do
        love.graphics.printf(line, 0, y, love.graphics.getWidth(), "center")
        y = y + 30
    end
    
    love.graphics.setColor(1, 1, 0)
    if passed then
        love.graphics.printf("Press Enter to continue to the next round", 0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
    else
        love.graphics.printf("Press M to return to the Main Menu", 0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function progressState.keypressed(key)
    if passed then
       if key == "return" or key == "kpenter" then
            local roundState = require("states/roundState")
            StateManager.switch(roundState)
       end
    else
       if key == "m" then
            local mainMenuState = require("states.mainMenuState")
            StateManager.switch(mainMenuState)
       end
    end
end

function progressState.textinput(t)
    -- No text input required on this screen.
end

return progressState
