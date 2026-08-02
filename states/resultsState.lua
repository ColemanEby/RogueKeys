-- states/resultsState.lua
-- Between-round results screen. roundState used to decide "shop or menu"
-- itself via raw key handling (the "press S for shop" bug); this screen now
-- owns that decision explicitly, with buttons instead of an overloaded
-- post-completion keypressed branch.

local StateManager = require("engine/stateManager")
local Context = require("modules/game/context")
local Screen = require("modules/ui/screen")
local Theme = require("modules/ui/theme")

local ResultsState = {
    name = "ResultsState",
    logical = true,
}

-- Held locally so a round trip through the shop (which re-enters this state
-- with no pending results) doesn't lose the screen's contents.
local results = nil
local moneyShown = 0
local moneyTimer = 0
local MONEY_ANIM_DURATION = 0.6

local function defaultResults()
    return {
        stats = { wpm = 0, accuracy = 0, longestStreak = 0, keystrokes = 0, mistakes = 0, score = 0 },
        moneyEarned = 0,
        requiredScore = 0,
        passed = false,
        round = 0,
    }
end

-- Switch to `target`, falling back to `fallback` if target isn't available
-- (used for gameOverState/pauseState, which are other units' in-flight work).
local function safeSwitch(target, fallback)
    local exists = not StateManager.loadState or StateManager.loadState(target)
    if exists then
        StateManager.switch(target)
    else
        StateManager.switch(fallback)
    end
end

local function goToGameOver()
    safeSwitch("gameOverState", "menuState")
end

local function goToShop()
    StateManager.switch("shopState", { returnTo = "resultsState" })
end

local function goToNextRound()
    local player = Context.player()
    player:advanceRound(results.stats.score)
    StateManager.switch("roundState")
end

local function buildButtons()
    local buttons = {}
    buttons[#buttons + 1] = { key = "s", label = "[S] Shop", action = goToShop }

    if results.passed then
        buttons[#buttons + 1] = { key = "n", label = "[N] Next Round", action = goToNextRound }
    else
        buttons[#buttons + 1] = { key = "n", label = "[N] Continue", action = goToGameOver }
    end

    buttons[#buttons + 1] = { key = "a", label = "[A] Abandon Run", action = goToGameOver }
    return buttons
end

function ResultsState.enter()
    local pending = Context.takePendingResults()
    if pending then
        results = pending
    elseif not results then
        results = defaultResults()
    end

    moneyShown = 0
    moneyTimer = 0
end

function ResultsState.update(dt)
    if not results then return end

    if moneyShown < results.moneyEarned then
        moneyTimer = moneyTimer + dt
        local t = math.min(1, moneyTimer / MONEY_ANIM_DURATION)
        moneyShown = math.floor(results.moneyEarned * t + 0.5)
    end
end

local function drawButton(x, y, w, h, label)
    Theme.setColor("panel")
    love.graphics.rectangle("fill", x, y, w, h)
    Theme.setColor("border")
    love.graphics.rectangle("line", x, y, w, h)

    Theme.setColor("text")
    love.graphics.setFont(Theme.font("body"))
    love.graphics.printf(label, x, y + h / 2 - Theme.font("body"):getHeight() / 2, w, "center")
end

local function buttonRects(buttons)
    local w, gap = 160, Theme.spacing.lg
    local totalWidth = #buttons * w + (#buttons - 1) * gap
    local x = (Screen.getWidth() - totalWidth) / 2
    local y = Screen.getHeight() - Theme.spacing.xxl - 24
    local h = 24

    local rects = {}
    for i, button in ipairs(buttons) do
        rects[i] = { x = x + (i - 1) * (w + gap), y = y, w = w, h = h, button = button }
    end
    return rects
end

function ResultsState.draw()
    if not results then return end

    local base = Theme.color("base")
    love.graphics.clear(base[1], base[2], base[3], base[4] or 1)

    local width = Screen.getWidth()
    local stats = results.stats or {}

    love.graphics.setFont(Theme.font("display"))
    Theme.setColor("text")
    love.graphics.printf("Round " .. tostring(results.round), 0, Theme.spacing.lg, width, "center")

    love.graphics.setFont(Theme.font("heading"))
    Theme.setColor(results.passed and "success" or "error")
    love.graphics.printf(results.passed and "PASSED" or "FAILED", 0, 48, width, "center")

    Theme.setColor("textMuted")
    love.graphics.setFont(Theme.font("body"))
    love.graphics.printf(
        string.format("Score %d / %d required", stats.score or 0, results.requiredScore or 0),
        0, 72, width, "center")

    -- Stat breakdown, two columns.
    local rows = {
        { "WPM", string.format("%.1f", stats.wpm or 0) },
        { "Accuracy", string.format("%.1f%%", stats.accuracy or 0) },
        { "Longest Streak", tostring(stats.longestStreak or 0) },
        { "Keystrokes", tostring(stats.keystrokes or 0) },
        { "Mistakes", tostring(stats.mistakes or 0) },
        { "Score", tostring(stats.score or 0) },
    }

    local colX = { width / 2 - 160, width / 2 + 20 }
    local rowY = 110
    local rowHeight = 20
    love.graphics.setFont(Theme.font("mono"))
    for i, row in ipairs(rows) do
        local col = (i - 1) % 2
        local rowIndex = math.floor((i - 1) / 2)
        local x = colX[col + 1]
        local y = rowY + rowIndex * rowHeight

        Theme.setColor("textMuted")
        love.graphics.print(row[1] .. ":", x, y)
        Theme.setColor("text")
        love.graphics.print(row[2], x + 120, y)
    end

    -- Money earned, counting up.
    love.graphics.setFont(Theme.font("display"))
    Theme.setColor("accent")
    love.graphics.printf("+" .. tostring(moneyShown) .. " coins", 0, 230, width, "center")

    local rects = buttonRects(buildButtons())
    for _, r in ipairs(rects) do
        drawButton(r.x, r.y, r.w, r.h, r.button.label)
    end
end

function ResultsState.keypressed(key)
    if not results then return end

    for _, button in ipairs(buildButtons()) do
        if button.key == key then
            button.action()
            return
        end
    end
end

function ResultsState.mousepressed(x, y, mouseButton)
    if not results or mouseButton ~= 1 then return end

    for _, r in ipairs(buttonRects(buildButtons())) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            r.button.action()
            return
        end
    end
end

return ResultsState
