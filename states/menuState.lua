-- states/menuState.lua
-- Main menu: the first screen a player sees. Draws on the 640x360 logical
-- canvas so it stays crisp at any window size.

local StateManager = require("engine/stateManager")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local Background = require("modules/ui/background")

local MenuState = {
    name = "MenuState",
    logical = true,
}

-- Other units are adding these states in parallel and lazy-load by name, so a
-- target that hasn't landed yet in this worktree must not hard-crash the menu.
local function safeSwitch(name, opts)
    local ok, err = pcall(StateManager.switch, name, opts)
    if not ok and _G.DEBUG_MODE then
        print("MenuState: failed to switch to '" .. tostring(name) .. "': " .. tostring(err))
    end
end

local menuItems = {
    { text = "Start Run",     action = function() safeSwitch("roundState") end },
    { text = "Keyboard Shop", action = function() safeSwitch("shopState", { returnTo = "menuState" }) end },
    { text = "Statistics",    action = function() safeSwitch("statsState") end },
    { text = "Settings",      action = function() safeSwitch("settingsState") end },
    { text = "Credits",       action = function() safeSwitch("creditsState") end },
    { text = "Quit",          action = function() love.event.quit() end },
}

-- Layout, in logical (640x360) pixels.
local TITLE_Y = 26
local TAGLINE_Y = 56
local PANEL_Y = 86
local PANEL_WIDTH = 210
local ITEM_HEIGHT = 27
local PANEL_PADDING = Theme.spacing.md

local FADE_DURATION = 0.25

local selectedItem = 1
local hoveredItem = nil
local fadeTimer = 0
local animTime = 0

local function panelHeight()
    return #menuItems * ITEM_HEIGHT + PANEL_PADDING * 2
end

-- Shared between draw and hit-testing so click targets always match what is
-- on screen.
local function computeItemRects()
    local panelX = (Screen.getWidth() - PANEL_WIDTH) / 2
    local rects = {}
    for i in ipairs(menuItems) do
        rects[i] = {
            x = panelX + PANEL_PADDING,
            y = PANEL_Y + PANEL_PADDING + (i - 1) * ITEM_HEIGHT,
            w = PANEL_WIDTH - PANEL_PADDING * 2,
            h = ITEM_HEIGHT,
        }
    end
    return rects, panelX
end

function MenuState.enter()
    selectedItem = 1
    hoveredItem = nil
    fadeTimer = 0
    animTime = 0
end

function MenuState.update(dt)
    fadeTimer = math.min(FADE_DURATION, fadeTimer + dt)
    animTime = animTime + dt
end

local function drawTitle(alpha)
    love.graphics.setFont(Theme.font("display"))
    love.graphics.setColor(Theme.color("accent", alpha))
    love.graphics.printf("ROGUEKEYS", 0, TITLE_Y, Screen.getWidth(), "center")

    love.graphics.setFont(Theme.font("small"))
    love.graphics.setColor(Theme.color("textMuted", alpha))
    love.graphics.printf("A Typing Roguelite", 0, TAGLINE_Y, Screen.getWidth(), "center")
end

local function drawPanelBackdrop(panelX, alpha)
    love.graphics.setColor(Theme.color("panel", 0.9 * alpha))
    love.graphics.rectangle("fill", panelX, PANEL_Y, PANEL_WIDTH, panelHeight())
    love.graphics.setColor(Theme.color("border", alpha))
    love.graphics.rectangle("line", panelX, PANEL_Y, PANEL_WIDTH, panelHeight())
end

local function drawMenuItem(item, rect, isSelected, isHovered, alpha, caretOffset)
    if isSelected then
        love.graphics.setColor(Theme.color("accent", 0.2 * alpha))
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    elseif isHovered then
        love.graphics.setColor(Theme.color("panelLight", 0.8 * alpha))
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    end

    local font = Theme.font("body")
    love.graphics.setFont(font)

    if isSelected then
        -- Filled caret, bobbing gently to keep the menu feeling alive at rest.
        love.graphics.setColor(Theme.color("accent", alpha))
        local cx = rect.x + 8 + caretOffset
        local cy = rect.y + rect.h / 2
        love.graphics.polygon("fill", cx - 3, cy - 4, cx - 3, cy + 4, cx + 4, cy)
        love.graphics.setColor(Theme.color("text", alpha))
    else
        love.graphics.setColor(Theme.color("textMuted", alpha))
    end

    love.graphics.printf(item.text, rect.x, rect.y + (rect.h - font:getHeight()) / 2, rect.w, "center")
end

function MenuState.draw()
    local alpha = fadeTimer / FADE_DURATION

    Background.draw(animTime)
    drawTitle(alpha)

    local rects, panelX = computeItemRects()
    drawPanelBackdrop(panelX, alpha)

    local caretOffset = math.sin(animTime * 4) * 2
    for i, item in ipairs(menuItems) do
        drawMenuItem(item, rects[i], i == selectedItem, i == hoveredItem, alpha, caretOffset)
    end

    love.graphics.setFont(Theme.font("small"))
    love.graphics.setColor(Theme.color("textDim", alpha))
    love.graphics.printf("Up/Down: Select   Enter: Confirm   Mouse: Click",
        0, Screen.getHeight() - 24, Screen.getWidth(), "center")

    -- Fade in from the background color rather than fading the canvas clear
    -- itself, since main.lua already clears the logical canvas opaquely.
    if alpha < 1 then
        love.graphics.setColor(Theme.color("base", 1 - alpha))
        love.graphics.rectangle("fill", 0, 0, Screen.getWidth(), Screen.getHeight())
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState.keypressed(key)
    if key == "up" then
        selectedItem = selectedItem - 1
        if selectedItem < 1 then selectedItem = #menuItems end
    elseif key == "down" then
        selectedItem = selectedItem + 1
        if selectedItem > #menuItems then selectedItem = 1 end
    elseif key == "return" or key == "kpenter" or key == "space" then
        if menuItems[selectedItem].action then
            menuItems[selectedItem].action()
        end
    end
end

function MenuState.mousemoved(x, y)
    local rects = computeItemRects()
    hoveredItem = nil
    for i, rect in ipairs(rects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            hoveredItem = i
            break
        end
    end
end

function MenuState.mousepressed(x, y, button)
    if button ~= 1 then return end

    local rects = computeItemRects()
    for i, rect in ipairs(rects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            selectedItem = i
            if menuItems[i].action then menuItems[i].action() end
            break
        end
    end
end

return MenuState
