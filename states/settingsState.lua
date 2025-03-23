local StateManager = require("engine/stateManager")
local ResourceManager = require("engine/resourceManager")
local ConfigManager = require("engine/configManager")
local MenuBuilder = require("modules/ui/menuBuilder")

local videoMenu = nil

local SettingsState = {
    name = "SettingsState"
}

local currentTab = "player" -- player, gameplay, layer, video, controls,

function SettingsState.enter()

    print("SettingsState: Entered")

    SettingsState.createVideoMenu()

    -- Create back button menu with proper positioning and styling
    SettingsState.createBackMenu()
end

function SettingsState.update(dt)
    videoMenu:update(dt)
end

function SettingsState.draw()

    -- Draw background
    love.graphics.clear(0.12, 0.12, 0.15)

    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Draw title
    love.graphics.setColor(1, 1, 1)
    local titleFont = ResourceManager:getFont("default", 28)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Settings", 0, 20, screenWidth, "center")

    -- Draw tab buttons
    local tabY = 70
    local tabWidth = 150
    local tabHeight = 30
    local tabSpacing = 10
    local totalTabWidth = tabWidth * 5 + tabSpacing * 2
    local tabStartX = (screenWidth - totalTabWidth) / 2

    -- Helper function to draw a tab
    local function drawTab(text, x, selected)
        -- Draw tab background
        if selected then
            love.graphics.setColor(0.3, 0.5, 0.7, 0.9)
        else
            love.graphics.setColor(0.2, 0.2, 0.25, 0.8)
        end
        love.graphics.rectangle("fill", x, tabY, tabWidth, tabHeight, 5, 5)

        -- Draw tab text
        love.graphics.setColor(1, 1, 1)
        local font = ResourceManager:getFont("default", 16)
        love.graphics.setFont(font)

        local textWidth = font:getWidth(text)
        local textX = x + (tabWidth - textWidth) / 2
        local textY = tabY + (tabHeight - font:getHeight()) / 2
        love.graphics.print(text, textX, textY)
    end

    -- Draw the tabs
    -- player, gameplay, video, audio, controls,
    drawTab("Player", tabStartX, currentTab == "player")
    drawTab("Gameplay", tabStartX + (tabWidth + tabSpacing), currentTab == "gameplay")
    drawTab("Video", tabStartX + (tabWidth + tabSpacing) * 2, currentTab == "video")
    drawTab("Audio", tabStartX + (tabWidth + tabSpacing) * 3, currentTab == "audio")
    drawTab("Controls", tabStartX + (tabWidth + tabSpacing) * 4, currentTab == "controls")

        -- Draw stats panel
    local panelY = tabY + tabHeight + 20
    local panelHeight = screenHeight - panelY - 80

    -- Draw panel background
    love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
    love.graphics.rectangle("fill", 50, panelY, screenWidth - 100, panelHeight, 10, 10)

    -- Draw the stats based on current tab
    if currentTab == "player" then
        SettingsState.drawPlayerSettings(50, panelY, screenWidth - 100, panelHeight)
    elseif currentTab == "gameplay" then
        SettingsState.drawGameplaySettings(50, panelY, screenWidth - 100, panelHeight)
    elseif currentTab == "video" then
        videoMenu:draw()
    end

    -- Draw back menu at the BOTTOM of the screen (fixed positioning)
    -- Calculate position explicitly instead of letting menu center itself
    local menuX = (screenWidth - 200) / 2  -- 200 is the menu width defined above
    local menuY = screenHeight - 70        -- Position from bottom

    -- Save the current transform
    love.graphics.push()

    -- Set absolute position for the menu
    love.graphics.translate(menuX, menuY)

    -- Draw the menu
    if backMenu then
        backMenu:draw()
    end

    -- Restore transform
    love.graphics.pop()

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function SettingsState.keypressed(key)

    if key == "left" then
        if currentTab == "player" then
            currentTab = "controls"
        elseif currentTab == "gameplay" then
            currentTab = "player"
        elseif currentTab == "video" then
            currentTab = "gameplay"
        elseif currentTab == "audio" then
            currentTab = "video"
        elseif currentTab == "controls" then
            currentTab = "audio"
        end
    elseif key == "right" then
        if currentTab == "player" then
            currentTab = "gameplay"
        elseif currentTab == "gameplay" then
            currentTab = "video"
        elseif currentTab == "video" then
            currentTab = "audio"
        elseif currentTab == "audio" then
            currentTab = "controls"
        elseif currentTab == "controls" then
            currentTab = "player"
        end
    elseif key == "escape" or key == "backspace" or key == "m" then
        StateManager.switch("menuState")
    end
