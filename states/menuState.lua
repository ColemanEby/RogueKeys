-- states/menuState.lua
-- Main menu state with simplified implementation for debugging

local StateManager = require("engine/stateManager")
local ResourceManager = require("engine/resourceManager")
local ConfigManager = require("engine/configManager")

local MenuState = {
    name = "MenuState"
}

-- Local variables
local menuItems = {
    { text = "Start Game", action = function()
        print("Starting game...")
        StateManager.switch("roundState")
    end },
    { text = "Keyboard Shop", action = function()
        print("Opening shop...")
        StateManager.switch("shopState")
    end },
    { text = "Statistics", action = function()
        print("Opening statistics...")
        StateManager.switch("statsState")
    end },
    { text = "Exit Game", action = function()
        print("Exiting game...")
        love.event.quit()
    end }
}

local selectedItem = 1
local backgroundAlpha = 0
local titleAlpha = 0

-- Initialize the menu state
function MenuState.enter()
    print("MenuState: Entered")
    selectedItem = 1
    backgroundAlpha = 0
    titleAlpha = 0
end

-- Update the menu state
function MenuState.update(dt)
    -- Update fade-in animations
    if backgroundAlpha < 1 then
        backgroundAlpha = math.min(1, backgroundAlpha + dt * 2)
    end

    if titleAlpha < 1 then
        titleAlpha = math.min(1, titleAlpha + dt * 1.5)
    end
end

-- Draw the menu state
function MenuState.draw()
    -- Draw background
    love.graphics.clear(0.1 * backgroundAlpha, 0.1 * backgroundAlpha, 0.2 * backgroundAlpha)

    -- Draw title
    love.graphics.setColor(1, 1, 1, titleAlpha)
    local font = love.graphics.getFont()
    local titleSize = 28
    local titleFont = love.graphics.newFont(titleSize)
    love.graphics.setFont(titleFont)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    love.graphics.printf("Typing Trainer Roguelike", 0, screenHeight / 4, screenWidth, "center")

    -- Draw menu items
    local menuFont = love.graphics.newFont(20)
    love.graphics.setFont(menuFont)
    local menuY = screenHeight / 2
    local lineHeight = menuFont:getHeight() * 1.5

    for i, item in ipairs(menuItems) do
        if i == selectedItem then
            love.graphics.setColor(1, 1, 0, titleAlpha)
        else
            love.graphics.setColor(1, 1, 1, titleAlpha * 0.8)
        end

        love.graphics.printf(item.text, 0, menuY + (i-1) * lineHeight, screenWidth, "center")
    end

    -- Draw instructions
    love.graphics.setFont(font)
    love.graphics.setColor(0.7, 0.7, 0.7, titleAlpha)
    love.graphics.printf("Up/Down: Select, Enter: Confirm", 0, screenHeight - 50, screenWidth, "center")

    -- Reset color and font
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(font)
end

-- Handle keyboard input
function MenuState.keypressed(key)
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
        if menuItems[selectedItem].action then
            menuItems[selectedItem].action()
        end
    end
end

-- Handle text input
function MenuState.textinput(text)
    -- Not needed for menu state
end

-- Handle mouse clicks
function MenuState.mousepressed(x, y, button)
    if button == 1 then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local menuY = screenHeight / 2
        local lineHeight = 30

        for i, item in ipairs(menuItems) do
            local itemY = menuY + (i-1) * lineHeight
            if y >= itemY and y <= itemY + lineHeight then
                if item.action then
                    item.action()
                end
                break
            end
        end
    end
end

return MenuState