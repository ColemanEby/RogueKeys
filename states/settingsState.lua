-- states/settingsState.lua
-- Persistent settings: audio, video and gameplay toggles, plus the
-- destructive "reset progress" flow. Every value is read through
-- ConfigManager with a default and written back with ConfigManager:set, so
-- this screen works whether or not the corresponding config keys have been
-- seeded elsewhere yet.

local StateManager = require("engine/stateManager")
local ConfigManager = require("engine/configManager")
local Audio = require("modules/audio/audio")
local Context = require("modules/game/context")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")

local SettingsState = { name = "SettingsState", logical = true }

local PANEL_X, PANEL_W = 60, 520
local ROW_H = 28
local ROW_START_Y = 46
local SLIDER_W = 180

local LAYOUTS = { "qwerty", "dvorak" }

local returnTo = "menuState"
local mode = "settings" -- "settings" | "confirmReset"
local selectedRow = 1
local confirmSelected = 2 -- default to "Cancel" so a stray Enter is harmless
local draggingRow = nil
local cachedRows = nil

-- ---- config helpers ------------------------------------------------------

local function getNumber(path, default)
    local v = ConfigManager:get(path, default)
    if type(v) == "number" then return v end
    return default
end

local function getBool(path, default)
    local v = ConfigManager:get(path, default)
    if type(v) == "boolean" then return v end
    return default
end

local function getString(path, default)
    local v = ConfigManager:get(path, default)
    if type(v) == "string" then return v end
    return default
end

local function optionIndex(options, value)
    for i, v in ipairs(options) do
        if v == value then return i end
    end
    return 1
end

-- Clamp + persist + apply live. This is exactly what the sliders call on
-- every drag and every keyboard nudge, and what tests exercise directly.
function SettingsState._setVolume(path, category, value)
    value = math.max(0, math.min(1, tonumber(value) or 0))
    ConfigManager:set(path, value)
    Audio.setVolume(category, value)
    return value
end

local function setFullscreen(v)
    ConfigManager:set("video.fullscreen", v)
    if love.window then
        pcall(love.window.setFullscreen, v, "desktop")
        if love.graphics then
            Screen.resize(love.graphics.getDimensions())
        end
    end
end

local function setVsync(v)
    ConfigManager:set("video.vsync", v)
    if love.window and love.window.setVSync then
        pcall(love.window.setVSync, v and 1 or 0)
    end
end

-- ---- rows ------------------------------------------------------------

local function buildRows()
    return {
        { id = "master", type = "slider", label = "Master Volume",
            get = function() return getNumber("audio.masterVolume", 1.0) end,
            set = function(v) SettingsState._setVolume("audio.masterVolume", "master", v) end },
        { id = "sfx", type = "slider", label = "SFX Volume",
            get = function() return getNumber("audio.sfxVolume", 1.0) end,
            set = function(v) SettingsState._setVolume("audio.sfxVolume", "sfx", v) end },
        { id = "music", type = "slider", label = "Music Volume",
            get = function() return getNumber("audio.musicVolume", 1.0) end,
            set = function(v) SettingsState._setVolume("audio.musicVolume", "music", v) end },
        { id = "fullscreen", type = "toggle", label = "Fullscreen",
            get = function() return getBool("video.fullscreen", false) end,
            set = function(v) setFullscreen(v) end },
        { id = "crt", type = "toggle", label = "CRT Filter",
            get = function() return getBool("video.crt", false) end,
            set = function(v) ConfigManager:set("video.crt", v) end },
        { id = "vsync", type = "toggle", label = "VSync",
            get = function() return getBool("video.vsync", true) end,
            set = function(v) setVsync(v) end },
        { id = "layout", type = "select", label = "Keyboard Layout", options = LAYOUTS,
            get = function() return getString("gameplay.layout", "qwerty") end,
            set = function(v) ConfigManager:set("gameplay.layout", v) end },
        { id = "reset", type = "button", label = "Reset Progress",
            action = function() SettingsState._requestReset() end },
        { id = "back", type = "button", label = "Back",
            action = function() SettingsState._goBack() end },
    }
end

local function getRows()
    cachedRows = cachedRows or buildRows()
    return cachedRows
end

-- ---- navigation --------------------------------------------------------

function SettingsState._getReturnTo()
    return returnTo
end

function SettingsState._getMode()
    return mode
end

-- Settings is pushed as an overlay on top of pauseState, so returning to it
-- must pop the state stack rather than switch (which would re-enter a fresh
-- pauseState and drop the underlying paused round). Pure, so it's trivial to
-- test without touching StateManager.
function SettingsState._backAction(target)
    return { usesPop = (target == "pauseState"), target = target }
