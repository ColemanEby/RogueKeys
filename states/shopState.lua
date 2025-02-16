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
         local cost = math.random(20, 70)
         local bonus = math.random(5, 30) / 100  -- bonus between 0.05 and 0.30
         table.insert(offers, { key = keyChar, cost = cost, bonus = bonus })
    end
end

function shopState.enter()
    currentSelection = 1
    shopState.generateOffers()
end

----------------------------------------------------------------
-- Helper Functions for Font Scaling
----------------------------------------------------------------
local function getShopFont()
    local windowWidth = love.graphics.getWidth()
    local baseFontSize = math.floor(windowWidth / 30) -- main shop title font size
    return love.graphics.newFont(baseFontSize)
end

-- Smaller font for the shop offers.
local function getOfferFont()
    local windowWidth = love.graphics.getWidth()
    local size = math.floor(windowWidth / 40) -- smaller than shop title font
    return love.graphics.newFont(size)
end

-- Smaller font for the keyboard layout.
local function getKeyboardFont()
    local windowWidth = love.graphics.getWidth()
    local size = math.floor(windowWidth / 40) -- adjust as needed so keys fit
    return love.graphics.newFont(size)
end

----------------------------------------------------------------
-- Helper: Draw text inside a box with padding.
local function drawTextBox(text, x, y, font)
    love.graphics.setFont(font)
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    local padding = 5
    love.graphics.rectangle("line", x - padding, y - padding, textWidth + 2 * padding, textHeight + 2 * padding)
    love.graphics.print(text, x, y)
end

----------------------------------------------------------------
-- Define a keyboard layout as a table of rows.
-- Each row is a table of keys. Each key is a table with:
--   key: the label,
--   w: width multiplier (1 is standard; larger values make the key wider).
local keyboardLayout = {
    { { key = "Q", w = 1 }, { key = "W", w = 1 }, { key = "E", w = 1 }, { key = "R", w = 1 },
      { key = "T", w = 1 }, { key = "Y", w = 1 }, { key = "U", w = 1 }, { key = "I", w = 1 },
      { key = "O", w = 1 }, { key = "P", w = 1 } },
    { { key = "A", w = 1 }, { key = "S", w = 1 }, { key = "D", w = 1 }, { key = "F", w = 1 },
      { key = "G", w = 1 }, { key = "H", w = 1 }, { key = "J", w = 1 }, { key = "K", w = 1 },
      { key = "L", w = 1 } },
    { { key = "Z", w = 1 }, { key = "X", w = 1 }, { key = "C", w = 1 }, { key = "V", w = 1 },
      { key = "B", w = 1 }, { key = "N", w = 1 }, { key = "M", w = 1 } },
    { { key = ",", w = 1 }, { key = ".", w = 1 }, { key = "?", w = 1 }, { key = "!", w = 1 },
       },
    { { key = "Space", w = 3 }}
}

----------------------------------------------------------------
-- Draw the keyboard layout, centered and enclosed in a box.
function shopState.drawKeyboardLayout(y)
    local kFont = getKeyboardFont()
    love.graphics.setFont(kFont)
    local padding = 5
    -- Base key width: measure a typical key.
    local baseKeyWidth = kFont:getWidth("W") + 10
    local keyHeight = kFont:getHeight() + 10

    -- Compute maximum row width.
    local maxRowWidth = 0
    for _, row in ipairs(keyboardLayout) do
        local rowWidth = 0
        for _, keyData in ipairs(row) do
            local widthMultiplier = keyData.w or 1
            rowWidth = rowWidth + (baseKeyWidth * widthMultiplier) + padding
        end
        rowWidth = rowWidth - padding -- remove extra padding after last key.
        if rowWidth > maxRowWidth then
            maxRowWidth = rowWidth
        end
    end

    local windowWidth = love.graphics.getWidth()
    local startX = (windowWidth - maxRowWidth) / 2

    -- Compute total layout height.
    local totalRows = #keyboardLayout
    local totalHeight = totalRows * keyHeight + (totalRows - 1) * padding

    -- Draw a box around the keyboard layout.
    local boxPadding = 10
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", startX - boxPadding, y - boxPadding, maxRowWidth + 2 * boxPadding, totalHeight + 2 * boxPadding)

    -- Now draw each key.
    local currentY = y
    for r, row in ipairs(keyboardLayout) do
         local offsetX = startX
         for i, keyData in ipairs(row) do
             local keyLabel = keyData.key
             local widthMultiplier = keyData.w or 1
             local keyWidth = baseKeyWidth * widthMultiplier
             -- If this key (lowercase) is upgraded, fill with light green.
             if Player.keyboard.upgrades and Player.keyboard.upgrades[keyLabel:lower()] then
                 love.graphics.setColor(0.5, 1, 0.5)
                 love.graphics.rectangle("fill", offsetX, currentY, keyWidth, keyHeight)
             end
             love.graphics.setColor(1, 1, 1)
             love.graphics.rectangle("line", offsetX, currentY, keyWidth, keyHeight)
             -- Center the key label.
             local textWidth = kFont:getWidth(keyLabel)
             local textX = offsetX + (keyWidth - textWidth) / 2
             local textY = currentY + (keyHeight - kFont:getHeight()) / 2
             love.graphics.print(keyLabel, textX, textY)
             offsetX = offsetX + keyWidth + padding
         end
         currentY = currentY + keyHeight + padding
    end
end

----------------------------------------------------------------
-- ShopState.draw: Draw the shop screen.
function shopState.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    
    -- Draw title using shop font.
    local shopFont = getShopFont()
    love.graphics.setFont(shopFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Shop - Upgrade Specific Keys", 0, 20, love.graphics.getWidth(), "center")
    
    -- Draw offers using a smaller font.
    local offerFont = getOfferFont()
    love.graphics.setFont(offerFont)
    local startY = 60
    for i, offer in ipairs(offers) do
         local text = string.format("Key '%s' - Cost: %d, Bonus: +%.2f", offer.key, offer.cost, offer.bonus)
         local textY = startY + (i - 1) * (offerFont:getHeight() + 20)
         if i == currentSelection then
              love.graphics.setColor(1, 1, 0)
         else
              love.graphics.setColor(1, 1, 1)
         end
         drawTextBox(text, 0.1 * love.graphics.getWidth(), textY, offerFont)
    end
    
    -- Draw the "Done" option.
    local doneY = startY + (#offers) * (offerFont:getHeight() + 20) + 20
    if currentSelection == #offers + 1 then
         love.graphics.setColor(1, 1, 0)
    else
         love.graphics.setColor(1, 1, 1)
    end
    drawTextBox("Done", 0.1 * love.graphics.getWidth(), doneY, offerFont)
    
    -- Display player money info.
    local infoY = doneY + 60
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Your Money: %d", Player.totalMoney), 0, infoY, love.graphics.getWidth(), "center")
    love.graphics.printf("Your Keyboard Upgrades:", 0, infoY + 30, love.graphics.getWidth(), "center")
    
    -- Draw the keyboard layout below the info, ensuring it is fully visible.
    shopState.drawKeyboardLayout(infoY + 60)
end

----------------------------------------------------------------
-- ShopState.keypressed: Handle navigation and purchasing.
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
                   -- Save the upgrade using the key in lowercase.
                   Player.keyboard.upgrades[offer.key:lower()] = offer.bonus
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
