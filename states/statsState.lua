-- states/statsState.lua
-- Stats screen: Overall / Typing / Economy tabs, an accuracy bar graph and a
-- WPM-over-time line graph. Reads Context.player() so it always reflects the
-- same in-memory player as every other state (never re-reads disk itself).

local StateManager = require("engine/stateManager")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local Context = require("modules/game/context")

local StatsState = {
    name = "StatsState",
    logical = true,
}

-- ---------------------------------------------------------------------------
-- Pure helpers. Exposed via StatsState._internal so tests/test_stats_graph.lua
-- can exercise the graph math and stat accessors without a graphics context.
-- ---------------------------------------------------------------------------

local function getAccuracy(stats)
    stats = stats or {}
    local correct = stats.totalCorrect or 0
    local mistakes = stats.totalMistakes or 0
    local total = correct + mistakes
    if total <= 0 then return 0 end
    return (correct / total) * 100
end

local function getSavingsRate(stats)
    stats = stats or {}
    local earned = stats.moneyEarned or 0
    if earned <= 0 then return 0 end
    local spent = stats.moneySpent or 0
    return math.max(0, ((earned - spent) / earned) * 100)
end

local function countUpgrades(upgrades)
    if type(upgrades) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(upgrades) do count = count + 1 end
    return count
end

local function formatTime(seconds)
    if type(seconds) ~= "number" or seconds < 0 then return "0m 0s" end
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    if minutes >= 60 then
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60
        return string.format("%dh %dm %ds", hours, minutes, remainingSeconds)
    end
    return string.format("%dm %ds", minutes, remainingSeconds)
end

-- matchHistory is stored newest-first (index 1 = most recent match -- see
-- PlayerModel:addMatchToHistory, which shifts everything forward and inserts
-- the new match at [1]). This maps a bar/point's left-to-right screen
-- position (1..displayCount) onto that array so the oldest of the displayed
-- matches lands on the left and the newest on the right.
local function barMatchIndex(displayPosition, displayCount)
    return displayCount - displayPosition + 1
end

-- y-axis range for a line graph. Safe for zero, one, or all-equal values --
-- callers divide by (hi - lo), so this must never return hi == lo.
local function lineGraphRange(values)
    if not values or #values == 0 then return 0, 1 end
    local lo, hi = values[1], values[1]
    for _, v in ipairs(values) do
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    if hi == lo then
        hi = lo + 1
        lo = math.max(0, lo - 1)
    end
    return lo, hi
end

-- Oldest-to-newest numeric series for `key`, tolerant of malformed/missing
-- entries (older saves, or a history array with holes).
local function matchSeries(matchHistory, key)
    local n = #matchHistory
    local series = {}
    for i = 1, n do
        local match = matchHistory[barMatchIndex(i, n)]
        series[i] = (type(match) == "table" and type(match[key]) == "number") and match[key] or 0
    end
    return series
end

