-- states/gameOverState.lua
-- The failed-run screen: reached when a score gate is missed (reason =
-- "failed") or the player abandons from pause (reason = "abandoned"). The
-- roadmap calls this out by name: "a failed run silently dumps to menu --
-- worst moment in the game to be anticlimactic." This is the fix.

local StateManager = require("engine/stateManager")
local Context = require("modules/game/context")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local Audio = require("modules/audio/audio")

local GameOverState = { name = "GameOverState", logical = true }

-- ---------------------------------------------------------------------------
-- Pure logic -- unit-tested directly by tests/test_run_summary.lua. Nothing
-- in this section touches love.graphics so it is safe to call headless.
-- ---------------------------------------------------------------------------

-- Read a field from a stats table under any of several candidate names.
-- Run-scoped and lifetime stat tables use different naming conventions
-- (TypingTrainer:getStats() vs PlayerModel:getStats(), and unit 1's
-- getRunStats() shape isn't settled yet), so callers pass every name that
-- could plausibly hold the value they want.
local function readStat(stats, ...)
    if not stats then return nil end
    for _, key in ipairs({ ... }) do
        if stats[key] ~= nil then return stats[key] end
    end
    return nil
end
GameOverState.readStat = readStat

-- This run's stats, preferring the run-scoped accessor unit 1 is adding and
-- falling back to the lifetime aggregate so this screen works before (or
-- without) that lands.
function GameOverState.getStatsSource(player)
    if not player then return {} end

    if type(player.getRunStats) == "function" then
        local ok, stats = pcall(player.getRunStats, player)
        if ok and stats then return stats end
    end

    if type(player.getStats) == "function" then
        local ok, stats = pcall(player.getStats, player)
        if ok and stats then return stats end
    end

    return {}
end

-- A "new best" is a strict improvement -- tying a lifetime record is not one.
function GameOverState.isNewBest(current, best)
    if type(current) ~= "number" or type(best) ~= "number" then return false end
    return current > best
end

-- The highest-bonus installed key, i.e. the "MVP". Returns nil with no
-- upgrades installed. Ties break alphabetically so the result is
-- deterministic regardless of pairs() iteration order. Per-key contribution
-- to the run's score is not tracked, so callers must label this honestly
-- (e.g. "Top Upgrade"), not as a measured contribution.
function GameOverState.selectMvpKey(keyboard)
    if not keyboard or type(keyboard.upgrades) ~= "table" then return nil end

    local keys = {}
    for key in pairs(keyboard.upgrades) do keys[#keys + 1] = key end
    table.sort(keys)

    local bestKey, bestBonus = nil, -math.huge
    for _, key in ipairs(keys) do
        local raw = keyboard.upgrades[key]
        local bonus = 0
        if type(raw) == "number" then
            bonus = raw
        elseif type(raw) == "table" then
            bonus = raw.bonus or (raw.effect and raw.effect.value) or 0
        end

        if bonus > bestBonus then
            bestKey, bestBonus = key, bonus
        end
    end

    if not bestKey then return nil end
    return { key = bestKey, bonus = bestBonus }
end

-- Call obj:method(...) only if it exists, swallowing errors. Used for every
-- cross-unit contract (PlayerModel additions, run.lua) that may not exist yet.
local function safeCall(obj, method, ...)
    if obj and type(obj[method]) == "function" then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then return result end
    end
    return nil
end
GameOverState.safeCall = safeCall

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local BUTTON_W, BUTTON_H, BUTTON_GAP = 140, 28, 16

local function layoutButtons(list)
    local totalW = #list * BUTTON_W + (#list - 1) * BUTTON_GAP
    local startX = (Screen.getWidth() - totalW) / 2
    local y = Screen.getHeight() - Theme.spacing.xxl - BUTTON_H
    for i, b in ipairs(list) do
        b.x = startX + (i - 1) * (BUTTON_W + BUTTON_GAP)
        b.y = y
        b.w = BUTTON_W
        b.h = BUTTON_H
    end
    return list
end

local function buildButtons()
    return layoutButtons({
        {
            label = "Retry",
            action = function()
                Context.clearRun()
                safeCall(Context.player(), "resetProgress")
                StateManager.switch("roundState")
            end,
        },
        {
            label = "Main Menu",
            action = function()
                StateManager.switch("menuState")
            end,
        },
    })
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local current = nil

function GameOverState.enter(params)
    params = params or {}

    -- pauseState and resultsState route here via StateManager.switch(name),
    -- which never forwards extra arguments, so also check the hand-off slot
    -- for the { reason, round } payload in case that is how it was sent.
    if params.reason == nil then
        local pending = Context.peekPendingResults()
        if pending and pending.reason then
            params = pending
            Context.takePendingResults()
        end
    end

    local player = Context.player()
    local lifetime = safeCall(player, "getStats") or {}
    local runStats = GameOverState.getStatsSource(player)

    local round = params.round or (player and player.currentRound) or 1
    local gate = safeCall(player, "getRequiredScore")
    local mvp = GameOverState.selectMvpKey(player and player.keyboard)

    local wpm = readStat(runStats, "bestWPM", "wpm") or 0
    local accuracy = readStat(runStats, "accuracy", "bestAccuracy") or 0
    local streak = readStat(runStats, "longestStreak", "bestStreak", "streak") or 0

    current = {
        reason = params.reason or "failed",
        round = round,
        gate = gate,
        score = params.score,
        stats = {
            keystrokes = readStat(runStats, "totalKeystrokes", "keystrokes") or 0,
            accuracy = accuracy,
            bestWPM = wpm,
            longestStreak = streak,
            moneyEarned = readStat(runStats, "moneyEarned") or 0,
        },
        mvp = mvp,
        newBest = {
            wpm = GameOverState.isNewBest(wpm, lifetime.bestWPM or 0),
            accuracy = GameOverState.isNewBest(accuracy, lifetime.bestAccuracy or 0),
            streak = GameOverState.isNewBest(streak, lifetime.bestStreak or 0),
            round = GameOverState.isNewBest(round, (player and player.maxRoundReached) or 0),
        },
        selected = 1,
        hoverIndex = nil,
        buttons = buildButtons(),
    }

    -- Reset the run cleanly on entry so the next run always starts fresh, no
    -- matter which button the player eventually presses. resetProgress()
    -- writes to disk, so skip it during the headless test suite -- otherwise
    -- every test run would stomp the real save file.
    Context.clearRun()
    if not _G.HEADLESS then
        safeCall(player, "resetProgress")
    end

    Audio.playMusic("gameover", { loop = false })
end

function GameOverState.exit()
    current = nil
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

local function drawButton(b, hovered)
    Theme.setColor(hovered and "panelLight" or "panel")
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    Theme.setColor(hovered and "accent" or "border")
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h)

    Theme.setColor("text")
    local font = Theme.font("body")
    love.graphics.setFont(font)
    love.graphics.printf(b.label, b.x, b.y + (b.h - font:getHeight()) / 2, b.w, "center")
end

function GameOverState.draw()
    -- Launched cold (e.g. the --shot harness) there is no run in progress;
    -- render sensible defaults instead of a crash or a blank screen.
    if not current then GameOverState.enter(nil) end

    local w, h = Screen.getWidth(), Screen.getHeight()
    local sp = Theme.spacing

    Theme.setColor("base")
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(Theme.font("display"))
    Theme.setColor("error")
    local title = current.reason == "abandoned" and "RUN ABANDONED" or "RUN OVER"
    love.graphics.printf(title, 0, sp.lg, w, "center")

    love.graphics.setFont(Theme.font("body"))
    Theme.setColor("textMuted")
    local subtitle
    if current.score and current.gate then
        subtitle = string.format("Round %d -- scored %d, needed %d", current.round, current.score, current.gate)
    elseif current.gate then
        subtitle = string.format("Round %d -- needed %d to advance", current.round, current.gate)
    else
        subtitle = string.format("Fell at round %d", current.round)
    end
    love.graphics.printf(subtitle, 0, sp.lg + 28, w, "center")

    -- Stats panel
    local panelX, panelY = sp.xxl, 80
    local panelW, panelH = w - sp.xxl * 2, 130
    Theme.setColor("panel")
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    Theme.setColor("border")
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)

    local stats = current.stats
    local rows = {
        { "Keystrokes", tostring(stats.keystrokes) },
        { "Accuracy", string.format("%.1f%%", stats.accuracy) },
        { "Best WPM", string.format("%.1f", stats.bestWPM) },
        { "Longest Streak", tostring(stats.longestStreak) },
        { "Money Earned", tostring(stats.moneyEarned) },
    }

    local monoFont = Theme.font("mono")
    love.graphics.setFont(monoFont)
    local rowH = 22
    for i, row in ipairs(rows) do
        local ry = panelY + sp.md + (i - 1) * rowH
        Theme.setColor("textMuted")
        love.graphics.print(row[1], panelX + sp.md, ry)
        Theme.setColor("text")
        local valW = monoFont:getWidth(row[2])
        love.graphics.print(row[2], panelX + panelW - sp.md - valW, ry)
    end

    -- MVP callout
    local calloutY = panelY + panelH + sp.md
    if current.mvp then
        Theme.setColor("accent")
        love.graphics.setFont(Theme.font("heading"))
        local label = current.mvp.key == " " and "SPACE" or current.mvp.key:upper()
        love.graphics.printf(
            string.format("Top Upgrade: %s (+%.0f%%)", label, current.mvp.bonus * 100),
            0, calloutY, w, "center")
    else
        Theme.setColor("textDim")
        love.graphics.setFont(Theme.font("body"))
        love.graphics.printf("No upgrades installed this run", 0, calloutY, w, "center")
    end

    -- "New best" callouts
    local bestLines = {}
    if current.newBest.wpm then bestLines[#bestLines + 1] = "New best WPM!" end
    if current.newBest.accuracy then bestLines[#bestLines + 1] = "New best accuracy!" end
    if current.newBest.streak then bestLines[#bestLines + 1] = "New best streak!" end
    if current.newBest.round then bestLines[#bestLines + 1] = "Furthest round yet!" end

    if #bestLines > 0 then
        Theme.setColor("success")
        love.graphics.setFont(Theme.font("body"))
        love.graphics.printf(table.concat(bestLines, "   "), 0, calloutY + 22, w, "center")
    end

    for i, b in ipairs(current.buttons) do
        drawButton(b, current.hoverIndex == i or current.selected == i)
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function GameOverState.keypressed(key)
    if not current then return end
    local buttons = current.buttons

    if key == "left" or key == "up" then
        current.selected = current.selected - 1
        if current.selected < 1 then current.selected = #buttons end
    elseif key == "right" or key == "down" then
        current.selected = current.selected + 1
        if current.selected > #buttons then current.selected = 1 end
    elseif key == "return" or key == "kpenter" or key == "space" then
        local b = buttons[current.selected]
        if b and b.action then
            Audio.playSfx("confirm")
            b.action()
        end
    elseif key == "escape" then
        StateManager.switch("menuState")
    end
end

local function buttonAt(x, y)
    if not current then return nil end
    for _, b in ipairs(current.buttons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return b
        end
    end
    return nil
end

function GameOverState.mousemoved(x, y)
    if not current then return end
    current.hoverIndex = nil
    for i, b in ipairs(current.buttons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            current.hoverIndex = i
            current.selected = i
        end
    end
end

function GameOverState.mousepressed(x, y, button)
    if button ~= 1 then return end
    local b = buttonAt(x, y)
    if b and b.action then
        Audio.playSfx("confirm")
        b.action()
    end
end

return GameOverState
