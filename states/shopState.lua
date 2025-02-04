-- states/shopState.lua
local StateManager = require("modules/statemanager")
local Player = require("modules/player")
local shopState = {}
shopState.name = "ShopState"

local offers = {}      -- list of offers (each offer: { key, cost, bonus })
local currentSelection = 1

-- List of possible keys for upgrade.
local possibleKeys = {
    "a","b","c","d","e","f","g","h","i","j","k","l","m",
    "n","o","p","q","r","s","t","u","v","w","x","y","z",
    ",", ".", "?", "!", " "
}

-- Helper: shuffle a table in place.
local function shuffle(t)
    local n = #t
    for i = n, 2, -1 do
       local j = math.random(i)
       t[i], t[j] = t[j], t[i]
    end
end

function shopState.generateOffers()
    offers = {}
    -- Build list of keys not yet upgraded.
    local availableKeys = {}
    for i, k in ipairs(possibleKeys) do
         if not (Player.keyboard.upgrades and Player.keyboard.upgrades[k]) then
             table.insert(availableKeys, k)
         end
    end
    shuffle(availableKeys)
    local numOffers = math.min(5, #availableKeys)
    for i = 1, numOffers do
         local keyChar = availableKeys[i]
         local cost = math.random(50, 150)
         local bonus = math.random(5, 30) / 100  -- bonus between 0.05 and 0.30
         table.insert(offers, { key = keyChar, cost = cost, bonus = bonus })
    end
end

function shopState.enter()
    currentSelection = 1
    shopState.generateOffers()
end

-- Draw a simple keyboard layout.
function shopState.drawKeyboardLayout(x, y)
    local rows = {
       "QWERTYUIOP",
       "ASDFGHJKL",
       "ZXCVBNM",
       " ,.?!"
    }
    local font = love.graphics.newFont(18)
    love.graphics.setFont(font)
    local keyWidth = font:getWidth("W") + 10
    local keyHeight = font:getHeight() + 10
    for r, row in ipairs(rows) do
         for i = 1, #row do
             local ch = row:sub(i, i)
             local drawX = x + (i - 1) * keyWidth
             local drawY = y + (r - 1) * keyHeight
             -- If this key (lowercase) is upgraded, draw in green.
             if Player.keyboard.upgrades and Player.keyboard.upgrades[ch:lower()] then
                 love.graphics.setColor(0, 1, 0)
             else
                 love.graphics.setColor(1, 1, 1)
             end
             love.graphics.rectangle("line", drawX, drawY, keyWidth, keyHeight)
             love.graphics.printf(ch, drawX, drawY + 5, keyWidth, "center")
         end
    end
end

function shopState.update(dt)
end

function shopState.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Shop - Upgrade Specific Keys", 0, 20, love.graphics.getWidth(), "center")
    
    local startY = 60
    for i, offer in ipairs(offers) do
         if i == currentSelection then
              love.graphics.setColor(1, 1, 0)
         else
              love.graphics.setColor(1, 1, 1)
         end
         local text = string.format("Key '%s' - Cost: %d, Bonus: +%.2f", offer.key, offer.cost, offer.bonus)
         love.graphics.printf(text, 0, startY + (i - 1) * 30, love.graphics.getWidth(), "center")
    end
    
    local doneY = startY + (#offers) * 30 + 20
    if currentSelection == #offers + 1 then
         love.graphics.setColor(1, 1, 0)
    else
         love.graphics.setColor(1, 1, 1)
    end
    love.graphics.printf("Done", 0, doneY, love.graphics.getWidth(), "center")
    
    local infoY = doneY + 40
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Your Money: %d", Player.totalMoney), 0, infoY, love.graphics.getWidth(), "center")
    love.graphics.printf("Your Keyboard Upgrades:", 0, infoY + 30, love.graphics.getWidth(), "center")
    
    shopState.drawKeyboardLayout(100, infoY + 60)
end

function shopState.keypressed(key)
    if key == "up" then
         currentSelection = currentSelection - 1
         if currentSelection < 1 then
             currentSelection = #offers + 1
         end
    elseif key == "down" then
         currentSelection = currentSelection + 1
         if currentSelection > #offers + 1 then
             currentSelection = 1
         end
    elseif (key == "return") or (key == "kpenter") then
         if currentSelection <= #offers then
              local offer = offers[currentSelection]
              if Player.totalMoney >= offer.cost then
                   Player.totalMoney = Player.totalMoney - offer.cost
                   if not Player.keyboard.upgrades then
                        Player.keyboard.upgrades = {}
                   end
                   Player.keyboard.upgrades[offer.key] = offer.bonus
              end
         else
              local roundState = require("states/roundState")
              StateManager.switch(roundState)
         end
    end
end

function shopState.textinput(text)
end

return shopState
