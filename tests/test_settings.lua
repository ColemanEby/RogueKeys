-- tests/test_settings.lua
-- Headless coverage for the settings/credits logic that doesn't need a
-- graphics context: volume clamping/persistence, the two-step reset-progress
-- confirmation, returnTo defaulting/routing, and the credits parser's
-- missing/empty-file edge cases.
--
-- love.filesystem.write/remove are monkeypatched during the destructive
-- cases so the suite never touches the real save/config directory.

local H = require("tests/helpers")

local ConfigManager = require("engine/configManager")
local Context = require("modules/game/context")
local SettingsState = require("states/settingsState")
local CreditsState = require("states/creditsState")

local T = {}

function T.volume_clamps_to_0_1_and_persists_through_config()
    -- The save directory is identity-based, not worktree-based, so this is
    -- the *real* config dir shared by every agent's `--test` run. Mocking
    -- write() only protects the writes made inside this test; ConfigManager
    -- keeps the mutated value in memory afterwards and love.quit() flushes
    -- every config unconditionally, so the original value must be restored
    -- before this test returns or it would corrupt a shared file on exit.
    local original = ConfigManager:get("audio.sfxVolume", 1.0)
    local realWrite = love.filesystem.write
    love.filesystem.write = function() return true end

    SettingsState._setVolume("audio.sfxVolume", "sfx", 5)
    H.near(ConfigManager:get("audio.sfxVolume", -1), 1.0)

    SettingsState._setVolume("audio.sfxVolume", "sfx", -5)
    H.near(ConfigManager:get("audio.sfxVolume", -1), 0.0)

    SettingsState._setVolume("audio.sfxVolume", "sfx", 0.42)
    H.near(ConfigManager:get("audio.sfxVolume", -1), 0.42)

    love.filesystem.write = realWrite
    ConfigManager:set("audio.sfxVolume", original)
end

function T.returnTo_defaults_to_menuState_with_no_params()
    H.succeeds(function() SettingsState.enter() end)
    H.equal(SettingsState._getReturnTo(), "menuState")

    SettingsState.enter({})
    H.equal(SettingsState._getReturnTo(), "menuState")

    SettingsState.enter({ returnTo = "pauseState" })
    H.equal(SettingsState._getReturnTo(), "pauseState")

    SettingsState.enter() -- leave the module in its default state
end

function T.back_action_pops_only_when_returning_to_pause()
    H.isTrue(SettingsState._backAction("pauseState").usesPop)
    H.isFalse(SettingsState._backAction("menuState").usesPop)
end

function T.reset_progress_requires_two_explicit_steps()
    local realRemove = love.filesystem.remove
    local removedPaths = {}
    love.filesystem.remove = function(path)
        removedPaths[#removedPaths + 1] = path
        return true
    end

    Context.reset()
    local before = Context.player()
    before.totalMoney = 999999

    SettingsState.enter()
    H.equal(SettingsState._getMode(), "settings")

    -- A single activation only arms the confirmation; nothing is destroyed.
    SettingsState._requestReset()
    H.equal(SettingsState._getMode(), "confirmReset")
    H.equal(Context.player().totalMoney, 999999, "arming the confirmation must not destroy progress")
    H.equal(#removedPaths, 0)

    -- Cancelling must not destroy anything either.
    SettingsState._cancelReset()
    H.equal(SettingsState._getMode(), "settings")
    H.equal(Context.player().totalMoney, 999999)

    -- The explicit second step is the only thing that resets.
    SettingsState._requestReset()
    SettingsState._confirmResetYes()
    H.equal(SettingsState._getMode(), "settings")
    H.notEqual(Context.player().totalMoney, 999999, "confirmed reset should replace the player")
    H.isTrue(#removedPaths >= 1, "confirmed reset should attempt to delete the save file")

    love.filesystem.remove = realRemove
    Context.reset()
end

function T.confirm_reset_yes_is_a_noop_outside_confirm_mode()
    local realRemove = love.filesystem.remove
    love.filesystem.remove = function() return true end

    Context.reset()
    local before = Context.player()
    before.totalMoney = 12345

    SettingsState.enter() -- mode == "settings"
    SettingsState._confirmResetYes() -- not armed; must do nothing
    H.equal(Context.player().totalMoney, 12345)

    love.filesystem.remove = realRemove
    Context.reset()
end

function T.credits_parser_handles_missing_and_empty_file()
    H.succeeds(function() CreditsState._parseText(nil) end)
    H.succeeds(function() CreditsState._parseText("") end)

    local missing = CreditsState._parseText(nil)
    H.isTrue(#missing >= 1, "missing file should still produce a displayable line")

    local empty = CreditsState._parseText("")
    H.isTrue(#empty >= 1, "empty file should still produce a displayable line")
end

function T.credits_parser_splits_lines_and_strips_carriage_returns()
    local lines = CreditsState._parseText("one\r\ntwo\nthree")
    H.equal(#lines, 3)
    H.equal(lines[1], "one")
    H.equal(lines[2], "two")
    H.equal(lines[3], "three")
end

return T
