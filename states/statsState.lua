-- states/statsState.lua
-- Improved stats state with visualizations and fixed menu positioning

local StateManager = require("engine/stateManager")
local ResourceManager = require("engine/resourceManager")
local PlayerModel = require("modules/player/playerModel")
local MenuBuilder = require("modules/ui/menuBuilder")
-- Add this to the beginning of the file after the includes
local StatVerifier = require("modules/util/statVerifier")

local StatsState = {
    name = "StatsState"
}

-- Update the getAccuracy helper to handle missing or zero values correctly
function getAccuracy(stats)
    local totalCorrect = stats.totalCorrect or 0
    local totalMistakes = stats.totalMistakes or 0
    local total = totalCorrect + totalMistakes
    
    if total <= 0 then return 0 end
    return (totalCorrect / total) * 100
end

-- Update the getSavingsRate helper to handle missing or zero values correctly
function getSavingsRate(stats)
    local totalEarned = stats.moneyEarned or 0
    if totalEarned <= 0 then return 0 end

    local moneySpent = stats.moneySpent or 0
    local savingsRate = ((totalEarned - moneySpent) / totalEarned) * 100
    return math.max(0, savingsRate)
end

-- Update the countUpgrades function to be more robust
function countUpgrades(upgrades)
    if not upgrades then return 0 end

    local count = 0
    for _, _ in pairs(upgrades) do
        count = count + 1
    end

    return count
end


-- Add a helper function to format time
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



-- Safe version of getAccuracy function that can handle nil values
local function safeGetAccuracy(stats)
    if not stats then return 0 end
    
    local totalCorrect = stats.totalCorrect or 0
    local totalMistakes = stats.totalMistakes or 0
    local total = totalCorrect + totalMistakes
    
    if total <= 0 then return 0 end
    return (totalCorrect / total) * 100
end

-- Safe version of countUpgrades function that can handle nil values
local function safeCountUpgrades(upgrades)
    if not upgrades then return 0 end

    local count = 0
    for _, _ in pairs(upgrades) do
        count = count + 1
    end

    return count
end


-- Local variables
local player = nil
local backMenu = nil
local currentTab = "overall"  -- "overall", "typing", "economy"

-- Initialize the stats state
function StatsState.enter()
    print("StatsState: Entered")
    
    -- Try to load player data in a protected call to handle errors
    local success, result = pcall(function()
        return PlayerModel.load()
    end)
    
    if success and result then
        player = result
        print("StatsState: Successfully loaded player data")
    else
        -- Create a new player if loading fails
        print("StatsState: Failed to load player data, creating new player")
        player = PlayerModel.new()
    end

    -- Verify stats are loaded correctly (only in debug mode)
    if _G and _G.DEBUG_MODE then
        print("StatsState: Verifying stat loading")
        pcall(function() 
            StatVerifier.verifySavedStats() 
        end)
    end

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

-- Update the draw function to handle nil player
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

    -- If player is nil, display an error message and return
    if not player then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("Error: Unable to load player data", 0, screenHeight / 2, screenWidth, "center")
        
        -- Draw back menu to allow user to return
        if backMenu then
            -- Calculate position for the menu
            local menuX = (screenWidth - 200) / 2  -- 200 is the menu width defined above
            local menuY = screenHeight - 70        -- Position from bottom

            -- Save the current transform
            love.graphics.push()
            love.graphics.translate(menuX, menuY)
            backMenu:draw()
            love.graphics.pop()
        end
        
        return
    end

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


