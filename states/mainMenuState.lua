-- states/mainMenuState.lua
local StateManager = require("modules.statemanager")
local roundState  = require("states/roundState")
local statsState  = require("states/statsState")

local mainMenuState = {}

local menuOptions = {"Start Endless Mode", "View Statistics", "Exit"}
local currentSelection = 1

function mainMenuState.enter()
    currentSelection = 1
end

function mainMenuState.update(dt)
    -- Nothing required here yet.
end

function mainMenuState.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Main Menu", 0, 50, love.graphics.getWidth(), "center")
    
    for i, option in ipairs(menuOptions) do
        if i == currentSelection then
            love.graphics.setColor(1, 1, 0)  -- highlight selection
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(option, 0, 100 + i * 30, love.graphics.getWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function mainMenuState.keypressed(key)
    if key == "up" then
        currentSelection = currentSelection - 1
        if currentSelection < 1 then currentSelection = #menuOptions end
    elseif key == "down" then
        currentSelection = currentSelection + 1
        if currentSelection > #menuOptions then currentSelection = 1 end
    elseif key == "return" or key == "kpenter" then
        if currentSelection == 1 then
            StateManager.switch(roundState)
        elseif currentSelection == 2 then
            StateManager.switch(statsState)
        elseif currentSelection == 3 then
            love.event.quit()
        end
    end
end

function mainMenuState.textinput(text)
    -- No text input needed in the main menu.
end

return mainMenuState
