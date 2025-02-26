-- states/statsState.lua
-- Improved stats state with visualizations and fixed menu positioning

local StateManager = require("engine/stateManager")
local ResourceManager = require("engine/resourceManager")
local PlayerModel = require("modules/player/playerModel")
local MenuBuilder = require("modules/ui/menuBuilder")

local StatsState = {
    name = "StatsState"
}

-- Local variables
local player = nil
local backMenu = nil
local currentTab = "overall"  -- "overall", "typing", "economy"

-- Initialize the stats state
function StatsState.enter()
    -- Get player data
    player = player or PlayerModel.load()

    -- Create back button menu with proper positioning and styling
    StatsState.createBackMenu()
end

-- Create back menu with proper positioning
function StatsState.createBackMenu()
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

-- Update the stats state
function StatsState.update(dt)
    -- Update menu animations
    if backMenu then
        backMenu:update(dt)
    end
end

-- Draw the stats state
function StatsState.draw()
    -- Draw background
    love.graphics.clear(0.12, 0.12, 0.15)

    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Draw title
    love.graphics.setColor(1, 1, 1)
    local titleFont = ResourceManager:getFont("default", 28)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Statistics", 0, 20, screenWidth, "center")

    -- Draw tab buttons
    local tabY = 70
    local tabWidth = 150
    local tabHeight = 30
    local tabSpacing = 10
    local totalTabWidth = tabWidth * 3 + tabSpacing * 2
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
    drawTab("Overall", tabStartX, currentTab == "overall")
    drawTab("Typing", tabStartX + tabWidth + tabSpacing, currentTab == "typing")
    drawTab("Economy", tabStartX + (tabWidth + tabSpacing) * 2, currentTab == "economy")

    -- Draw stats panel
    local panelY = tabY + tabHeight + 20
    local panelHeight = screenHeight - panelY - 80

    -- Draw panel background
    love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
    love.graphics.rectangle("fill", 50, panelY, screenWidth - 100, panelHeight, 10, 10)

    -- Draw the stats based on current tab
    if currentTab == "overall" then
        StatsState.drawOverallStats(50, panelY, screenWidth - 100, panelHeight)
    elseif currentTab == "typing" then
        StatsState.drawTypingStats(50, panelY, screenWidth - 100, panelHeight)
    elseif currentTab == "economy" then
        StatsState.drawEconomyStats(50, panelY, screenWidth - 100, panelHeight)
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

-- Draw overall stats
function StatsState.drawOverallStats(x, y, width, height)
    local stats = player:getStats()

    -- Set font
    local font = ResourceManager:getFont("default", 18)
    love.graphics.setFont(font)

    -- Stats to display
    local statItems = {
        { label = "Total Play Time", value = formatTime(stats.totalPlayTime) },
        { label = "Total Sessions", value = stats.totalSessions },
        { label = "Current Round", value = player.currentRound },
        { label = "Max Round Reached", value = player.maxRoundReached },
        { label = "Perfect Rounds", value = stats.perfectRounds },
        { label = "Current Money", value = player.totalMoney },
        { label = "Current Keyboard", value = player.keyboard.name },
        { label = "Keyboard Upgrades", value = countUpgrades(player.keyboard.upgrades) }
    }

    -- Draw stats in a grid layout
    local padding = 20
    local itemsPerRow = 2
    local itemWidth = (width - padding * (itemsPerRow + 1)) / itemsPerRow
    local itemHeight = 40

    local startX = x + padding
    local startY = y + padding

    for i, item in ipairs(statItems) do
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

