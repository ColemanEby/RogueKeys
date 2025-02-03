-- states/statsState.lua
local StatTracker = require("modules.statstracker")
local StateManager = require("modules.statemanager")
-- local mainMenuState = require("states.mainMenuState")

local statsState = {}

function statsState.enter()
    -- Load statistics from file.
    StatTracker.load()
end

function statsState.update(dt)
    -- No update logic required.
end

function statsState.draw()
    love.graphics.clear(0.15, 0.15, 0.15)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Game Statistics", 0, 30, love.graphics.getWidth(), "center")

    local stats = StatTracker.getStats()
    local y = 70
    local lineHeight = 20
    love.graphics.printf("Total Sessions: " .. stats.totalSessions, 0, y, love.graphics.getWidth(), "center")
    y = y + lineHeight
    love.graphics.printf("Total Keystrokes: " .. stats.totalKeystrokes, 0, y, love.graphics.getWidth(), "center")
    y = y + lineHeight
    love.graphics.printf("Total Mistakes: " .. stats.totalMistakes, 0, y, love.graphics.getWidth(), "center")
    y = y + lineHeight
    love.graphics.printf("Total Correct: " .. stats.totalCorrect, 0, y, love.graphics.getWidth(), "center")
    y = y + lineHeight
    love.graphics.printf(string.format("Total Time: %.2fs", stats.totalTime), 0, y, love.graphics.getWidth(), "center")
    y = y + lineHeight
    love.graphics.printf(string.format("Best APM: %.2f", stats.bestAPM), 0, y, love.graphics.getWidth(), "center")
    y = y + lineHeight
    love.graphics.printf(string.format("Best Accuracy: %.2f%%", stats.bestAccuracy), 0, y, love.graphics.getWidth(),
        "center")
    y = y + lineHeight
    love.graphics.printf("Best Longest Streak: " .. stats.bestStreak, 0, y, love.graphics.getWidth(), "center")
    y = y + lineHeight
    love.graphics.printf("Rounds Without Error: " .. stats.roundsWithoutError, 0, y, love.graphics.getWidth(), "center")

    y = y + lineHeight * 2
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Press M to return to Main Menu", 0, y, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

function statsState.keypressed(key)
    if key == "m" then
        -- Lazy-load mainMenuState to break the circular dependency.
        local mainMenuState = require("states.mainMenuState")
        StateManager.switch(mainMenuState)
    end
end

function statsState.textinput(text)
    -- No text input for the stats screen.
end

return statsState
