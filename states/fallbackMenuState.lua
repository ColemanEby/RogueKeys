-- states/fallbackMenuState.lua
-- Safety-net menu shown when menuState fails to load. Its whole job is to
-- still work when something else is broken, so keep its dependency list to
-- the bare minimum: StateManager and Theme, both of which main.lua already
-- requires successfully before fallbackMenuState is even considered. It does
-- NOT opt into the logical canvas (`logical = true`) -- it needs to render
-- even if Screen/the canvas failed to initialise.

local StateManager = require("engine/stateManager")
local Theme = require("modules/ui/theme")

local FallbackMenuState = {
    name = "FallbackMenuState"
}

local menuItems = {
    { text = "Start Game", action = function()
        StateManager.switch("roundState")
    end },
    { text = "Exit Game", action = function()
        love.event.quit()
    end }
}

local selectedItem = 1
local showDebugInfo = true

function FallbackMenuState.enter()
    if _G.DEBUG_MODE then print("FallbackMenuState: entered") end
end

function FallbackMenuState.draw()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    love.graphics.clear(Theme.color("base"))

    love.graphics.setFont(Theme.font("display"))
    Theme.setColor("text")
    love.graphics.printf("Typing Trainer Roguelike", 0, screenHeight / 4, screenWidth, "center")

    love.graphics.setFont(Theme.font("body"))
    local fontSize = Theme.font("body"):getHeight()
    local menuY = screenHeight / 2
    for i, item in ipairs(menuItems) do
        Theme.setColor(i == selectedItem and "accent" or "text")
        love.graphics.printf(item.text, 0, menuY + (i - 1) * fontSize * 2, screenWidth, "center")
    end

    love.graphics.setFont(Theme.font("small"))
    Theme.setColor("textMuted")
    love.graphics.printf("Up/Down: Select, Enter: Confirm", 0, screenHeight - fontSize * 3, screenWidth, "center")

    if showDebugInfo then
        Theme.setColor("textMuted", 0.7)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
        love.graphics.print("Memory: " .. string.format("%.2f MB", collectgarbage("count") / 1024), 10, 30)
        love.graphics.print("Current State: FallbackMenuState", 10, 50)
    end

    Theme.setColor("text")
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
    if button ~= 1 then return end

    local fontSize = Theme.font("body"):getHeight()
    local screenHeight = love.graphics.getHeight()
    local menuY = screenHeight / 2

    for i, item in ipairs(menuItems) do
        local itemY = menuY + (i - 1) * fontSize * 2
        if y >= itemY and y <= itemY + fontSize then
            if item.action then item.action() end
            break
        end
    end
end

return FallbackMenuState
