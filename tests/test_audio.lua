-- tests/test_audio.lua
-- The audio suite runs with love.audio/love.sound entirely disabled (see
-- conf.lua's HEADLESS block), so it tests logic, not playback: volume
-- clamping/persistence, pitch-variance bounds, pool bookkeeping, and that
-- every public entry point is a safe no-op without a real device.

local H = require("tests/helpers")
local Audio = require("modules/audio/audio")

local T = {}

------------------------------------------------------------------
-- Volume clamping
------------------------------------------------------------------

function T.volume_clamps_to_0_1_for_each_category()
    for _, category in ipairs({ "master", "sfx", "music" }) do
        Audio.setVolume(category, 5)
        H.equal(Audio.getVolume(category), 1, category .. " should clamp to 1")

        Audio.setVolume(category, -5)
        H.equal(Audio.getVolume(category), 0, category .. " should clamp to 0")

        Audio.setVolume(category, 0.42)
        H.near(Audio.getVolume(category), 0.42, 1e-6, category .. " should hold a valid value")
    end

    -- restore defaults so later cases in this file see a known state
    Audio.setVolume("master", 1)
    Audio.setVolume("sfx", 1)
    Audio.setVolume("music", 1)
end

function T.volume_rejects_unknown_categories()
    local before = Audio.getVolume("master")
    Audio.setVolume("reverb", 0.9)
    H.equal(Audio.getVolume("reverb"), 1.0, "unknown category must not be created")
    H.equal(Audio.getVolume("master"), before, "unknown category must not disturb known ones")
end

------------------------------------------------------------------
-- Effective volume = category x master
------------------------------------------------------------------

function T.effective_volume_is_category_times_master()
    Audio.setVolume("master", 0.5)
    Audio.setVolume("sfx", 0.4)
    Audio.setVolume("music", 0.8)

    H.near(Audio._test.effectiveVolume("sfx"), 0.5 * 0.4, 1e-6)
    H.near(Audio._test.effectiveVolume("music"), 0.5 * 0.8, 1e-6)

    Audio.setVolume("master", 1)
    Audio.setVolume("sfx", 1)
    Audio.setVolume("music", 1)
end

function T.effective_volume_clamps_out_of_range_inputs_too()
    -- effectiveVolume is defensive even if called against an out-of-range
    -- value that slipped past setVolume's own clamp somehow.
    H.near(Audio._test.clamp01(3), 1)
    H.near(Audio._test.clamp01(-3), 0)
    H.near(Audio._test.clamp01(0.3), 0.3)
end

------------------------------------------------------------------
-- Every public function is a safe no-op headless
------------------------------------------------------------------

function T.public_api_never_raises_headless()
    H.succeeds(function() Audio.init() end)
    H.isFalse(Audio.isReady(), "no love.audio in the test runner -- must not claim readiness")

    H.succeeds(function() Audio.playSfx("coin") end)
    H.succeeds(function() Audio.playSfx("coin", { pitch = 1.1, volume = 0.5 }) end)
    H.succeeds(function() Audio.playSfx("not_a_real_sound") end)
    H.succeeds(function() Audio.playKey("linear", true) end)
    H.succeeds(function() Audio.playKey("tactile", false) end)
    H.succeeds(function() Audio.playKey("clicky", true) end)
    H.succeeds(function() Audio.playKey("unknown_switch", true) end)
    H.succeeds(function() Audio.playMusic("menu", { loop = true, fade = 0.5 }) end)
    H.succeeds(function() Audio.stopMusic(0.5) end)
    H.succeeds(function() Audio.stopMusic() end)
    H.succeeds(function() Audio.update(1 / 60) end)
    H.succeeds(function() Audio.setVolume("master", 0.5) end)
    H.succeeds(function() Audio.getVolume("master") end)

    Audio.setVolume("master", 1)
end

------------------------------------------------------------------
-- Volumes persist through ConfigManager and are re-read on init
------------------------------------------------------------------

function T.volumes_persist_and_are_reread_on_init()
    Audio.setVolume("sfx", 0.33)
    Audio.setVolume("music", 0.77)

    -- A fresh init must pick the persisted values back up rather than
    -- resetting to the compiled-in defaults.
    Audio.init()

    H.near(Audio.getVolume("sfx"), 0.33, 1e-6, "sfx volume was not re-read from ConfigManager")
    H.near(Audio.getVolume("music"), 0.77, 1e-6, "music volume was not re-read from ConfigManager")

    Audio.setVolume("sfx", 1)
    Audio.setVolume("music", 1)
    Audio.init()
end

------------------------------------------------------------------
-- Pitch variance helper
------------------------------------------------------------------

function T.pitch_variance_stays_in_documented_range()
    for _ = 1, 500 do
        local p = Audio._test.randomPitch()
        H.isTrue(p >= 0.95 and p <= 1.05, "pitch out of [0.95, 1.05]: " .. tostring(p))
    end
end

------------------------------------------------------------------
-- Source pool bookkeeping (plain tables, no real love.audio.Source)
------------------------------------------------------------------

local function fakeSource(playing)
    return { playing = playing, isPlaying = function(self) return self.playing end }
end

function T.pool_reuses_idle_items_instead_of_growing()
    local Pool = Audio._test.Pool
    local pool = Pool.new(4)

    local created = 0
    local factory = function()
        created = created + 1
        return fakeSource(true)
    end
    local isIdle = function(s) return not s:isPlaying() end

    local a = pool:acquire(factory, isIdle)
    H.equal(created, 1)
    H.equal(pool:size(), 1)

    -- a is still "playing" (busy) so a second acquire must create a new item.
    local b = pool:acquire(factory, isIdle)
    H.equal(created, 2)
    H.notEqual(a, b)

    -- Freeing `a` (mark idle) means the next acquire must reuse it, not grow.
    a.playing = false
    local c = pool:acquire(factory, isIdle)
    H.equal(created, 2, "pool must reuse an idle item instead of allocating")
    H.isTrue(c == a)
end

function T.pool_respects_its_cap_via_voice_stealing()
    local Pool = Audio._test.Pool
    local pool = Pool.new(2)

    local factory = function() return fakeSource(true) end
    local isIdle = function() return false end -- nothing is ever idle

    local a = pool:acquire(factory, isIdle)
    local b = pool:acquire(factory, isIdle)
    H.equal(pool:size(), 2)

    -- Everything is busy and the pool is at cap: acquiring again must steal
    -- (reuse) an existing item rather than exceeding the cap.
    local c = pool:acquire(factory, isIdle)
    H.equal(pool:size(), 2, "pool must not grow past its cap")
    H.isTrue(c == a or c == b, "stolen voice must be one of the pool's own items")

    for _ = 1, 20 do
        pool:acquire(factory, isIdle)
        H.isTrue(pool:size() <= 2, "pool must never exceed its cap under repeated pressure")
    end
end

------------------------------------------------------------------
-- Synthesis math is sane (structural verification -- there is no audio
-- device in this test run to listen with)
------------------------------------------------------------------

function T.envelope_sample_never_exceeds_its_amplitude()
    for _, waveform in ipairs({ "sine", "square" }) do
        for _, t in ipairs({ 0, 0.001, 0.01, 0.05, 0.2 }) do
            local v = Audio._test.envelopeSample(waveform, 440, t, 0.5, 10)
            H.isTrue(v >= -0.5 - 1e-9 and v <= 0.5 + 1e-9,
                waveform .. " sample out of amplitude bound at t=" .. t .. ": " .. tostring(v))
        end
    end
end

function T.clamp_sample_prevents_clipping_when_tones_are_summed()
    H.equal(Audio._test.clampSample(1.5), 1, "overshoot must clamp to 1")
    H.equal(Audio._test.clampSample(-1.5), -1, "undershoot must clamp to -1")
    H.near(Audio._test.clampSample(0.3), 0.3, 1e-9, "in-range values must pass through unchanged")
end

function T.sample_count_matches_duration_and_rate()
    H.equal(Audio._test.sampleCount(1, 22050), 22050)
    H.equal(Audio._test.sampleCount(0.05, 22050), math.floor(0.05 * 22050))
    H.isTrue(Audio._test.sampleCount(0.0001, 22050) >= 1, "even a tiny duration must produce at least one sample")
end

function T.key_switch_specs_are_distinguishable()
    local specs = Audio._test.keySpecs
    H.isTrue(specs.clicky.freq > specs.tactile.freq, "clicky should read brighter/higher than tactile")
    H.isTrue(specs.tactile.freq > specs.linear.freq, "tactile should read higher than linear")
    H.isTrue(specs.clicky.duration < specs.linear.duration, "clicky should be the sharpest/shortest transient")
    H.isTrue(specs.tactile.bump and not specs.linear.bump and not specs.clicky.bump,
        "only tactile should have the secondary bump envelope")
end

return T