-- Update drawOverallStats to handle nil player
function StatsState.drawOverallStats(x, y, width, height)
    if not player then return end
    
    local stats = player:getStats() or {}

    -- Set font
    local font = ResourceManager:getFont("default", 18)
    love.graphics.setFont(font)
    
    -- Add debug info section to verify stats are loaded
    if _G and _G.DEBUG_MODE then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("DEBUG INFO - Stats Loaded", x + 10, y + 10, width - 20, "center")
    end

    -- Stats to display
    local statItems = {
        { label = "Total Play Time", value = formatTime(stats.totalPlayTime or 0) },
        { label = "Total Sessions", value = stats.totalSessions or 0 },
        { label = "Total Keystrokes", value = stats.totalKeystrokes or 0 },
        { label = "Current Round", value = player.currentRound or 1 },
        { label = "Max Round Reached", value = player.maxRoundReached or 1 },
        { label = "Perfect Rounds", value = stats.perfectRounds or 0 },
        { label = "Current Money", value = player.totalMoney or 0 },
        { label = "Current Keyboard", value = (player.keyboard and player.keyboard.name) or "QWERTY" },
        { label = "Keyboard Upgrades", value = safeCountUpgrades(player.keyboard and player.keyboard.upgrades) }
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
    
    -- Add a verification button in debug mode
    if _G and _G.DEBUG_MODE then
        local buttonY = startY + (math.ceil(#statItems / itemsPerRow) + 1) * (itemHeight + padding)
        love.graphics.setColor(0.3, 0.6, 0.3, 0.8)
        love.graphics.rectangle("fill", startX, buttonY, width - padding * 2, itemHeight, 5, 5)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Run Stats Verification", startX, buttonY + (itemHeight - font:getHeight()) / 2, 
                            width - padding * 2, "center")
    end
end

-- Update the drawing of typing stats to better show troubleshooting info
function StatsState.drawTypingStats(x, y, width, height)
    local stats = player:getStats()

    -- Set font
    local font = ResourceManager:getFont("default", 18)
    love.graphics.setFont(font)

    -- Add debug header
    if _G.DEBUG_MODE then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("DEBUG INFO - Typing Stats", x + 10, y + 10, width - 20, "center")
    end

    -- Stats to display
    local statItems = {
        { label = "Total Keystrokes", value = stats.totalKeystrokes or 0 },
        { label = "Total Correct", value = stats.totalCorrect or 0 },
        { label = "Total Mistakes", value = stats.totalMistakes or 0 },
        { label = "Accuracy", value = string.format("%.1f%%", getAccuracy(stats)) },
        { label = "Best APM", value = string.format("%.1f", stats.bestAPM or 0) },
        { label = "Best WPM", value = string.format("%.1f", stats.bestWPM or 0) },
        { label = "Best Accuracy", value = string.format("%.1f%%", stats.bestAccuracy or 0) },
        { label = "Best Streak", value = stats.bestStreak or 0 },
        { label = "Error-free Rounds", value = stats.roundsWithoutError or 0 }
    }

    -- Draw stats in a grid layout
    local padding = 20
    local itemsPerRow = 2
    local itemWidth = (width - padding * (itemsPerRow + 1)) / itemsPerRow
    local itemHeight = 40

    local startX = x + padding
    local startY = y + padding
    
    -- Adjust startY if debug mode is active
    if _G.DEBUG_MODE then
        startY = startY + 30
    end

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
    -- =============================================================================================================
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

    -- In debug mode, also add actual accuracy value
    if _G.DEBUG_MODE then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Actual accuracy: " .. string.format("%.1f%%", getAccuracy(stats)), 
                           graphX + 10, graphY + 30)
    end

    local matchHistory = player:getMatchHistory()
    local matchCount = #matchHistory
    -- print("Match history count from player:getMatchHistory() " .. matchCount)
    
    for i = 1, barCount do
        -- Calculate the reversed index position
        local reversedPosition = barCount - (i - 1)
        
        if i <= matchCount then
            -- using 1 so that there is a bar but it barely shows
            local matchIndex = i -- Reverse the match index too
            local value = matchHistory[matchIndex].accuracy
            local barHeight = (value / 100) * barMaxHeight
    
            -- Draw bar (with reversedPosition instead of i)
            local barX = graphX + 20 + (reversedPosition - 1) * barWidth
    
            -- Color gradient based on value
            local r = 1 - (value / 100)
            local g = value / 100
            love.graphics.setColor(r, g, 0.2)
    
            love.graphics.rectangle("fill", barX, barY - barHeight, barWidth - 5, barHeight, 2, 2)
        else
            -- using 1 so that there is a bar but it barely shows
            local value = 1
            local barHeight = (value / 100) * barMaxHeight
    
            -- Draw bar (with reversedPosition instead of i)
            local barX = graphX + 20 + (reversedPosition - 1) * barWidth
    
            -- Color gradient based on value
            local r = 1 - (value / 100)
            local g = value / 100
            love.graphics.setColor(r, g, 0.2)
    
            love.graphics.rectangle("fill", barX, barY - barHeight, barWidth - 5, barHeight, 2, 2)
        end
    end

    -- Draw axis labels
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Recent Sessions", graphX + graphWidth / 2 - 40, barY + 5)
    love.graphics.print("100%", graphX + 5, graphY + 20)
    love.graphics.print("0%", graphX + 5, barY - 5)
end
-- =====================================================================================================================
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

-- Add this to the mousepressed function to handle verification button
local originalMousepressed = StatsState.mousepressed
function StatsState.mousepressed(x, y, button)
    -- Call the original function first
    if originalMousepressed then
        originalMousepressed(x, y, button)
    end
    
    -- Add verification button handling in debug mode
    if _G.DEBUG_MODE and button == 1 then
        local screenWidth = love.graphics.getWidth()
        local padding = 20
        
        if currentTab == "overall" then
            local panelY = 70 + 30 + 20  -- tabY + tabHeight + padding
            local statItems = {
                { label = "Total Play Time" }, { label = "Total Sessions" },
                { label = "Total Keystrokes" }, { label = "Current Round" },
                { label = "Max Round Reached" }, { label = "Perfect Rounds" },
                { label = "Current Money" }, { label = "Current Keyboard" },
                { label = "Keyboard Upgrades" }
            }
            
            local startX = 50 + padding
            local startY = panelY + padding
            
            -- Adjust startY if debug mode is active
            if _G.DEBUG_MODE then
                startY = startY + 30
            end
            
            local itemHeight = 40
            local itemsPerRow = 2
            
            -- Check if the verification button was clicked
            local buttonY = startY + (math.ceil(#statItems / itemsPerRow) + 1) * (itemHeight + padding)
            local buttonWidth = screenWidth - 100 - padding * 2
            
            if x >= startX and x <= startX + buttonWidth and 
               y >= buttonY and y <= buttonY + itemHeight then
                print("StatsState: Running stats verification")
                local result = StatVerifier.runIntegrationTest()
                print("StatsState: Verification complete. Result: " .. (result and "PASSED" or "FAILED"))
                
                -- Reload player to reflect any new data
                player = PlayerModel.load()
            end
        end
    end
end

return StatsState