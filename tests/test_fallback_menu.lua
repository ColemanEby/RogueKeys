-- tests/test_fallback_menu.lua
-- Headless coverage for the fallback menu state.
--
-- NOTE: draw() and primary-button mousepressed() are intentionally NOT
-- exercised here. Under --test, _G.HEADLESS is true and Theme.font() returns
-- nil; FallbackMenuState.draw() calls love.graphics.setFont(nil), which
-- segfaults the LOVE process uncatchably. Primary-button mousepressed() hits
-- Theme.font("body"):getHeight() on nil and errors. These paths are only safe
-- with a real graphics context.
--
-- The menu selection and debug flag are private upvalues. Tests can mutate
-- both through keypressed(), but the public API cannot restore the debug flag
-- to a known value, so teardown uses debug.getupvalue/setupvalue by name.

local H = require("tests/helpers")
local StateManager = require("engine/stateManager")
local FallbackMenuState = require("states/fallbackMenuState")

local T = {}

local originalSwitch, originalQuit
local switchCalls, switchState, quitCalls

local function findUpvalue(fn, targetName)
    local index = 1
    while true do
        local name, value = debug.getupvalue(fn, index)
        if name == nil then
            H.fail("could not find upvalue '" .. targetName .. "'")
        end
        if name == targetName then return index, value end
        index = index + 1
    end
end

local function getUpvalue(fn, targetName)
    local _, value = findUpvalue(fn, targetName)
    return value
end

local function setUpvalue(fn, targetName, value)
    local index = findUpvalue(fn, targetName)
    local name = debug.setupvalue(fn, index, value)
    if name == nil then
        H.fail("could not restore upvalue '" .. targetName .. "'")
    end
end

local pristineSelectedItem = getUpvalue(FallbackMenuState.keypressed, "selectedItem")
local pristineShowDebugInfo = getUpvalue(FallbackMenuState.keypressed, "showDebugInfo")

local function resetRecorder()
    switchCalls = 0
    switchState = nil
    quitCalls = 0
end

-- Probe which menu entry is currently selected by firing the confirm key and
-- observing which stubbed action runs. selectedItem is module-local and shared,
-- so tests must discover the current position instead of assuming it.
local function probeSelection(state)
    resetRecorder()
    state.keypressed("return")
    if switchCalls == 1 then return 1 end
    if quitCalls == 1 then return 2 end
    H.fail("probeSelection: expected exactly one action, got switch=" ..
        tostring(switchCalls) .. ", quit=" .. tostring(quitCalls))
end

-- Drive selection to the requested 1-based menu entry. With only two entries,
-- a single "up" press toggles to the other item, so this is a one-key move at
-- most.
local function ensureSelection(state, target)
    local current = probeSelection(state)
    if current ~= target then
        state.keypressed("up")
    end
    resetRecorder()
end

function T.setup()
    originalSwitch = StateManager.switch
    originalQuit = love.event.quit
    resetRecorder()

    StateManager.switch = function(name)
        switchCalls = switchCalls + 1
        switchState = name
    end

    love.event.quit = function()
        quitCalls = quitCalls + 1
    end
end

function T.teardown()
    setUpvalue(FallbackMenuState.keypressed, "selectedItem", pristineSelectedItem)
    setUpvalue(FallbackMenuState.keypressed, "showDebugInfo", pristineShowDebugInfo)
    StateManager.switch = originalSwitch
    love.event.quit = originalQuit
end

function T.construction_returns_expected_table()
    local State = require("states/fallbackMenuState")
    H.equal(State.name, "FallbackMenuState")
    H.isType(State.enter, "function")
    H.isType(State.draw, "function")
    H.isType(State.keypressed, "function")
    H.isType(State.mousepressed, "function")
end

