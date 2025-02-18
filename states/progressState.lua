-- states/progressState.lua
local StatTracker  = require("modules/statstracker")
local StateManager = require("modules/statemanager")
local mainMenuState = require("states/mainMenuState")
local progressState = {}
progressState.name = "ProgressState"

local data = nil
local passed = false

function progressState.setData(sessionStats, didPass)
    data = sessionStats
    passed = didPass
end

function progressState.enter()
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
    
    local statsLines = {
       string.format("Your Score: %.2f (Required: %.2f)", data.score, data.requiredScore),
       string.format("Keystrokes: %d", data.keystrokes),
       string.format("Time: %.2fs", data.time),
       string.format("Money Earned: %d", data.moneyEarned),
    }
    local y = 100
    for _, line in ipairs(statsLines) do
        love.graphics.printf(line, 0, y, love.graphics.getWidth(), "center")
        y = y + 30
    end
    
    love.graphics.setColor(1, 1, 0)
    if passed then
        love.graphics.printf("Press Enter to continue to next round, or S to shop for upgrades", 0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
    else
        love.graphics.printf("Press M to return to Main Menu", 0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function progressState.keypressed(key)
    if passed then
       if (key == "return") or (key == "kpenter") then
            local roundState = require("states/roundState")
            StateManager.switch(roundState)
       elseif key == "s" then
            local shopState = require("states/shopState")
            StateManager.switch(shopState)
       end
    else
       if key == "m" then
            StateManager.switch(mainMenuState)
       end
    end
end

function progressState.textinput(text)
end

return progressState
