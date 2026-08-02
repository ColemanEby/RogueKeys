-- states/victoryState.lua
-- The run-complete screen: reached when the final round of a run is cleared
-- (unit 12 defines an 8-round run in modules/game/run.lua). This is the
-- payoff moment, the mirror of gameOverState -- celebratory treatment, the
-- finished keyboard on display, the full run summary.

local StateManager = require("engine/stateManager")
local Context = require("modules/game/context")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local Audio = require("modules/audio/audio")

-- modules/game/run.lua (unit 12) and KeyboardView's exact shape may not match
-- what's here yet; require defensively and guard every use.
local runOk, Run = pcall(require, "modules/game/run")
local keyboardViewOk, KeyboardView = pcall(require, "modules/keyboard/keyboardView")

local VictoryState = { name = "VictoryState", logical = true }

-- ---------------------------------------------------------------------------
-- Pure logic -- mirrors gameOverState.lua exactly (duplicated rather than
-- shared: these are two standalone new states and neither owns a shared
-- module file). Unit-tested by tests/test_run_summary.lua.
-- ---------------------------------------------------------------------------

local function readStat(stats, ...)
    if not stats then return nil end
    for _, key in ipairs({ ... }) do
        if stats[key] ~= nil then return stats[key] end
    end
    return nil
end
VictoryState.readStat = readStat

function VictoryState.getStatsSource(player)
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

function VictoryState.isNewBest(current, best)
    if type(current) ~= "number" or type(best) ~= "number" then return false end
    return current > best
end

function VictoryState.selectMvpKey(keyboard)
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

local function safeCall(obj, method, ...)
    if obj and type(obj[method]) == "function" then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then return result end
    end
    return nil
end
VictoryState.safeCall = safeCall

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local BUTTON_W, BUTTON_H, BUTTON_GAP = 170, 28, 16

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

-- Advance to the next difficulty tier. Prefers modules/game/run.lua's own
-- advance if it exposes one; otherwise keeps rounds going with a raised
-- difficulty scalar stashed on Context.run so at least *something* escalates.
local function continueEndless()
    local run = Context.run

    if runOk and Run and run and type(run.advanceTier) == "function" then
        local ok = pcall(run.advanceTier, run)
        if ok then
            StateManager.switch("roundState")
            return
        end
    end

    run = run or {}
    run.endlessMultiplier = (run.endlessMultiplier or 1.0) * 1.15
    run.tier = (run.tier or 1) + 1
    Context.setRun(run)
    StateManager.switch("roundState")
end

local function buildButtons()
    return layoutButtons({
        {
            label = "Continue (Endless)",
            action = continueEndless,
        },
        {
            label = "Main Menu",
            action = function()
                Context.clearRun()
                safeCall(Context.player(), "resetProgress")
                StateManager.switch("menuState")
            end,
        },
    })
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local current = nil

function VictoryState.enter(params)
    params = params or {}

    if params.round == nil then
        local pending = Context.peekPendingResults()
        if pending and pending.round then
            params = pending
            Context.takePendingResults()
        end
    end

    local player = Context.player()
    local lifetime = safeCall(player, "getStats") or {}
    local runStats = VictoryState.getStatsSource(player)

    local round = params.round or (player and player.maxRoundReached) or 8
    local mvp = VictoryState.selectMvpKey(player and player.keyboard)

    local wpm = readStat(runStats, "bestWPM", "wpm") or 0
    local accuracy = readStat(runStats, "accuracy", "bestAccuracy") or 0
    local streak = readStat(runStats, "longestStreak", "bestStreak", "streak") or 0

    current = {
        round = round,
        stats = {
            keystrokes = readStat(runStats, "totalKeystrokes", "keystrokes") or 0,
            accuracy = accuracy,
            bestWPM = wpm,
            longestStreak = streak,
            moneyEarned = readStat(runStats, "moneyEarned") or 0,
        },
        mvp = mvp,
        newBest = {
            wpm = VictoryState.isNewBest(wpm, lifetime.bestWPM or 0),
            accuracy = VictoryState.isNewBest(accuracy, lifetime.bestAccuracy or 0),
            streak = VictoryState.isNewBest(streak, lifetime.bestStreak or 0),
            round = VictoryState.isNewBest(round, (player and player.maxRoundReached) or 0),
        },
        selected = 1,
        hoverIndex = nil,
        buttons = buildButtons(),
        keyboardView = nil,
        glowT = 0,
    }

    Audio.playMusic("victory", { loop = false })
end

function VictoryState.exit()
    current = nil
end

function VictoryState.update(dt)
    if not current then return end
    current.glowT = current.glowT + dt
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

