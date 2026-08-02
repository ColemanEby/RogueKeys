-- states/creditsState.lua
-- Renders CREDITS.txt (the source of truth for third-party attribution) as a
-- scrollable block of text. The file is read at runtime rather than
-- duplicated here so the license ledger cannot drift from what actually
-- ships.

local StateManager = require("engine/stateManager")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")

local CreditsState = { name = "CreditsState", logical = true }

local MARGIN = 24
local LINE_H = 12
local TITLE_H = 30
local WHEEL_STEP = 3

local returnTo = "menuState"
local lines = {}
local scrollLines = 0

-- Pure text -> lines parser, exposed so tests can exercise the missing-file
-- and empty-file paths without touching disk.
function CreditsState._parseText(text)
    if not text then
        return { "CREDITS.txt not found." }
    end
    if text == "" then
        return { "(CREDITS.txt is empty)" }
    end

    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = (line:gsub("\r$", ""))
    end
    return out
end

local function loadLines()
    local ok, content = pcall(love.filesystem.read, "CREDITS.txt")
    if not ok then content = nil end
    return CreditsState._parseText(content)
end

local function viewportLines()
    local h = Screen.getHeight() - TITLE_H - MARGIN
    return math.max(1, math.floor(h / LINE_H))
end

local function maxScroll()
    return math.max(0, #lines - viewportLines())
end

local function clampScroll()
    scrollLines = math.max(0, math.min(scrollLines, maxScroll()))
end

function CreditsState.enter(params)
    params = params or {}
    returnTo = params.returnTo or "menuState"
    lines = loadLines()
    scrollLines = 0
end

function CreditsState.exit()
    lines = nil
end

function CreditsState.wheelmoved(_, wy)
    if wy ~= 0 then
        scrollLines = scrollLines - wy * WHEEL_STEP
        clampScroll()
    end
end

function CreditsState.update(dt) end

function CreditsState.draw()
    local w, h = Screen.getWidth(), Screen.getHeight()

    love.graphics.setFont(Theme.font("heading"))
    Theme.setColor("text")
    love.graphics.printf("Credits", 0, 8, w, "center")

    love.graphics.setFont(Theme.font("mono"))
    love.graphics.setScissor(MARGIN, TITLE_H, w - MARGIN * 2, h - TITLE_H - MARGIN)

    for i, line in ipairs(lines) do
        local y = TITLE_H + (i - 1 - scrollLines) * LINE_H
        if y > -LINE_H and y < h then
            Theme.setColor("textMuted")
            love.graphics.print(line, MARGIN, y)
        end
    end

    love.graphics.setScissor()

    love.graphics.setFont(Theme.font("small"))
    Theme.setColor("textDim")
    love.graphics.printf("Up/Down, PgUp/PgDn or the mouse wheel to scroll -- Escape to return",
        0, h - 14, w, "center")
end

function CreditsState.keypressed(key)
    if key == "escape" or key == "backspace" then
        StateManager.switch(returnTo)
    elseif key == "up" then
        scrollLines = scrollLines - 1
        clampScroll()
    elseif key == "down" then
        scrollLines = scrollLines + 1
        clampScroll()
    elseif key == "pageup" then
        scrollLines = scrollLines - viewportLines()
        clampScroll()
    elseif key == "pagedown" then
        scrollLines = scrollLines + viewportLines()
        clampScroll()
    elseif key == "home" then
        scrollLines = 0
    elseif key == "end" then
        scrollLines = maxScroll()
    end
end

return CreditsState
