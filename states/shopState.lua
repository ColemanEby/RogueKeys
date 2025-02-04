-- states/shopState.lua
local StateManager = require("modules/statemanager")
local Player = require("modules/player")
-- We will lazy-load roundState when needed.
local shopState = {}

local upgrades = {
    { name = "Red Key Cap", cost = 50, bonus = 0.1 },
    { name = "Blue Key Cap", cost = 75, bonus = 0.15 },
    { name = "Green Key Cap", cost = 100, bonus = 0.2 },
    { name = "Purple Key Cap", cost = 150, bonus = 0.25 }
}
local currentSelection = 1

function shopState.enter()
    currentSelection = 1
end

function shopState.update(dt)
end

function shopState.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Shop - Upgrade Your Keyboard", 0, 20, love.graphics.getWidth(), "center")
    
    local y = 80
    for i, item in ipairs(upgrades) do
        if i == currentSelection then
            love.graphics.setColor(1,1,0)
        else
            love.graphics.setColor(1,1,1)
        end
        local text = string.format("%s - Cost: %d, Bonus: +%.2f", item.name, item.cost, item.bonus)
        love.graphics.printf(text, 0, y, love.graphics.getWidth(), "center")
        y = y + 30
    end
    
    local doneY = y + 20
    if currentSelection == #upgrades + 1 then
        love.graphics.setColor(1,1,0)
    else
        love.graphics.setColor(1,1,1)
    end
    love.graphics.printf("Done", 0, doneY, love.graphics.getWidth(), "center")
    
    love.graphics.setColor(1,1,1)
    local infoY = doneY + 50
    love.graphics.printf(string.format("Your Money: %d", Player.totalMoney), 0, infoY, love.graphics.getWidth(), "center")
    love.graphics.printf(string.format("Keyboard Multiplier: %.2f", Player.keyboard.multiplier), 0, infoY+30, love.graphics.getWidth(), "center")
end

function shopState.keypressed(key)
    if key == "up" then
        currentSelection = currentSelection - 1
        if currentSelection < 1 then
            currentSelection = #upgrades + 1
        end
    elseif key == "down" then
        currentSelection = currentSelection + 1
        if currentSelection > #upgrades + 1 then
            currentSelection = 1
        end
    elseif key == "return" or key == "kpenter" then
        if currentSelection <= #upgrades then
            local item = upgrades[currentSelection]
            if Player.totalMoney >= item.cost then
                Player.totalMoney = Player.totalMoney - item.cost
                Player.keyboard.multiplier = Player.keyboard.multiplier + item.bonus
            end
        else
            -- "Done" option: finish shopping and return to the next round.
            local roundState = require("states/roundState")
            StateManager.switch(roundState)
        end
    end
end

function shopState.textinput(text)
end

return shopState
