-- tests/test_foundation.lua
-- Smoke tests for the shared foundation modules. These are deliberately small:
-- their job is to prove the runner works and that the foundation contracts hold.

local H = require("tests/helpers")

local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local Context = require("modules/game/context")
local Audio = require("modules/audio/audio")
local Serialize = require("modules/util/serialize")

local T = {}

function T.theme_hex_parses_to_floats()
    local white = Theme.hex("#ffffff")
    H.near(white[1], 1.0)
    H.near(white[2], 1.0)
    H.near(white[3], 1.0)
    H.near(white[4], 1.0)

    local black = Theme.hex("#000000")
    H.near(black[1], 0.0)

    local withAlpha = Theme.hex("#ffffff80")
    H.near(withAlpha[4], 128 / 255, 1e-6)
end

function T.theme_color_lookup()
    local accent = Theme.color("accent")
    H.equal(#accent, 4, "color must be a 4-component table")

    local epic = Theme.color("rarity.epic")
    H.notEqual(epic[1], 1, "rarity.epic should not be the magenta fallback")

    local clicky = Theme.color("switch.clicky")
    H.isTrue(clicky[3] > clicky[1], "clicky switch should read blue")

    -- Unknown names fall back to magenta rather than nil.
    local missing = Theme.color("definitely_not_a_color")
    H.equal(missing[1], 1)
    H.equal(missing[2], 0)
    H.equal(missing[3], 1)
end

function T.theme_alpha_override_does_not_mutate_palette()
    local a = Theme.color("accent", 0.5)
    H.near(a[4], 0.5)

    local b = Theme.color("accent")
    H.near(b[4], 1.0, 1e-6, "palette entry was mutated by an alpha override")
end

function T.theme_rarity_order_is_complete()
    for _, name in ipairs(Theme.rarityOrder) do
        H.isTrue(Theme.rarity[name] ~= nil, "missing rarity color: " .. name)
    end
    H.equal(#Theme.rarityOrder, 5)
end

function T.screen_logical_dimensions()
    H.equal(Screen.getWidth(), 640)
    H.equal(Screen.getHeight(), 360)

    local w, h = Screen.getDimensions()
    H.equal(w, 640)
    H.equal(h, 360)

    -- 640x360 must scale integer-perfect into the common targets.
    H.equal(1280 / Screen.WIDTH, 2)
    H.equal(1920 / Screen.WIDTH, 3)
    H.equal(2560 / Screen.WIDTH, 4)
end

function T.screen_push_pop_are_safe_without_canvas()
    -- Headless: there is no canvas, and these must no-op rather than raise.
    H.succeeds(function() Screen.push() end)
    H.succeeds(function() Screen.pop() end)
    H.succeeds(function() Screen.resize(1280, 720) end)
end

function T.context_player_is_memoized()
    Context.reset()

    local a = Context.player()
    local b = Context.player()

    H.isTrue(a ~= nil, "Context.player() returned nil")
    H.isTrue(a == b, "Context.player() must return the same instance every call")

    Context.reset()
end

function T.context_pending_results_are_take_once()
    Context.reset()

    H.equal(Context.takePendingResults(), nil)

    Context.setPendingResults({ score = 42 })
    H.equal(Context.peekPendingResults().score, 42)

    local taken = Context.takePendingResults()
    H.equal(taken.score, 42)
    H.equal(Context.takePendingResults(), nil, "results must only be taken once")

    Context.reset()
end

function T.context_reset_clears_run_and_results()
    Context.setRun({ round = 3 })
    Context.setPendingResults({ score = 1 })
    Context.reset()

    H.equal(Context.run, nil)
    H.equal(Context.peekPendingResults(), nil)
end

function T.audio_volume_is_clamped()
    Audio.setVolume("sfx", 2.5)
    H.equal(Audio.getVolume("sfx"), 1)

    Audio.setVolume("sfx", -3)
    H.equal(Audio.getVolume("sfx"), 0)

    Audio.setVolume("sfx", 0.5)
    H.near(Audio.getVolume("sfx"), 0.5)

    -- Unknown categories are ignored, not created.
    Audio.setVolume("nonsense", 0.5)
    H.equal(Audio.getVolume("nonsense"), 1.0)
end

function T.audio_stub_calls_never_raise()
    H.succeeds(function() Audio.playSfx("coin") end)
    H.succeeds(function() Audio.playKey("clicky", true) end)
    H.succeeds(function() Audio.playMusic("menu", { loop = true }) end)
    H.succeeds(function() Audio.stopMusic(0.5) end)
    H.succeeds(function() Audio.update(1 / 60) end)
end

-- The whole reason serpent is vendored: the hand-rolled serializers dropped
-- numeric keys, which silently re-indexed sparse arrays and destroyed match
-- history ordering.
local function roundTrip(value)
    local chunk, err = Serialize.encode(value)
    H.isTrue(chunk ~= nil, "encode failed: " .. tostring(err))

    local restored, decodeErr = Serialize.decode(chunk)
    H.isTrue(restored ~= nil, "decode failed: " .. tostring(decodeErr))
    return restored
end

function T.serialize_round_trips_dense_arrays()
    local original = { 10, 20, 30 }
    local restored = roundTrip(original)

    H.deepEqual(restored, original)
    H.equal(#restored, 3)
end

function T.serialize_round_trips_sparse_arrays()
    local original = { [1] = "a", [3] = "c", [7] = "g" }
    local restored = roundTrip(original)

    H.equal(restored[1], "a")
    H.equal(restored[3], "c")
    H.equal(restored[7], "g")
    H.equal(restored[2], nil, "sparse hole was filled in -- indices shifted")
end

function T.serialize_round_trips_match_history_shape()
    local history = {}
    for i = 1, 5 do
        history[i] = { timestamp = 1000 + i, wpm = i * 10, accuracy = 90 + i, mistakes = i }
    end

    local restored = roundTrip(history)

    H.equal(#restored, 5)
    for i = 1, 5 do
        H.equal(restored[i].timestamp, 1000 + i, "history order lost at index " .. i)
        H.equal(restored[i].wpm, i * 10)
    end
end

function T.serialize_escapes_hostile_strings()
    local original = {
        quote = 'he said "hi"',
        backslash = "a\\b",
        newline = "line1\nline2",
        carriage = "line1\r\nline2",
        bracket = "]]==]",
        solo = "\\",
    }

    H.deepEqual(roundTrip(original), original)
end

function T.serialize_round_trips_mixed_tables()
    local original = {
        "first", "second",
        name = "keyboard",
        nested = { [1] = "x", [2] = "y", label = "row" },
    }

    local restored = roundTrip(original)
    H.deepEqual(restored, original)
    H.equal(restored[1], "first")
    H.equal(restored[2], "second")
end

function T.serialize_round_trips_the_keyboard_layout_config()
    -- The nested array-of-arrays-of-tables that the old serializer was most
    -- likely to corrupt.
    local original = {
        qwerty = {
            name = "QWERTY",
            description = 'Standard "US" layout',
            layout = {
                { { key = "Q", w = 1 }, { key = "W", w = 1 } },
                { { key = "Space", w = 5 } },
            },
        },
    }

    local restored = roundTrip(original)
    H.deepEqual(restored, original)
    H.equal(restored.qwerty.layout[1][2].key, "W")
    H.equal(restored.qwerty.layout[2][1].w, 5)
end

function T.serialize_decode_rejects_garbage()
    local value, err = Serialize.decode("this is not lua {{{")
    H.equal(value, nil)
    H.isTrue(err ~= nil, "expected an error message")

    value = Serialize.decode("")
    H.equal(value, nil)

    value = Serialize.decode("return 42")
    H.equal(value, nil, "non-table chunks must be rejected")
end

function T.serialize_decode_is_sandboxed()
    -- A corrupted or hostile save must not be able to reach the real globals.
    _G.__canary = "untouched"
    local value = Serialize.decode("return { hit = tostring(os) }")

    -- Either it fails outright or os resolves to nil inside the sandbox;
    -- what must never happen is it reaching the real os table.
    if value then
        H.notEqual(value.hit, tostring(os), "sandbox leaked the real os table")
    end
    H.equal(_G.__canary, "untouched")
    _G.__canary = nil
end

return T