StatsState._internal = {
    getAccuracy = getAccuracy,
    getSavingsRate = getSavingsRate,
    countUpgrades = countUpgrades,
    formatTime = formatTime,
    barMatchIndex = barMatchIndex,
    lineGraphRange = lineGraphRange,
    matchSeries = matchSeries,
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local player = nil
local currentTab = "overall" -- "overall" | "typing" | "economy"
local TABS = { "overall", "typing", "economy" }
local TAB_LABELS = { overall = "Overall", typing = "Typing", economy = "Economy" }
local MAX_BARS = 20

-- Rebuilt every draw so mousepressed can hit-test without redoing layout math.
local layout = { tabs = {}, back = nil }

function StatsState.enter()
    player = Context.player()
    currentTab = "overall"
end

function StatsState.update(dt)
end

-- ---------------------------------------------------------------------------
-- Drawing helpers
-- ---------------------------------------------------------------------------

local function drawPanel(x, y, w, h)
    Theme.setColor("panel")
    love.graphics.rectangle("fill", x, y, w, h, Theme.radius, Theme.radius)
    Theme.setColor("border")
    love.graphics.rectangle("line", x, y, w, h, Theme.radius, Theme.radius)
end

local function drawEmptyMessage(x, y, w, h, text)
    local font = Theme.font("small")
    love.graphics.setFont(font)
    Theme.setColor("textDim")
    love.graphics.printf(text, x, y + h / 2 - font:getHeight() / 2, w, "center")
end

-- Draws a 2-column grid of label/value cards and returns the y coordinate
-- just below the grid, so callers can stack more content underneath.
local function drawStatGrid(x, y, w, items)
    local font = Theme.font("small")
    love.graphics.setFont(font)

    local cols = 2
    local gap = Theme.spacing.sm
    local itemW = (w - gap * (cols + 1)) / cols
    local itemH = font:getHeight() + Theme.spacing.sm * 2

    for i, item in ipairs(items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local ix = x + gap + col * (itemW + gap)
        local iy = y + gap + row * (itemH + gap)

        Theme.setColor("panelLight")
        love.graphics.rectangle("fill", ix, iy, itemW, itemH, Theme.radius, Theme.radius)

        Theme.setColor("textMuted")
        love.graphics.print(item.label .. ":", ix + Theme.spacing.sm, iy + Theme.spacing.sm)

        Theme.setColor("text")
        local valueText = tostring(item.value)
        local valueW = font:getWidth(valueText)
        love.graphics.print(valueText, ix + itemW - valueW - Theme.spacing.sm, iy + Theme.spacing.sm)
    end

    local rows = math.ceil(#items / cols)
    return y + gap + rows * (itemH + gap)
end

local function drawBarGraph(x, y, w, h, matchHistory)
    drawPanel(x, y, w, h)

    local labelFont = Theme.font("small")
    love.graphics.setFont(labelFont)
    Theme.setColor("text")
    love.graphics.print("Accuracy", x + Theme.spacing.sm, y + Theme.spacing.xs)

    local n = #matchHistory
    if n == 0 then
        drawEmptyMessage(x, y, w, h, "No matches recorded yet")
        return
    end

    local barCount = math.min(n, MAX_BARS)
    local top = y + labelFont:getHeight() + Theme.spacing.sm
    local bottom = y + h - Theme.spacing.sm
    local barAreaHeight = math.max(1, bottom - top)
    local left = x + Theme.spacing.md
    local right = x + w - Theme.spacing.sm
    local barAreaWidth = math.max(1, right - left)
    local barWidth = barAreaWidth / barCount

    local errC, okC = Theme.color("error"), Theme.color("success")

    for i = 1, barCount do
        local match = matchHistory[barMatchIndex(i, barCount)]
        local accuracy = (type(match) == "table" and type(match.accuracy) == "number") and match.accuracy or 0
        accuracy = math.max(0, math.min(100, accuracy))

        local t = accuracy / 100
        local barHeight = t * barAreaHeight
        local barX = left + (i - 1) * barWidth

        love.graphics.setColor(
            errC[1] + (okC[1] - errC[1]) * t,
            errC[2] + (okC[2] - errC[2]) * t,
            errC[3] + (okC[3] - errC[3]) * t,
            1)
        love.graphics.rectangle("fill", barX, bottom - barHeight, math.max(1, barWidth - 1), barHeight)
    end

    Theme.setColor("textDim")
    love.graphics.print("0%", x + Theme.spacing.xs, bottom - labelFont:getHeight())
    love.graphics.print("100%", x + Theme.spacing.xs, top)
end

local function drawLineGraph(x, y, w, h, matchHistory)
    drawPanel(x, y, w, h)

    local labelFont = Theme.font("small")
    love.graphics.setFont(labelFont)
    Theme.setColor("text")
    love.graphics.print("WPM over time", x + Theme.spacing.sm, y + Theme.spacing.xs)

    local series = matchSeries(matchHistory, "wpm")
    if #series == 0 then
        drawEmptyMessage(x, y, w, h, "No matches recorded yet")
        return
    end

    local lo, hi = lineGraphRange(series)
    local top = y + labelFont:getHeight() + Theme.spacing.sm
    local bottom = y + h - Theme.spacing.sm
    local plotHeight = math.max(1, bottom - top)
    local left = x + Theme.spacing.lg -- room for the axis labels
    local right = x + w - Theme.spacing.sm
    local plotWidth = math.max(1, right - left)

    local function pointAt(i)
        local px
        if #series == 1 then
            px = left + plotWidth / 2
        else
            px = left + (i - 1) / (#series - 1) * plotWidth
        end
        local py = bottom - ((series[i] - lo) / (hi - lo)) * plotHeight
        return px, py
    end

    Theme.setColor("accent")
    if #series == 1 then
        local px, py = pointAt(1)
        love.graphics.circle("fill", px, py, 2)
    else
        for i = 1, #series - 1 do
            local x1, y1 = pointAt(i)
            local x2, y2 = pointAt(i + 1)
            love.graphics.line(x1, y1, x2, y2)
        end
    end

    -- Best-ever marker: the series already spans the full match history, so
    -- its max is the true personal best among recorded matches.
    local bestIndex, bestValue = 1, series[1]
    for i, v in ipairs(series) do
        if v > bestValue then bestValue, bestIndex = v, i end
    end
    if bestValue > 0 then
        local bx, by = pointAt(bestIndex)
        Theme.setColor("rarity.legendary")
        love.graphics.circle("fill", bx, by, 3)

        local label = string.format("best %.0f", bestValue)
        local labelX = math.min(math.max(left, bx - 14), right - labelFont:getWidth(label))
        love.graphics.print(label, labelX, by - labelFont:getHeight() - 2)
    end

    Theme.setColor("textDim")
    love.graphics.print(string.format("%.0f", hi), x + Theme.spacing.xs, top)
    love.graphics.print(string.format("%.0f", lo), x + Theme.spacing.xs, bottom - labelFont:getHeight())
end

local function drawPieChart(x, y, w, h, spent, balance)
    local font = Theme.font("small")
    love.graphics.setFont(font)

    local total = spent + balance
    local radius = math.max(1, math.min(w, h) / 2 - Theme.spacing.sm)
    local cx = x + radius + Theme.spacing.sm
    local cy = y + h / 2

    if total <= 0 then
        Theme.setColor("panelLight")
        love.graphics.circle("fill", cx, cy, radius)
    else
        local spentAngle = (spent / total) * math.pi * 2
        Theme.setColor("error")
        love.graphics.arc("fill", cx, cy, radius, 0, spentAngle)
        Theme.setColor("success")
        love.graphics.arc("fill", cx, cy, radius, spentAngle, math.pi * 2)
    end

    local legendX = cx + radius + Theme.spacing.lg
    local legendY = cy - radius
    local swatch = font:getHeight()

    Theme.setColor("error")
    love.graphics.rectangle("fill", legendX, legendY, swatch, swatch)
    Theme.setColor("text")
    love.graphics.print("Spent", legendX + swatch + Theme.spacing.xs, legendY)

    Theme.setColor("success")
    love.graphics.rectangle("fill", legendX, legendY + swatch + Theme.spacing.xs, swatch, swatch)
    Theme.setColor("text")
    love.graphics.print("Balance", legendX + swatch + Theme.spacing.xs, legendY + swatch + Theme.spacing.xs)
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------

local function drawOverallTab(x, y, w, h)
    local stats = player:getStats() or {}
    local items = {
        { label = "Play Time", value = formatTime(stats.totalPlayTime) },
        { label = "Sessions", value = stats.totalSessions or 0 },
        { label = "Keystrokes", value = stats.totalKeystrokes or 0 },
        { label = "Round", value = player.currentRound or 1 },
        { label = "Best Round", value = player.maxRoundReached or 1 },
        { label = "Perfect Rounds", value = stats.perfectRounds or 0 },
        { label = "Money", value = player.totalMoney or 0 },
        { label = "Keyboard", value = (player.keyboard and player.keyboard.name) or "QWERTY" },
        { label = "Upgrades", value = countUpgrades(player.keyboard and player.keyboard.upgrades) },
    }
    drawStatGrid(x, y, w, items)
end

local function drawTypingTab(x, y, w, h)
    local stats = player:getStats() or {}
    local items = {
        { label = "Keystrokes", value = stats.totalKeystrokes or 0 },
        { label = "Correct", value = stats.totalCorrect or 0 },
        { label = "Mistakes", value = stats.totalMistakes or 0 },
        { label = "Accuracy", value = string.format("%.1f%%", getAccuracy(stats)) },
        { label = "Best APM", value = string.format("%.1f", stats.bestAPM or 0) },
        { label = "Best WPM", value = string.format("%.1f", stats.bestWPM or 0) },
        { label = "Best Accuracy", value = string.format("%.1f%%", stats.bestAccuracy or 0) },
        { label = "Best Streak", value = stats.bestStreak or 0 },
        { label = "Error-free", value = stats.roundsWithoutError or 0 },
    }
    local afterGrid = drawStatGrid(x, y, w, items)

    local matchHistory = (type(player.getMatchHistory) == "function" and player:getMatchHistory()) or {}
    local graphY = afterGrid + Theme.spacing.sm
    local graphH = (y + h) - graphY
    if graphH > Theme.spacing.xl then
        local graphGap = Theme.spacing.sm
        local graphW = (w - graphGap) / 2
        drawBarGraph(x, graphY, graphW, graphH, matchHistory)
        drawLineGraph(x + graphW + graphGap, graphY, graphW, graphH, matchHistory)
    end
end

local function drawEconomyTab(x, y, w, h)
    local stats = player:getStats() or {}
    local items = {
        { label = "Earned", value = stats.moneyEarned or 0 },
        { label = "Spent", value = stats.moneySpent or 0 },
        { label = "Balance", value = player.totalMoney or 0 },
        { label = "Upgrades", value = countUpgrades(player.keyboard and player.keyboard.upgrades) },
        { label = "Savings Rate", value = string.format("%.1f%%", getSavingsRate(stats)) },
    }
    local afterGrid = drawStatGrid(x, y, w, items)

    local chartY = afterGrid + Theme.spacing.sm
    local chartH = (y + h) - chartY
    if chartH > Theme.spacing.xl then
        drawPieChart(x, chartY, w, chartH, stats.moneySpent or 0, player.totalMoney or 0)
    end
end

-- ---------------------------------------------------------------------------
-- Main draw
-- ---------------------------------------------------------------------------

function StatsState.draw()
    local sw, sh = Screen.getWidth(), Screen.getHeight()

    Theme.setColor("base")
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if not player then
        Theme.setColor("error")
        love.graphics.setFont(Theme.font("body"))
        love.graphics.printf("Unable to load player data", 0, sh / 2, sw, "center")
        return
    end

    local margin = Theme.spacing.md

    -- Title
    local titleFont = Theme.font("display")
    love.graphics.setFont(titleFont)
    Theme.setColor("accent")
    love.graphics.printf("Statistics", 0, Theme.spacing.xs, sw, "center")
    local titleBottom = Theme.spacing.xs + titleFont:getHeight()

    -- Tabs
    local tabFont = Theme.font("heading")
    love.graphics.setFont(tabFont)
    local tabH = tabFont:getHeight() + Theme.spacing.sm * 2
    local tabsY = titleBottom + Theme.spacing.xs
    local tabGap = Theme.spacing.xs
    local tabsW = sw - margin * 2
    local tabW = (tabsW - tabGap * (#TABS - 1)) / #TABS

    layout.tabs = {}
    for i, tab in ipairs(TABS) do
        local tx = margin + (i - 1) * (tabW + tabGap)
        local selected = (currentTab == tab)
        Theme.setColor(selected and "accent" or "panel")
        love.graphics.rectangle("fill", tx, tabsY, tabW, tabH, Theme.radius, Theme.radius)
        Theme.setColor("border")
        love.graphics.rectangle("line", tx, tabsY, tabW, tabH, Theme.radius, Theme.radius)
        Theme.setColor(selected and "base" or "text")
        love.graphics.printf(TAB_LABELS[tab], tx, tabsY + Theme.spacing.sm, tabW, "center")
        layout.tabs[i] = { x = tx, y = tabsY, w = tabW, h = tabH, tab = tab }
    end

    -- Back button
    local backFont = Theme.font("body")
    local backH = backFont:getHeight() + Theme.spacing.sm * 2
    local backW = 120
    local backX = (sw - backW) / 2
    local backY = sh - margin - backH
    Theme.setColor("panelLight")
    love.graphics.rectangle("fill", backX, backY, backW, backH, Theme.radius, Theme.radius)
    Theme.setColor("border")
    love.graphics.rectangle("line", backX, backY, backW, backH, Theme.radius, Theme.radius)
    Theme.setColor("text")
    love.graphics.setFont(backFont)
    love.graphics.printf("Back (Esc)", backX, backY + Theme.spacing.sm, backW, "center")
    layout.back = { x = backX, y = backY, w = backW, h = backH }

    -- Content panel
    local panelY = tabsY + tabH + Theme.spacing.xs
    local panelBottom = backY - Theme.spacing.xs
    local panelH = panelBottom - panelY
    local panelX = margin
    local panelW = sw - margin * 2
    drawPanel(panelX, panelY, panelW, panelH)

    local innerPad = Theme.spacing.sm
    local contentX = panelX + innerPad
    local contentY = panelY + innerPad
    local contentW = panelW - innerPad * 2
    local contentH = panelH - innerPad * 2

    if currentTab == "overall" then
        drawOverallTab(contentX, contentY, contentW, contentH)
    elseif currentTab == "typing" then
        drawTypingTab(contentX, contentY, contentW, contentH)
    elseif currentTab == "economy" then
        drawEconomyTab(contentX, contentY, contentW, contentH)
    end

    Theme.setColor("text")
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function StatsState.keypressed(key)
    if key == "left" then
        for i, tab in ipairs(TABS) do
            if tab == currentTab and i > 1 then
                currentTab = TABS[i - 1]
                break
            end
        end
    elseif key == "right" then
        for i, tab in ipairs(TABS) do
            if tab == currentTab and i < #TABS then
                currentTab = TABS[i + 1]
                break
            end
        end
    elseif key == "escape" or key == "backspace" or key == "m" then
        StateManager.switch("menuState")
    end
end

local function pointInRect(px, py, r)
    return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

function StatsState.mousepressed(x, y, button)
    if button ~= 1 then return end

    if pointInRect(x, y, layout.back) then
        StateManager.switch("menuState")
        return
    end

    for _, tabRect in ipairs(layout.tabs) do
        if pointInRect(x, y, tabRect) then
            currentTab = tabRect.tab
            return
        end
    end
end

return StatsState
