-- tests/test_config.lua
-- Regression tests for engine/configManager.lua: the serializer swap to
-- modules/util/serialize, config self-healing, the new settings schema, write
-- amplification on set(), path-walking hardening, and deterministic layout ids.
--
-- ConfigManager is a singleton already initialized by main.lua's headless
-- bootstrap (runTests() calls ConfigManager:init() before the suite runs), and
-- it persists to the real LOVE save directory. To avoid disturbing real
-- config files (which other units' tests/screens may read) or colliding with
-- other concurrently-running test processes sharing the same save identity,
-- every test here operates on uniquely-named, throwaway top-level config keys
-- and always cleans up -- even on failure -- via a pcall wrapper.

local H = require("tests/helpers")
local ConfigManager = require("engine/configManager")
local Serialize = require("modules/util/serialize")

local T = {}

local counter = 0
local function tempName()
    counter = counter + 1
    local t = (love.timer and love.timer.getTime()) or os.time()
    return string.format("_test_cfg_%d_%d_%d", math.floor(t * 1000), counter, math.random(1, 1e6))
end

-- Runs fn(name), always cleaning up any config state / file left under `name`
-- afterwards, then re-raises fn's error (if any) so failures still surface.
local function withTempConfig(fn)
    local name = tempName()
    local ok, err = pcall(fn, name)

    ConfigManager.configs[name] = nil
    ConfigManager.defaultConfigs[name] = nil
    ConfigManager.dirty[name] = nil
    pcall(function() love.filesystem.remove("config/" .. name .. ".lua") end)

    if not ok then error(err, 0) end
end

function T.hostile_strings_round_trip_through_save_and_load()
    withTempConfig(function(name)
        local original = {
            quote = 'he said "hi"',
            backslash = "a\\b\\c",
            newline = "line1\nline2\ttabbed",
            mixed = 'back\\slash and "quote" and \nnewline',
        }

        ConfigManager.configs[name] = original
        H.isTrue(ConfigManager:saveConfig(name), "saveConfig should succeed")

        ConfigManager.configs[name] = nil
        H.isTrue(ConfigManager:loadConfig(name), "loadConfig should succeed on the file we just wrote")

        H.deepEqual(ConfigManager.configs[name], original)
    end)
end

function T.keyboard_layout_tree_round_trips()
    withTempConfig(function(name)
        local original = {
            qwerty = {
                name = "QWERTY",
                description = 'Standard "US" layout',
                layout = {
                    { { key = "Q", w = 1 }, { key = "W", w = 1 }, { key = "E", w = 1 } },
                    { { key = "A", w = 1 }, { key = "S", w = 1 } },
                    { { key = "Space", w = 5 } },
                },
            },
        }

        ConfigManager.configs[name] = original
        H.isTrue(ConfigManager:saveConfig(name))

        ConfigManager.configs[name] = nil
        H.isTrue(ConfigManager:loadConfig(name))

        local restored = ConfigManager.configs[name]
        H.deepEqual(restored, original)
        H.equal(restored.qwerty.layout[1][2].key, "W")
        H.equal(restored.qwerty.layout[3][1].w, 5)
        H.equal(#restored.qwerty.layout, 3)
    end)
end

function T.get_returns_default_when_any_segment_missing()
    H.equal(ConfigManager:get("nope.totally.missing", "fallback"), "fallback")
    H.equal(ConfigManager:get("audio.nope", "fallback"), "fallback")
    H.equal(ConfigManager:get("audio.masterVolume.tooDeep", "fallback"), "fallback")
    H.equal(ConfigManager:get("", "fallback"), "fallback")
    H.equal(ConfigManager:get(nil, "fallback"), "fallback")
end

function T.set_then_get_returns_new_value()
    withTempConfig(function(name)
        ConfigManager:set(name .. ".volume", 0.42)
        H.near(ConfigManager:get(name .. ".volume"), 0.42)
    end)
end

function T.set_on_deep_path_creates_intermediate_tables()
    withTempConfig(function(name)
        H.equal(ConfigManager.configs[name], nil)

        ConfigManager:set(name .. ".a.b.c", 42)

        H.equal(type(ConfigManager.configs[name]), "table")
        H.equal(type(ConfigManager.configs[name].a), "table")
        H.equal(type(ConfigManager.configs[name].a.b), "table")
        H.equal(ConfigManager.configs[name].a.b.c, 42)
        H.equal(ConfigManager:get(name .. ".a.b.c"), 42)
    end)
end

function T.set_marks_dirty_but_does_not_save_immediately()
    withTempConfig(function(name)
        ConfigManager:set(name .. ".x", 1)
        H.isTrue(ConfigManager.dirty[name], "set() must mark its top-level config dirty")
        H.isFalse(love.filesystem.getInfo("config/" .. name .. ".lua") ~= nil,
            "set() must not write to disk by itself")

        ConfigManager:flush()
        H.isTrue(love.filesystem.getInfo("config/" .. name .. ".lua") ~= nil,
            "flush() must persist dirty configs")
        H.equal(ConfigManager.dirty[name], nil, "flush() must clear the dirty flag once saved")
    end)
end

function T.corrupt_config_file_falls_back_to_defaults_and_is_rewritten()
    withTempConfig(function(name)
        ConfigManager.defaultConfigs[name] = { foo = "bar", nested = { n = 1 } }
        ConfigManager.configs[name] = { foo = "bar", nested = { n = 1 } }

        local path = "config/" .. name .. ".lua"
        love.filesystem.write(path, "this is not valid lua {{{ ]] ==")

        local ok = ConfigManager:loadConfig(name)
        H.isFalse(ok, "loadConfig must report failure for unparsable content")

        -- Fell back to the default in memory...
        H.equal(ConfigManager.configs[name].foo, "bar")
        H.equal(ConfigManager.configs[name].nested.n, 1)

        -- ...and the broken file on disk was rewritten with something loadable,
        -- rather than left broken forever.
        local content = love.filesystem.read(path)
        local reparsed, err = Serialize.decode(content)
        H.isTrue(reparsed ~= nil, "rewritten config must parse: " .. tostring(err))
        H.equal(reparsed.foo, "bar")
        H.equal(reparsed.nested.n, 1)
    end)
end

function T.keyboard_layout_ids_are_sorted_and_stable()
    local a = ConfigManager:getKeyboardLayoutIds()
    local b = ConfigManager:getKeyboardLayoutIds()

    H.deepEqual(a, b)

    for i = 2, #a do
        H.isTrue(a[i - 1] < a[i], "layout ids must be sorted: " .. a[i - 1] .. " vs " .. a[i])
    end

    -- The two built-in layouts must always be present.
    local seen = {}
    for _, id in ipairs(a) do seen[id] = true end
    H.isTrue(seen.qwerty, "qwerty layout missing")
    H.isTrue(seen.dvorak, "dvorak layout missing")
end

function T.new_settings_schema_has_documented_defaults()
    local d = ConfigManager.defaultConfigs

    H.near(d.audio.masterVolume, 1.0)
    H.near(d.audio.sfxVolume, 0.8)
    H.near(d.audio.musicVolume, 0.5)

    H.isFalse(d.video.fullscreen)
    H.equal(d.video.scaleMode, "integer")
    H.isFalse(d.video.crt)
    H.isTrue(d.video.vsync)

    H.equal(d.gameplay.layout, "qwerty")
    H.isTrue(d.gameplay.showKeyboard)

    H.equal(d.progression.baseRequiredScore, 20)
end

function T.new_settings_keys_are_readable_through_get()
    -- Exercised through the live singleton (already initialized by the test
    -- bootstrap), proving the schema actually reaches self.configs and isn't
    -- only present in defaultConfigs.
    H.isTrue(type(ConfigManager:get("audio.masterVolume")) == "number")
    H.isTrue(type(ConfigManager:get("video.scaleMode")) == "string")
    H.isTrue(type(ConfigManager:get("gameplay.layout")) == "string")
    H.equal(ConfigManager:get("progression.baseRequiredScore", "MISSING"), 20)
end

return T
