-- states/pauseState.lua
-- In-run pause overlay. Meant to be pushed on top of the active round with
-- StateManager.push("pauseState") and dismissed with StateManager.pop(), so
-- the round underneath keeps its state and simply resumes. push/pop are being
-- added in parallel (unit 4); every call against that API is guarded so this
-- state degrades to switch()-based navigation instead of crashing if they are
-- not there yet (e.g. when entered directly for --shot pauseState).

local StateManager = require("engine/stateManager")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local Context = require("modules/game/context")

local PauseState = { name = "PauseState", logical = true }

local PANEL_W, PANEL_H = 220, 130
local ROW_H = 26
local ROWS_TOP = Theme.spacing.xxl
local OPTION_COUNT = 3

local selected = 1
local confirmingAbandon = false

local function panelRect()
    local w, h = Screen.getWidth(), Screen.getHeight()
    return (w - PANEL_W) / 2, (h - PANEL_H) / 2, PANEL_W, PANEL_H
end

local function rowRect(index)
    local px, py = panelRect()
    local x = px + Theme.spacing.md
    local y = py + ROWS_TOP + (index - 1) * ROW_H
    return x, y, PANEL_W - Theme.spacing.md * 2, ROW_H - Theme.spacing.xs
end

local function labelFor(index)
    if index == 3 and confirmingAbandon then
        return "Really abandon? (Enter)"
    end
    return ({ "Resume", "Settings", "Abandon Run" })[index]
end

-- Resume the underlying state. Falls back to switching straight to the round
-- if this state was entered without ever being pushed.
function PauseState.resume()
    if type(StateManager.pop) == "function" then
        local ok = pcall(StateManager.pop)
        if ok then return end
    end
    StateManager.switch("roundState")
end

local function goToSettings()
    local pushed = false
    if type(StateManager.push) == "function" then
        pushed = pcall(StateManager.push, "settingsState", { returnTo = "pauseState" })
    end
    if not pushed then
        StateManager.switch("settingsState")
    end
end

-- Abandoning a run must never pay out: no trainer:finish(), no
-- player:endSession(), no money awarded. Just drop the run and leave.
local function abandonRun()
    Context.clearRun()

    local ok = pcall(StateManager.switch, "gameOverState")
    if not ok then
        StateManager.switch("menuState")
    end
end

local function activate(index)
    if index == 1 then
        confirmingAbandon = false
        PauseState.resume()
    elseif index == 2 then
        confirmingAbandon = false
        goToSettings()
    elseif index == 3 then
        if confirmingAbandon then
            confirmingAbandon = false
            abandonRun()
        else
            confirmingAbandon = true
        end
    end
end

function PauseState.enter(params)
    selected = 1
    confirmingAbandon = false
end

function PauseState.update(dt) end

function PauseState.draw()
    local w, h = Screen.getWidth(), Screen.getHeight()

    Theme.setColor("base", 0.78)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local px, py, pw, ph = panelRect()
    Theme.setColor("panel")
    love.graphics.rectangle("fill", px, py, pw, ph)
    Theme.setColor("border")
    love.graphics.rectangle("line", px, py, pw, ph)

    love.graphics.setFont(Theme.font("heading"))
    Theme.setColor("text")
    love.graphics.printf("Paused", px, py + Theme.spacing.sm, pw, "center")

    love.graphics.setFont(Theme.font("body"))
    local bodyHeight = Theme.font("body"):getHeight()
    for i = 1, OPTION_COUNT do
        local rx, ry, rw, rh = rowRect(i)

        if i == selected then
            Theme.setColor("panelLight")
            love.graphics.rectangle("fill", rx, ry, rw, rh)
        end

        if i == 3 and confirmingAbandon then
            Theme.setColor("error")
        elseif i == selected then
            Theme.setColor("accent")
        else
            Theme.setColor("text")
        end
        love.graphics.printf(labelFor(i), rx, ry + (rh - bodyHeight) / 2, rw, "center")
    end
end

function PauseState.keypressed(key)
    if key == "escape" then
        if confirmingAbandon then
            confirmingAbandon = false
        else
            PauseState.resume()
        end
    elseif key == "up" then
        confirmingAbandon = false
        selected = selected - 1
        if selected < 1 then selected = OPTION_COUNT end
    elseif key == "down" then
        confirmingAbandon = false
        selected = selected + 1
        if selected > OPTION_COUNT then selected = 1 end
    elseif key == "return" or key == "kpenter" or key == "space" then
        activate(selected)
    end
end

local function hitTest(x, y)
    for i = 1, OPTION_COUNT do
        local rx, ry, rw, rh = rowRect(i)
        if x >= rx and x <= rx + rw and y >= ry and y <= ry + rh then
            return i
        end
    end
    return nil
end

function PauseState.mousemoved(x, y)
    local hit = hitTest(x, y)
    if hit then selected = hit end
end

function PauseState.mousepressed(x, y, button)
    if button ~= 1 then return end
    local hit = hitTest(x, y)
    if hit then
        selected = hit
        activate(hit)
    end
end

return PauseState
