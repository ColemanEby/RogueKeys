-- states/shopState.lua
-- Refactored shop state with modular keyboard visualization

local StateManager = require("engine/stateManager")
local ResourceManager = require("engine/resourceManager")
local ConfigManager = require("engine/configManager")
local PlayerModel = require("modules/player/playerModel")
local KeyboardView = require("modules/keyboard/keyboardView")
local MenuBuilder = require("modules/ui/menuBuilder")

local ShopState = {
    name = "ShopState"
}

-- Local variables
local player = nil
local keyboardView = nil
local offers = {}
local menu = nil
local shopSection = "upgrades" -- "upgrades" or "keyboards"

-- Initialize the shop state
function ShopState.enter()
    -- Get player instance
    player = player or PlayerModel.load()

    -- Create keyboard view if needed
    if not keyboardView then
        keyboardView = KeyboardView.new(player.keyboard)
    else
        -- Update with current keyboard
        keyboardView.keyboardModel = player.keyboard
    end

    -- Generate offers
    ShopState.generateOffers()

    -- Create shop menu
    ShopState.createShopMenu()
end

-- Generate upgrade offers
function ShopState.generateOffers()
    -- Get progression settings
    local upgradeBaseCost = ConfigManager:get("progression.upgradeBaseCost", 20)
    local upgradeMinBonus = ConfigManager:get("progression.upgradeMinBonus", 0.05)
    local upgradeMaxBonus = ConfigManager:get("progression.upgradeMaxBonus", 0.3)

    -- Generate offers based on player's current keyboard
    offers = player.keyboard:generateUpgradeOffers(
            5, -- Number of offers
            upgradeBaseCost,
            upgradeBaseCost * 3.5,
            upgradeMinBonus,
            upgradeMaxBonus
    )
end

-- Create the shop menu
function ShopState.createShopMenu()
    local availableMoney = player.totalMoney

    -- Create a new menu builder
    menu = MenuBuilder.new("Keyboard Shop", {
        backgroundColor = {0.15, 0.15, 0.2, 0.95},
        titleFontSize = 28
    })

    -- Add section tabs
    menu:addButton("Key Upgrades", function()
        shopSection = "upgrades"
        ShopState.createShopMenu()
    end, shopSection ~= "upgrades")

    menu:addButton("Keyboard Layouts", function()
        shopSection = "keyboards"
        ShopState.createShopMenu()
    end, shopSection ~= "keyboards")

    menu:addSeparator()

    -- Show appropriate section
    if shopSection == "upgrades" then
        -- Display money
        menu:addLabel("Your Money: " .. availableMoney)
        menu:addSeparator()

        -- Add offers
        for i, offer in ipairs(offers) do
            local canAfford = availableMoney >= offer.cost
            local label = string.format("%s Key - %d coins (+%.0f%% bonus)",
                    offer.displayKey, offer.cost, offer.bonus * 100)

            menu:addButton(label, function()
                if player:spendMoney(offer.cost) then
                    player.keyboard:upgradeKey(offer.key, offer.bonus)
                    availableMoney = player.totalMoney

                    -- Regenerate offers and menu after purchase
                    ShopState.generateOffers()
                    ShopState.createShopMenu()

                    -- Save player data
                    player:save()
                end
            end, canAfford)
        end
    else
        -- Display keyboard layouts
        menu:addLabel("Select a Keyboard Layout:")

        -- Get available layouts
        local layouts = ConfigManager:getKeyboardLayouts()
        for layoutId, layoutData in pairs(layouts) do
            local isSelected = (player.selectedKeyboardLayout == layoutId)
            local label = layoutData.name

            if isSelected then
                label = label .. " (Current)"
            end

            menu:addButton(label, function()
                -- Change keyboard
                player:changeKeyboard(layoutId)

                -- Update keyboard view
                keyboardView = KeyboardView.new(player.keyboard)

                -- Refresh menu to show selected keyboard
                ShopState.createShopMenu()

                -- Save player data
                player:save()
            end, not isSelected)
        end
    end

    menu:addSeparator()

    -- Add done button
    menu:addButton("Return to Game", function()
        StateManager.switch("roundState")
    end)

    -- Set menu callbacks
    menu:setCallbacks(
            nil, -- onConfirm (handled by individual buttons)
            function() StateManager.switch("roundState") end, -- onBack
            function() StateManager.switch("roundState") end  -- onClose
    )
end

-- Update the shop state
function ShopState.update(dt)
    -- Update menu animations
    menu:update(dt)

    -- Update keyboard view animations
    keyboardView:update(dt)
end

-- Draw the shop state
function ShopState.draw()
    -- Draw background
    love.graphics.clear(0.1, 0.1, 0.15)

    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Draw the menu
    menu:draw()

    -- Draw the keyboard visualization
    local keyboardY = screenHeight - 300
    keyboardView:draw(20, keyboardY, 0.9)

    -- Display help text
    love.graphics.setColor(0.7, 0.7, 0.7)
    local helpText = "Upgraded keys give bonus points when typing those characters."
    love.graphics.printf(helpText, 20, keyboardY - 30, screenWidth - 40, "left")

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Handle keyboard input
function ShopState.keypressed(key)
    menu:keypressed(key)
end

-- Handle text input
function ShopState.textinput(text)
    -- Not needed for shop state
end

return ShopState