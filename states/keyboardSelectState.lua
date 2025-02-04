-- states/keyboardSelectState.lua
local StateManager = require("modules/statemanager")
local Player = require("modules/player")
local Keyboard = require("modules/keyboard")
local roundState = require("states/roundState")  -- Safe to require here.

local keyboardSelectState = {}
keyboardSelectState.name = "KeyboardSelectState"  -- Explicitly set name

local keyboards = {
    { name = "Standard Keyboard", description = "A standard keyboard with basic keycaps." }
    -- Future keyboards can be added here.
}
local currentSelection = 1

function keyboardSelectState.enter()
    currentSelection = 1
end

function keyboardSelectState.update(dt)
end

function keyboardSelectState.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Select a Keyboard", 0, 50, love.graphics.getWidth(), "center")
    
    local y = 100
    for i, kb in ipairs(keyboards) do
        if i == currentSelection then
            love.graphics.setColor(1,1,0)
        else
            love.graphics.setColor(1,1,1)
        end
        love.graphics.printf(kb.name, 0, y, love.graphics.getWidth(), "center")
        y = y + 40
    end
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Press Enter to select", 0, love.graphics.getHeight()-60, love.graphics.getWidth(), "center")
end

function keyboardSelectState.keypressed(key)
    if key == "up" then
        currentSelection = currentSelection - 1
        if currentSelection < 1 then currentSelection = #keyboards end
    elseif key == "down" then
        currentSelection = currentSelection + 1
        if currentSelection > #keyboards then currentSelection = 1 end
    elseif (key == "return") or (key == "kpenter") then
        local selectedKeyboard = keyboards[currentSelection]
        local kb = Keyboard.new()
        kb.name = selectedKeyboard.name
        Player.keyboard = kb
        StateManager.switch(roundState)
    end
end

function keyboardSelectState.textinput(text)
    -- No text input needed.
end

return keyboardSelectState
