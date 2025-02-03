-- main.lua
local StateManager = require("modules.statemanager")
local mainMenuState = require("states.mainMenuState")

function love.load()
    love.graphics.setFont(love.graphics.newFont(14))
    StateManager.switch(mainMenuState)
end

function love.update(dt)
    StateManager.update(dt)
end

function love.draw()
    StateManager.draw()
end

function love.keypressed(key)
    StateManager.keypressed(key)
end

function love.textinput(text)
    StateManager.textinput(text)
end
