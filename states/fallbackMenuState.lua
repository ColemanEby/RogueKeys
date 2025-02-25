-- states/fallbackMenuState.lua
-- Simple fallback menu state that doesn't rely on other modules

local StateManager = require("engine/stateManager")

local FallbackMenuState = {
    name = "FallbackMenuState"
}

local menuItems = {
    { text = "Start Game", action = function()
        print("Attempting to start game...")
        StateManager.switch("roundState")
    end },
    { text = "Exit Game", action = function()
        love.event.quit()
    end }
}

local selectedItem = 1
local showDebugInfo = true

function FallbackMenuState.enter()
    print("FallbackMenuState: Entered")
end

function FallbackMenuState.update(dt)
    -- Nothing to update
end

function FallbackMenuState.draw()
    -- Draw background
    love.graphics.clear(0.1, 0.1, 0.2)

    -- Draw title
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local fontSize = font:getHeight()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    love.graphics.printf("Typing Trainer Roguelike", 0, screenHeight / 4, screenWidth, "center")

    -- Draw menu items
    local menuY = screenHeight / 2
    for i, item in ipairs(menuItems) do
        if i == selectedItem then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end

        love.graphics.printf(item.text, 0, menuY + (i-1) * fontSize * 2, screenWidth, "center")
    end

    -- Draw instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Up/Down: Select, Enter: Confirm", 0, screenHeight - fontSize * 3, screenWidth, "center")

    -- Draw debug info
    if showDebugInfo then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
        love.graphics.print("Memory: " .. string.format("%.2f MB", collectgarbage("count") / 1024), 10, 30)
        love.graphics.print("Current State: FallbackMenuState", 10, 50)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

function FallbackMenuState.keypressed(key)
    if key == "up" then
        selectedItem = selectedItem - 1
        if selectedItem < 1 then
            selectedItem = #menuItems
        end
    elseif key == "down" then
        selectedItem = selectedItem + 1
        if selectedItem > #menuItems then
            selectedItem = 1
        end
    elseif key == "return" or key == "kpenter" or key == "space" then
        if menuItems[selectedItem] and menuItems[selectedItem].action then
            menuItems[selectedItem].action()
        end
    elseif key == "f1" then
        showDebugInfo = not showDebugInfo
    end
end

function FallbackMenuState.mousepressed(x, y, button)
    -- Handle mouse clicks (simple implementation)
    if button == 1 then
        local font = love.graphics.getFont()
        local fontSize = font:getHeight()
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local menuY = screenHeight / 2

        for i, item in ipairs(menuItems) do
            local itemY = menuY + (i-1) * fontSize * 2
            if y >= itemY and y <= itemY + fontSize then
                if item.action then
                    item.action()
                end
                break
            end
        end
    end
end

return FallbackMenuState