end

-- Create back menu with proper positioning
function SettingsState.createBackMenu()
    backMenu = MenuBuilder.new("", {
        backgroundColor = {0.1, 0.1, 0.2, 0.8},
        width = 200,
        titleFontSize = 18
    })

    backMenu:addButton("Back to Main Menu", function()
        StateManager.switch("menuState")
    end)

    backMenu:setCallbacks(
            nil, -- onConfirm
            function() StateManager.switch("menuState") end, -- onBack
            function() StateManager.switch("menuState") end  -- onClose
    )
end

function SettingsState.drawPlayerSettings(x, y, width, height)
    return
end

function SettingsState.drawGameplaySettings(x, y, width, height)

    -- Set font
    local font = ResourceManager:getFont("default", 18)
    love.graphics.setFont(font)

    local difficulties = ConfigManager:getDifficulties()

    local settings = {
        { label = "Difficulty", value = difficulties.current, values = pairs(difficulties.levels)}
    }

    -- Draw stats in a grid layout
    local padding = 20
    local itemsPerRow = 2
    local itemWidth = (width - padding * (itemsPerRow + 1)) / itemsPerRow
    local itemHeight = 40

    local startX = x + padding
    local startY = y + padding

    -- Adjust startY if debug mode is active
    if _G and _G.DEBUG_MODE then
        startY = startY + 30
    end

    for i, item in ipairs(settings) do
        local col = (i - 1) % itemsPerRow
        local row = math.floor((i - 1) / itemsPerRow)

        local itemX = startX + col * (itemWidth + padding)
        local itemY = startY + row * (itemHeight + padding)

        -- Draw box background
        love.graphics.setColor(0.2, 0.2, 0.25, 0.8)
        love.graphics.rectangle("fill", itemX, itemY, itemWidth, itemHeight, 5, 5)

        -- Draw label and value
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(item.label .. ":", itemX + 10, itemY + (itemHeight - font:getHeight()) / 2)

        love.graphics.setColor(1, 1, 1)
        local valueText = tostring(item.value)
        local valueX = itemX + itemWidth - font:getWidth(valueText) - 10
        love.graphics.print(valueText, valueX, itemY + (itemHeight - font:getHeight()) / 2)
    end
end

function SettingsState.createVideoMenu()
    videoMenu = MenuBuilder.new("Video Settings", {
        backgroundColor = {0.15, 0.15, 0.2, 0.95},
        titleFontSize = 28
    })

    videoMenu:addInput("Width", function()
        -- Update width
    end, true)

    local game = ConfigManager:getGame()

    local settings = {
        { label = "Width", value = game.width },
        { label = "Height", value = game.height },
        { label = "Fullscreen", value = game.fullscreen },
        { label = "V-Sync", value = game.vsync },
        { label = "Show FPS", value = game.showFPS }
    }
end

function SettingsState.drawVideoSettings(x, y, width, height)



    -- Set font
    local font = ResourceManager:getFont("default", 18)
    love.graphics.setFont(font)



    -- Draw stats in a grid layout
    local padding = 20
    local itemsPerRow = 2
    local itemWidth = (width - padding * (itemsPerRow + 1)) / itemsPerRow
    local itemHeight = 40

    local startX = x + padding
    local startY = y + padding

    -- Adjust startY if debug mode is active
    if _G and _G.DEBUG_MODE then
        startY = startY + 30
    end

    for i, item in ipairs(settings) do
        local col = (i - 1) % itemsPerRow
        local row = math.floor((i - 1) / itemsPerRow)

        local itemX = startX + col * (itemWidth + padding)
        local itemY = startY + row * (itemHeight + padding)

        -- Draw box background
        love.graphics.setColor(0.2, 0.2, 0.25, 0.8)
        love.graphics.rectangle("fill", itemX, itemY, itemWidth, itemHeight, 5, 5)

        -- Draw label and value
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(item.label .. ":", itemX + 10, itemY + (itemHeight - font:getHeight()) / 2)

        love.graphics.setColor(1, 1, 1)
        local valueText = tostring(item.value)
        local valueX = itemX + itemWidth - font:getWidth(valueText) - 10
        love.graphics.print(valueText, valueX, itemY + (itemHeight - font:getHeight()) / 2)
    end
end

return SettingsState