function T.createState_wrapping_supplies_full_contract_and_update_is_safe()
    local State = StateManager.createState(FallbackMenuState)
    H.isType(State.enter, "function", '"enter" should be a function')
    H.isType(State.exit, "function", '"exit" should be a function')
    H.isType(State.update, "function", '"update" should be a function')
    H.isType(State.draw, "function", '"draw" should be a function')
    H.isType(State.keypressed, "function", '"keypressed" should be a function')
    H.isType(State.keyreleased, "function", '"keyreleased" should be a function')
    H.isType(State.textinput, "function", '"textinput" should be a function')
    H.isType(State.resize, "function", '"resize" should be a function')

    H.succeeds(function() State.exit() end, '"exit" should be safe')
    H.succeeds(function() State.update(1 / 60) end, '"update" should be safe')
    H.succeeds(function() State.keyreleased("escape") end,
        '"keyreleased" should be safe')
    H.succeeds(function() State.textinput("a") end, '"textinput" should be safe')
    H.succeeds(function() State.resize(1280, 720) end, '"resize" should be safe')
end

function T.enter_is_safe_headless()
    local State = StateManager.createState(require("states/fallbackMenuState"))
    H.succeeds(function() State.enter() end)
end

function T.up_and_down_wrap_around_two_entries()
    local State = StateManager.createState(require("states/fallbackMenuState"))

    ensureSelection(State, 1)
    State.keypressed("return")
    H.equal(switchState, "roundState", "starting at item 1, return switches to roundState")
    H.equal(quitCalls, 0)

    resetRecorder()
    State.keypressed("up")
    State.keypressed("return")
    H.equal(quitCalls, 1, "up from item 1 moves to item 2 (Exit Game)")
    H.equal(switchCalls, 0)

    resetRecorder()
    State.keypressed("up")
    State.keypressed("return")
    H.equal(switchState, "roundState", "up from item 2 wraps back to item 1")
    H.equal(quitCalls, 0)

    ensureSelection(State, 2)
    State.keypressed("return")
    H.equal(quitCalls, 1, "starting at item 2, return quits")
    H.equal(switchCalls, 0)

    resetRecorder()
    State.keypressed("down")
    State.keypressed("return")
    H.equal(switchState, "roundState", "down from item 2 moves to item 1")
    H.equal(quitCalls, 0)

    resetRecorder()
    State.keypressed("down")
    State.keypressed("return")
    H.equal(quitCalls, 1, "down from item 1 wraps back to item 2")
    H.equal(switchCalls, 0)
end

function T.confirm_keys_fire_correct_action_for_each_entry()
    local State = StateManager.createState(require("states/fallbackMenuState"))
    local confirmKeys = { "return", "kpenter", "space" }

    for _, key in ipairs(confirmKeys) do
        ensureSelection(State, 1)
        State.keypressed(key)
        H.equal(switchState, "roundState", key .. " on item 1 should switch to roundState")
        H.equal(quitCalls, 0, key .. " on item 1 should not quit")

        resetRecorder()

        ensureSelection(State, 2)
        State.keypressed(key)
        H.equal(quitCalls, 1, key .. " on item 2 should quit")
        H.equal(switchCalls, 0, key .. " on item 2 should not switch")

        resetRecorder()
    end
end

function T.f1_is_safe_and_leaves_state_usable()
    local State = StateManager.createState(require("states/fallbackMenuState"))
    H.succeeds(function() State.keypressed("f1") end)

    ensureSelection(State, 1)
    State.keypressed("return")
    H.equal(switchState, "roundState", "navigation still works after f1")
    H.equal(quitCalls, 0)
end

function T.teardown_restores_module_local_state()
    local State = StateManager.createState(FallbackMenuState)

    State.keypressed("up")
    State.keypressed("f1")
    H.equal(getUpvalue(State.keypressed, "selectedItem"), 2,
        "up should mutate selectedItem before teardown")
    H.equal(getUpvalue(State.keypressed, "showDebugInfo"), false,
        "f1 should mutate showDebugInfo before teardown")

    T.teardown()

    H.equal(getUpvalue(State.keypressed, "selectedItem"), 1,
        "teardown should restore selectedItem")
    H.equal(getUpvalue(State.keypressed, "showDebugInfo"), true,
        "teardown should restore showDebugInfo")
end

function T.mousepressed_non_primary_button_is_noop()
    local State = StateManager.createState(require("states/fallbackMenuState"))
    ensureSelection(State, 1)
    H.succeeds(function() State.mousepressed(10, 10, 2) end)
    H.succeeds(function() State.mousepressed(10, 10, 3) end)
    H.equal(switchCalls, 0, "non-primary mouse button should not switch state")
    H.equal(quitCalls, 0, "non-primary mouse button should not quit")
end

return T