-- Lazily build (and defensively fail on) the big keyboard preview. Unit 14
-- owns keyboardView.lua; call it, never modify it, never let a shape change
-- there crash this screen.
local function ensureKeyboardView(player)
    if current.keyboardView or not keyboardViewOk or not KeyboardView then return end
    if not player or not player.keyboard then return end

    local ok, kv = pcall(KeyboardView.new, player.keyboard)
    if ok and kv then current.keyboardView = kv end
end

function VictoryState.draw()
    if not current then VictoryState.enter(nil) end

    local w, h = Screen.getWidth(), Screen.getHeight()
    local sp = Theme.spacing

    Theme.setColor("base")
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Gentle glow pulse behind the title -- the celebratory beat this screen
    -- exists for.
    local pulse = 0.15 + 0.10 * (0.5 + 0.5 * math.sin((current.glowT or 0) * 2))
    Theme.setColor("accent", pulse)
    love.graphics.rectangle("fill", 0, 0, w, 96)

    love.graphics.setFont(Theme.font("display"))
    Theme.setColor("accent")
    love.graphics.printf("RUN COMPLETE!", 0, sp.lg, w, "center")

    love.graphics.setFont(Theme.font("body"))
    Theme.setColor("text")
    local roundWord = current.round == 1 and "round" or "rounds"
    love.graphics.printf(string.format("Cleared %d %s", current.round, roundWord), 0, sp.lg + 28, w, "center")

    -- Big keyboard preview, if the view module is available.
    ensureKeyboardView(Context.player())
    if current.keyboardView then
        local scale = 0.5
        local ok, dims = pcall(current.keyboardView.calculateDimensions, current.keyboardView, 0, 0, scale)
        if ok and dims then
            local kx = (w - dims.width) / 2
            local ky = 92
            pcall(current.keyboardView.draw, current.keyboardView, kx, ky, scale)
        end
    end

    -- Stats panel
    local panelX, panelY = sp.xxl, 200
    local panelW, panelH = w - sp.xxl * 2, 90
    Theme.setColor("panel")
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    Theme.setColor("borderLight")
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)

    local stats = current.stats
    local cols = {
        { "Keystrokes", tostring(stats.keystrokes) },
        { "Accuracy", string.format("%.1f%%", stats.accuracy) },
        { "Best WPM", string.format("%.1f", stats.bestWPM) },
        { "Streak", tostring(stats.longestStreak) },
        { "Earned", tostring(stats.moneyEarned) },
    }

    local monoFont = Theme.font("mono")
    love.graphics.setFont(monoFont)
    local colW = panelW / #cols
    for i, col in ipairs(cols) do
        local cx = panelX + (i - 1) * colW
        Theme.setColor("textMuted")
        love.graphics.printf(col[1], cx, panelY + sp.sm, colW, "center")
        Theme.setColor("accent")
        love.graphics.printf(col[2], cx, panelY + sp.sm + 16, colW, "center")
    end

    -- MVP + new best callouts
    local calloutY = panelY + panelH + sp.md
    if current.mvp then
        Theme.setColor("accent")
        love.graphics.setFont(Theme.font("heading"))
        local label = current.mvp.key == " " and "SPACE" or current.mvp.key:upper()
        love.graphics.printf(
            string.format("Top Upgrade: %s (+%.0f%%)", label, current.mvp.bonus * 100),
            0, calloutY, w, "center")
    end

    local bestLines = {}
    if current.newBest.wpm then bestLines[#bestLines + 1] = "New best WPM!" end
    if current.newBest.accuracy then bestLines[#bestLines + 1] = "New best accuracy!" end
    if current.newBest.streak then bestLines[#bestLines + 1] = "New best streak!" end
    if current.newBest.round then bestLines[#bestLines + 1] = "Furthest round yet!" end

    if #bestLines > 0 then
        Theme.setColor("success")
        love.graphics.setFont(Theme.font("body"))
        love.graphics.printf(table.concat(bestLines, "   "), 0, calloutY + 20, w, "center")
    end

    for i, b in ipairs(current.buttons) do
        drawButton(b, current.hoverIndex == i or current.selected == i)
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function VictoryState.keypressed(key)
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

function VictoryState.mousemoved(x, y)
    if not current then return end
    current.hoverIndex = nil
    for i, b in ipairs(current.buttons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            current.hoverIndex = i
            current.selected = i
        end
    end
end

function VictoryState.mousepressed(x, y, button)
    if button ~= 1 then return end
    local b = buttonAt(x, y)
    if b and b.action then
        Audio.playSfx("confirm")
        b.action()
    end
end

return VictoryState