-- Draw typing stats
function StatsState.drawTypingStats(x, y, width, height)
    local stats = player:getStats()

    -- Set font
    local font = ResourceManager:getFont("default", 18)
    love.graphics.setFont(font)

    -- Stats to display
    local statItems = {
        { label = "Total Keystrokes", value = stats.totalKeystrokes },
        { label = "Total Correct", value = stats.totalCorrect },
        { label = "Total Mistakes", value = stats.totalMistakes },
        { label = "Accuracy", value = string.format("%.1f%%", getAccuracy(stats)) },
        { label = "Best APM", value = string.format("%.1f", stats.bestAPM) },
        { label = "Best WPM", value = string.format("%.1f", stats.bestWPM) },
        { label = "Best Accuracy", value = string.format("%.1f%%", stats.bestAccuracy) },
        { label = "Best Streak", value = stats.bestStreak },
        { label = "Error-free Rounds", value = stats.roundsWithoutError }
    }

    -- Draw stats in a grid layout
    local padding = 20
    local itemsPerRow = 2
    local itemWidth = (width - padding * (itemsPerRow + 1)) / itemsPerRow
    local itemHeight = 40

    local startX = x + padding
    local startY = y + padding

    for i, item in ipairs(statItems) do
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

    -- Draw a mini graph showing accuracy over time (conceptual - would need real data)
    local graphX = startX
    local graphY = startY + (math.ceil(#statItems / itemsPerRow) + 0.5) * (itemHeight + padding)
    local graphWidth = width - padding * 2
    local graphHeight = 120

    -- Draw graph background
    love.graphics.setColor(0.2, 0.2, 0.25, 0.8)
    love.graphics.rectangle("fill", graphX, graphY, graphWidth, graphHeight, 5, 5)

    -- Draw graph title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Typing Performance", graphX + 10, graphY + 10)

    -- Draw accuracy bars (simplified example)
    local barCount = 10
    local barWidth = (graphWidth - 40) / barCount
    local barMaxHeight = graphHeight - 50
    local barY = graphY + graphHeight - 20

    for i = 1, barCount do
        -- Simulate some data (in a real implementation, use actual session history)
        local value = 50 + math.sin(i * 0.7) * 20 + math.random() * 10
        local barHeight = (value / 100) * barMaxHeight

        -- Draw bar
        local barX = graphX + 20 + (i - 1) * barWidth

        -- Color gradient based on value
        local r = 1 - (value / 100)
        local g = value / 100
        love.graphics.setColor(r, g, 0.2)

        love.graphics.rectangle("fill", barX, barY - barHeight, barWidth - 5, barHeight, 2, 2)
    end

    -- Draw axis labels
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Recent Sessions", graphX + graphWidth / 2 - 40, barY + 5)
    love.graphics.print("100%", graphX + 5, graphY + 20)
    love.graphics.print("0%", graphX + 5, barY - 5)
end

-- Draw economy stats
function StatsState.drawEconomyStats(x, y, width, height)
    local stats = player:getStats()

    -- Set font
    local font = ResourceManager:getFont("default", 18)
    love.graphics.setFont(font)

    -- Stats to display
    local statItems = {
        { label = "Total Money Earned", value = stats.moneyEarned },
        { label = "Total Money Spent", value = stats.moneySpent },
        { label = "Current Balance", value = player.totalMoney },
        { label = "Keyboard Upgrades", value = countUpgrades(player.keyboard.upgrades) },
        { label = "Savings Rate", value = string.format("%.1f%%", getSavingsRate(stats)) }
    }

    -- Draw stats in a grid layout
    local padding = 20
    local itemsPerRow = 2
    local itemWidth = (width - padding * (itemsPerRow + 1)) / itemsPerRow
    local itemHeight = 40

    local startX = x + padding
    local startY = y + padding

    for i, item in ipairs(statItems) do
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

    -- Draw a pie chart showing money allocation
    local chartX = startX + (width - padding * 2) / 2
    local chartY = startY + (math.ceil(#statItems / itemsPerRow) + 1) * (itemHeight + padding)
    local chartRadius = 80

    -- Draw chart title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Money Allocation", startX, chartY - 40, width - padding * 2, "center")

    -- Draw pie segments
    local spent = stats.moneySpent
    local current = player.totalMoney
    local total = spent + current

    if total > 0 then
        -- Calculate angles
        local spentAngle = (spent / total) * math.pi * 2
        local currentAngle = (current / total) * math.pi * 2

        -- Draw spent segment
        love.graphics.setColor(0.8, 0.3, 0.3)
        love.graphics.arc("fill", chartX, chartY, chartRadius, 0, spentAngle)

        -- Draw current balance segment
        love.graphics.setColor(0.3, 0.8, 0.3)
        love.graphics.arc("fill", chartX, chartY, chartRadius, spentAngle, math.pi * 2)
    else
        -- Draw empty chart
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.circle("fill", chartX, chartY, chartRadius)
    end

    -- Draw legend
    local legendX = chartX + chartRadius + 20
    local legendY = chartY - 30

    love.graphics.setColor(0.8, 0.3, 0.3)
    love.graphics.rectangle("fill", legendX, legendY, 20, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Spent", legendX + 30, legendY)

    love.graphics.setColor(0.3, 0.8, 0.3)
    love.graphics.rectangle("fill", legendX, legendY + 30, 20, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Balance", legendX + 30, legendY + 30)
end

-- Handle keyboard input
function StatsState.keypressed(key)
    if key == "left" then
        if currentTab == "typing" then
            currentTab = "overall"
        elseif currentTab == "economy" then
            currentTab = "typing"
        end
    elseif key == "right" then
        if currentTab == "overall" then
            currentTab = "typing"
        elseif currentTab == "typing" then
            currentTab = "economy"
        end
    elseif key == "escape" or key == "backspace" or key == "m" then
        StateManager.switch("menuState")
    end

    -- Forward to back menu
    if backMenu then
        backMenu:keypressed(key)
    end
end

-- Handle text input
function StatsState.textinput(text)
    -- Not needed for stats state
end

-- Handle mouse click for tab selection
function StatsState.mousepressed(x, y, button)
    if button == 1 then
        -- Check if a tab was clicked
        local tabY = 70
        local tabWidth = 150
        local tabHeight = 30
        local tabSpacing = 10
        local totalTabWidth = tabWidth * 3 + tabSpacing * 2
        local screenWidth = love.graphics.getWidth()
        local tabStartX = (screenWidth - totalTabWidth) / 2

        if y >= tabY and y <= tabY + tabHeight then
            -- Overall tab
            if x >= tabStartX and x <= tabStartX + tabWidth then
                currentTab = "overall"
                -- Typing tab
            elseif x >= tabStartX + tabWidth + tabSpacing and
                    x <= tabStartX + tabWidth * 2 + tabSpacing then
                currentTab = "typing"
                -- Economy tab
            elseif x >= tabStartX + (tabWidth + tabSpacing) * 2 and
                    x <= tabStartX + (tabWidth + tabSpacing) * 2 + tabWidth then
                currentTab = "economy"
            end
        end

        -- Check if back menu was clicked
        local screenHeight = love.graphics.getHeight()
        local menuX = (screenWidth - 200) / 2
        local menuY = screenHeight - 70

        -- Simple check if click is in menu area
        if x >= menuX and x <= menuX + 200 and y >= menuY and y <= menuY + 40 then
            StateManager.switch("menuState")
        end
    end
end

-- Helper: Format time in seconds to a readable string
function formatTime(seconds)
    if not seconds or seconds < 0 then
        return "0m 0s"
    end

    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)

    if minutes >= 60 then
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60
        return string.format("%dh %dm %ds", hours, minutes, remainingSeconds)
    else
        return string.format("%dm %ds", minutes, remainingSeconds)
    end
end

-- Helper: Count the number of keyboard upgrades
function countUpgrades(upgrades)
    if not upgrades then return 0 end

    local count = 0
    for _, _ in pairs(upgrades) do
        count = count + 1
    end

    return count
end

-- Helper: Calculate overall accuracy
function getAccuracy(stats)
    local total = stats.totalCorrect + stats.totalMistakes
    if total <= 0 then return 0 end

    return (stats.totalCorrect / total) * 100
end

-- Helper: Calculate savings rate
function getSavingsRate(stats)
    local totalEarned = stats.moneyEarned
    if totalEarned <= 0 then return 0 end

    local savingsRate = ((totalEarned - stats.moneySpent) / totalEarned) * 100
    return math.max(0, savingsRate)
end

return StatsState