end

function SettingsState._goBack()
    local action = SettingsState._backAction(returnTo)
    if action.usesPop and type(StateManager.pop) == "function" then
        local ok = pcall(StateManager.pop)
        if ok then return end
    end
    StateManager.switch(action.target)
end

-- ---- reset progress ------------------------------------------------------

local function deleteSaveFiles()
    if not love.filesystem then return end
    pcall(love.filesystem.remove, "save/player.lua")
    pcall(love.filesystem.remove, "save/player_backup.lua")
end

-- First step: only arms the confirmation. Nothing is destroyed here.
function SettingsState._requestReset()
    mode = "confirmReset"
    confirmSelected = 2
end

function SettingsState._cancelReset()
    mode = "settings"
end

-- Second, explicit step. The only path that actually destroys anything.
function SettingsState._confirmResetYes()
    if mode ~= "confirmReset" then return end
    deleteSaveFiles()
    Context.reset()
    mode = "settings"
end

-- ---- lifecycle ----------------------------------------------------------

function SettingsState.enter(params)
    params = params or {}
    returnTo = params.returnTo or "menuState"
    mode = "settings"
    selectedRow = 1
    confirmSelected = 2
    draggingRow = nil
    cachedRows = nil
end

function SettingsState.exit()
    draggingRow = nil
end

function SettingsState.update(dt) end

-- ---- drawing --------------------------------------------------------------

local function rowY(index)
    return ROW_START_Y + (index - 1) * ROW_H
end

local function drawSlider(x, y, w, value, focused)
    local trackH = 6
    local ty = y + (ROW_H - trackH) / 2 - Theme.spacing.xs

    Theme.setColor("panelLight")
    love.graphics.rectangle("fill", x, ty, w, trackH)
    Theme.setColor(focused and "accent" or "borderLight")
    love.graphics.rectangle("fill", x, ty, w * value, trackH)

    Theme.setColor("text")
    love.graphics.circle("fill", x + w * value, ty + trackH / 2, 4)
end

local function drawRows()
    local w = Screen.getWidth()

    love.graphics.setFont(Theme.font("heading"))
    Theme.setColor("text")
    love.graphics.printf("Settings", 0, 12, w, "center")

    love.graphics.setFont(Theme.font("body"))
    local valueX = PANEL_X + PANEL_W - SLIDER_W

    for i, row in ipairs(getRows()) do
        local y = rowY(i)
        local focused = (i == selectedRow)

        if focused then
            Theme.setColor("panel")
            love.graphics.rectangle("fill", PANEL_X - Theme.spacing.sm, y,
                PANEL_W + Theme.spacing.sm * 2, ROW_H - Theme.spacing.xs)
        end

        if row.type == "button" then
            local color = row.id == "reset" and "error" or (focused and "accent" or "text")
            Theme.setColor(color)
            love.graphics.printf(row.label, PANEL_X, y + Theme.spacing.xs, PANEL_W, "center")
        else
            Theme.setColor("text")
            love.graphics.print(row.label, PANEL_X, y + Theme.spacing.xs)

            if row.type == "slider" then
                drawSlider(valueX, y, SLIDER_W, row.get(), focused)
            elseif row.type == "toggle" then
                local on = row.get()
                Theme.setColor(on and "success" or "textDim")
                love.graphics.printf(on and "ON" or "OFF", valueX, y + Theme.spacing.xs, SLIDER_W, "right")
            elseif row.type == "select" then
                Theme.setColor("text")
                love.graphics.printf("< " .. tostring(row.get()) .. " >", valueX, y + Theme.spacing.xs,
                    SLIDER_W, "right")
            end
        end
    end
end

local function confirmDialogRect()
    local w, h = Screen.getWidth(), Screen.getHeight()
    local dw, dh = 320, 120
    return (w - dw) / 2, (h - dh) / 2, dw, dh
end

local function confirmButtonRect(index)
    local dx, dy, dw, dh = confirmDialogRect()
    local btnW = (dw - Theme.spacing.lg * 3) / 2
    local bx = dx + Theme.spacing.lg + (index - 1) * (btnW + Theme.spacing.lg)
    local by = dy + dh - 34
    return bx, by, btnW, 24
end

