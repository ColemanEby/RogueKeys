-- states/mainMenuState.lua
local StateManager = require("modules/statemanager")
-- Do NOT require the other states here—lazy-load them in the key handler.
local mainMenuState = {}
mainMenuState.name = "MainMenu"

local menuOptions = {"Start Endless Mode", "View Statistics", "Exit"}
local currentSelection = 1

function mainMenuState.enter()
    currentSelection = 1
    print("Entered Main Menu")
end

function mainMenuState.update(dt)
end

function mainMenuState.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Main Menu", 0, 50, love.graphics.getWidth(), "center")
    
    for i, option in ipairs(menuOptions) do
        if i == currentSelection then
            love.graphics.setColor(1, 1, 0)  -- highlight
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
    elseif (key == "return") or (key == "kpenter") then
        if currentSelection == 1 then
            print("Before switching: MainMenu -> keyboardSelectState")
            local keyboardSelectState = require("states/keyboardSelectState")
            StateManager.switch(keyboardSelectState)
            print("After switching to KeyboardSelectState")
        elseif currentSelection == 2 then
            print("Before switching: MainMenu -> StatsState")
            local statsState = require("states/statsState")
            StateManager.switch(statsState)
            print("After switching to StatsState")
        elseif currentSelection == 3 then
            love.event.quit()
        end
    end
end

function mainMenuState.textinput(text)
    -- No text input needed.
end

return mainMenuState