local function drawConfirmDialog()
    local w, h = Screen.getWidth(), Screen.getHeight()

    Theme.setColor("base", 0.85)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local dx, dy, dw, dh = confirmDialogRect()
    Theme.setColor("panel")
    love.graphics.rectangle("fill", dx, dy, dw, dh)
    Theme.setColor("error")
    love.graphics.rectangle("line", dx, dy, dw, dh)

    love.graphics.setFont(Theme.font("body"))
    Theme.setColor("text")
    love.graphics.printf("Reset all progress? This cannot be undone.",
        dx + Theme.spacing.md, dy + Theme.spacing.md, dw - Theme.spacing.md * 2, "center")

    local labels = { "Yes, delete it", "Cancel" }
    for i, label in ipairs(labels) do
        local bx, by, bw, bh = confirmButtonRect(i)
        if i == confirmSelected then
            Theme.setColor("panelLight")
            love.graphics.rectangle("fill", bx, by, bw, bh)
        end
        Theme.setColor(i == 1 and "error" or "text")
        love.graphics.printf(label, bx, by + Theme.spacing.xs, bw, "center")
    end
end

function SettingsState.draw()
    drawRows()
    if mode == "confirmReset" then
        drawConfirmDialog()
    end
end

-- ---- input ----------------------------------------------------------------

function SettingsState.keypressed(key)
    if mode == "confirmReset" then
        if key == "left" or key == "right" or key == "tab" then
            confirmSelected = (confirmSelected == 1) and 2 or 1
        elseif key == "return" or key == "kpenter" or key == "space" then
            if confirmSelected == 1 then
                SettingsState._confirmResetYes()
            else
                SettingsState._cancelReset()
            end
        elseif key == "escape" then
            SettingsState._cancelReset()
        end
        return
    end

    local list = getRows()
    if key == "up" then
        selectedRow = selectedRow - 1
        if selectedRow < 1 then selectedRow = #list end
    elseif key == "down" then
        selectedRow = selectedRow + 1
        if selectedRow > #list then selectedRow = 1 end
    elseif key == "left" or key == "right" then
        local row = list[selectedRow]
        if row.type == "slider" then
            row.set(row.get() + ((key == "left") and -0.05 or 0.05))
        elseif row.type == "toggle" then
            row.set(not row.get())
        elseif row.type == "select" then
            local idx = optionIndex(row.options, row.get())
            idx = idx + ((key == "right") and 1 or -1)
            if idx < 1 then idx = #row.options end
            if idx > #row.options then idx = 1 end
            row.set(row.options[idx])
        end
    elseif key == "return" or key == "kpenter" or key == "space" then
        local row = list[selectedRow]
        if row.type == "toggle" then
            row.set(not row.get())
        elseif row.type == "button" then
            row.action()
        elseif row.type == "select" then
            local idx = optionIndex(row.options, row.get())
            row.set(row.options[(idx % #row.options) + 1])
        end
    elseif key == "escape" then
        SettingsState._goBack()
    end
end

local function rowHit(x, y)
    local list = getRows()
    for i in ipairs(list) do
        local top = rowY(i)
        if y >= top and y <= top + ROW_H - Theme.spacing.xs
            and x >= PANEL_X - Theme.spacing.sm and x <= PANEL_X + PANEL_W + Theme.spacing.sm then
            return i
        end
    end
    return nil
end

local function sliderValueAt(x)
    local trackX = PANEL_X + PANEL_W - SLIDER_W
    return math.max(0, math.min(1, (x - trackX) / SLIDER_W))
end

function SettingsState.mousepressed(x, y, button)
    if button ~= 1 then return end

    if mode == "confirmReset" then
        for i = 1, 2 do
            local bx, by, bw, bh = confirmButtonRect(i)
            if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
                confirmSelected = i
                if i == 1 then SettingsState._confirmResetYes() else SettingsState._cancelReset() end
                return
            end
        end
        return
    end

    local hit = rowHit(x, y)
    if not hit then return end
    selectedRow = hit

    local row = getRows()[hit]
    local valueX = PANEL_X + PANEL_W - SLIDER_W

    if row.type == "slider" and x >= valueX then
        row.set(sliderValueAt(x))
        draggingRow = hit
    elseif row.type == "toggle" then
        row.set(not row.get())
    elseif row.type == "select" then
        local idx = optionIndex(row.options, row.get())
        row.set(row.options[(idx % #row.options) + 1])
    elseif row.type == "button" then
        row.action()
    end
end

function SettingsState.mousemoved(x, y)
    if draggingRow then
        local row = getRows()[draggingRow]
        if row and row.type == "slider" then
            row.set(sliderValueAt(x))
        end
        return
    end

    if mode == "settings" then
        local hit = rowHit(x, y)
        if hit then selectedRow = hit end
    end
end

function SettingsState.mousereleased(x, y, button)
    draggingRow = nil
end

return SettingsState
