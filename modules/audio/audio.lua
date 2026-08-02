-- modules/audio/audio.lua
-- Audio facade. Owns volume state, procedurally synthesized fallback sounds,
-- source pooling, and music crossfade. Real assets drop in automatically --
-- see resources/sounds/README.md for the filenames this module looks for.
--
-- Contract (do not rename/reorder -- other units call this exactly):
--   Audio.init()                       -- called once from love.load
--   Audio.playSfx(name, opts)          -- opts = { pitch, volume }
--   Audio.playKey(switchType, correct) -- per-keystroke thock
--   Audio.playMusic(track, opts)       -- opts = { loop, fade }
--   Audio.stopMusic(fade)
--   Audio.setVolume(category, value)   -- "master" | "sfx" | "music"
--   Audio.getVolume(category)
--   Audio.update(dt)
--   Audio.isReady()

local Audio = {}

-- Every entry point must survive a headless run (no love.audio/love.sound,
-- e.g. `love . --test`) and the `--shot` path (a real audio device). Check
-- both flags, not just one: HEADLESS is the intent, love.audio/love.sound
-- existing is the actual capability.
local function audioAvailable()
    return not _G.HEADLESS and love ~= nil and love.audio ~= nil and love.sound ~= nil
end

-- Resolved once: love.math is never toggled at runtime (HEADLESS disables
-- audio/sound/joystick/physics/touch/video, not math), so there is nothing
-- to re-check on every call.
local randomFn = (love and love.math and love.math.random) or math.random

local function clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function clampSample(v)
    if v > 1 then return 1 end
    if v < -1 then return -1 end
    return v
end

-- 0.95..1.05: enough to keep a fast typist's key thocks from machine-gunning
-- into an identical repeated sample, subtle enough not to sound "wrong".
local function randomPitch()
    return 0.95 + randomFn() * 0.10
end

------------------------------------------------------------------
-- Volumes, backed by ConfigManager. Reading/writing works headlessly (it
-- only touches love.filesystem via ConfigManager, not love.audio), so
-- volumes persist and are testable without a real audio device.
------------------------------------------------------------------

local CONFIG_KEYS = {
    master = "audio.masterVolume",
    sfx = "audio.sfxVolume",
    music = "audio.musicVolume",
}

local volumes = {
    master = 1.0,
    sfx = 1.0,
    music = 1.0,
}

local function configManager()
    local ok, ConfigManager = pcall(require, "engine/configManager")
    if ok and ConfigManager then return ConfigManager end
    return nil
end

local function readConfigVolume(path, fallback)
    local CM = configManager()
    if not CM or not CM.get then return fallback end
    local ok, value = pcall(function() return CM:get(path, fallback) end)
    if ok and type(value) == "number" then return value end
    return fallback
end

local function writeConfigVolume(path, value)
    local CM = configManager()
    if not CM or not CM.set then return end
    pcall(function() CM:set(path, value) end)
end

local function loadVolumesFromConfig()
    volumes.master = readConfigVolume(CONFIG_KEYS.master, volumes.master)
    volumes.sfx = readConfigVolume(CONFIG_KEYS.sfx, volumes.sfx)
    volumes.music = readConfigVolume(CONFIG_KEYS.music, volumes.music)
end

-- category volume x master, per the shared contract. Only meaningful for
-- "sfx"/"music" -- master has no further multiplier applied to itself.
local function effectiveVolume(category)
    return clamp01(volumes[category] or 1) * clamp01(volumes.master or 1)
end

------------------------------------------------------------------
-- Source pool: a fast typist fires 8-10 sounds/sec. Pool bookkeeping is
-- plain-table logic so it is unit-testable without a real love.audio.Source.
------------------------------------------------------------------

local Pool = {}
Pool.__index = Pool

function Pool.new(cap)
    return setmetatable({ cap = cap or 4, items = {} }, Pool)
end

-- Reuses an idle item if one exists; otherwise creates one under the cap;
-- otherwise steals the oldest item (voice stealing) rather than growing
-- unbounded.
function Pool:acquire(factory, isIdle)
    for _, item in ipairs(self.items) do
        if isIdle(item) then
            return item
        end
    end

    if #self.items < self.cap then
        local item = factory()
        table.insert(self.items, item)
        return item
    end

    local stolen = table.remove(self.items, 1)
    table.insert(self.items, stolen)
    return stolen
end

function Pool:size()
    return #self.items
end

local DEFAULT_POOL_CAP = 4
local POOL_CAPS = {
    key_linear = 6,
    key_tactile = 6,
    key_clicky = 6,
}

local pools = {}

-- Shared across every pool: no upvalues, so it costs nothing to reuse
-- instead of allocating a fresh closure on every playSfx call.
local function sourceIsIdle(source) return not source:isPlaying() end

-- The factory closure captures `data`, but `data` is fixed per sound name
-- after buildSoundLibrary() runs -- build it once here rather than on every
-- playSfx call (which fires 8-10x/sec while typing).
local function poolFor(name, data)
    local p = pools[name]
    if not p then
        p = Pool.new(POOL_CAPS[name] or DEFAULT_POOL_CAP)
        p.factory = function() return love.audio.newSource(data, "static") end
        pools[name] = p
    end
    return p
end

------------------------------------------------------------------
-- Synthesis. This is the shipping path: the licensed SFX packs cannot be
-- downloaded, so every sound is generated at init unless a real asset file
-- is present (see resources/sounds/README.md).
------------------------------------------------------------------

local SYNTH_RATE = 22050 -- plenty for short percussive/chip sounds, half the CPU of 44100

local function sampleCount(duration, rate)
    return math.max(1, math.floor(duration * (rate or SYNTH_RATE)))
end

-- Pure envelope+waveform sample, factored out of the SoundData writer so it
-- can be unit tested without love.sound. Returns a value already inside
-- [-amp, amp]; summed writes are clamped separately at write time.
local function envelopeSample(waveform, freq, t, amp, decay)
    local v
    if waveform == "noise" then
        v = randomFn() * 2 - 1
    elseif waveform == "square" then
        v = (math.sin(2 * math.pi * freq * t) >= 0) and 1 or -1
    else
        v = math.sin(2 * math.pi * freq * t)
    end
    return v * math.exp(-(decay or 0) * t) * (amp or 1)
end

local function newBuffer(duration)
    local n = sampleCount(duration)
    return love.sound.newSoundData(n, SYNTH_RATE, 16, 1), n
end

-- Additively writes a decaying tone/noise/square burst starting at
-- `startTime` seconds into `data`. Several calls on the same buffer let a
-- one-shot layer multiple notes (chords, arpeggios).
local function writeTone(data, n, startTime, duration, freq, amp, decay, waveform)
    local startSample = math.floor(startTime * SYNTH_RATE)
    local endSample = math.min(n - 1, startSample + sampleCount(duration) - 1)
    for i = startSample, endSample do
        local t = (i - startSample) / SYNTH_RATE
        local existing = data:getSample(i)
        data:setSample(i, clampSample(existing + envelopeSample(waveform, freq, t, amp, decay)))
    end
end

-- Linear frequency sweep via phase accumulation (not sin(2*pi*f(t)*t), which
-- has a discontinuous derivative and clicks).
local function writeSweep(data, n, startTime, duration, f1, f2, amp, decay)
    local startSample = math.floor(startTime * SYNTH_RATE)
    local total = sampleCount(duration)
    local endSample = math.min(n - 1, startSample + total - 1)
    local phase = 0
    for i = startSample, endSample do
        local t = (i - startSample) / SYNTH_RATE
        local frac = total > 1 and (i - startSample) / (total - 1) or 0
        local freq = f1 + (f2 - f1) * frac
        phase = phase + 2 * math.pi * freq / SYNTH_RATE
        local existing = data:getSample(i)
        data:setSample(i, clampSample(existing + math.sin(phase) * math.exp(-decay * t) * amp))
    end
end

-- Key thock specs. Distinguishable per the gameplay contract: linear is
-- duller/lower with a longer smoother decay, tactile has a secondary "bump"
-- partway through, clicky is short/bright/noisy with a sharp transient.
local KEY_SPECS = {
    linear = { duration = 0.09, freq = 110, noiseMix = 0.25, decay = 14, bump = false },
    tactile = { duration = 0.07, freq = 190, noiseMix = 0.35, decay = 18, bump = true },
    clicky = { duration = 0.05, freq = 320, noiseMix = 0.55, decay = 26, bump = false },
}

local function synthKeyThock(switchType)
    local spec = KEY_SPECS[switchType] or KEY_SPECS.linear
    local data, n = newBuffer(spec.duration)
    for i = 0, n - 1 do
        local t = i / SYNTH_RATE
        local env = math.exp(-spec.decay * t)
        if spec.bump then
            env = env + 0.25 * math.exp(-spec.decay * 3 * math.abs(t - spec.duration * 0.35))
        end
        local tone = math.sin(2 * math.pi * spec.freq * t)
        local noise = randomFn() * 2 - 1
        local sample = (tone * (1 - spec.noiseMix) + noise * spec.noiseMix) * env * 0.5
        data:setSample(i, clampSample(sample))
    end
    return data
end

-- Shared shape for the menu-navigation blips: a short tone followed by a
-- second tone that rises (confirm) or falls (back).
local function riseFallTone(f2)
    return function()
        local data, n = newBuffer(0.09)
        writeTone(data, n, 0, 0.05, 520, 0.3, 20)
        writeTone(data, n, 0.03, 0.06, f2, 0.3, 20)
        return data
    end
end

-- One-shot UI/feedback stings. Kept short and quiet -- this is a typing
-- game, the player hears these constantly, harsh sounds become unbearable.
local SFX_SYNTH = {
    error = function()
        local data, n = newBuffer(0.14)
        writeTone(data, n, 0, 0.14, 180, 0.35, 10, "square")
        writeTone(data, n, 0, 0.14, 170, 0.25, 10, "square") -- slight detune -> dissonant buzz
        return data
    end,
    coin = function()
        local data, n = newBuffer(0.09)
        writeSweep(data, n, 0, 0.09, 520, 1050, 0.4, 9)
        return data
    end,
    crit = function()
        local data, n = newBuffer(0.18)
        writeSweep(data, n, 0, 0.12, 660, 1320, 0.35, 7)
        writeTone(data, n, 0.02, 0.14, 1320, 0.2, 8)
        return data
    end,
    ui_move = function()
        local data, n = newBuffer(0.035)
        writeTone(data, n, 0, 0.035, 700, 0.25, 40)
        return data
    end,
    ui_confirm = riseFallTone(780),
    ui_back = riseFallTone(360),
    streak = function()
        local data, n = newBuffer(0.34)
        writeTone(data, n, 0.00, 0.12, 660, 0.28, 12)
        writeTone(data, n, 0.09, 0.12, 880, 0.28, 12)
        writeTone(data, n, 0.18, 0.16, 1320, 0.28, 10)
        return data
    end,
    round_complete = function()
        local data, n = newBuffer(0.4)
        writeTone(data, n, 0, 0.4, 523.25, 0.2, 5)
        writeTone(data, n, 0, 0.4, 659.25, 0.18, 5)
        writeTone(data, n, 0, 0.4, 783.99, 0.18, 5)
        return data
    end,
    game_over = function()
        local data, n = newBuffer(0.6)
        writeSweep(data, n, 0, 0.6, 300, 120, 0.3, 3)
        return data
    end,
}

local SFX_NAMES = { "error", "coin", "crit", "ui_move", "ui_confirm", "ui_back", "streak", "round_complete", "game_over" }

local ASSET_EXTS = { "wav", "ogg" }

local function loadRealAsset(name)
    if not love.filesystem then return nil end
    for _, ext in ipairs(ASSET_EXTS) do
        local path = "resources/sounds/" .. name .. "." .. ext
        if love.filesystem.getInfo(path) then
            local ok, data = pcall(love.sound.newSoundData, path)
            if ok and data then return data end
        end
    end
    return nil
end

local soundData = {}

local function buildSoundLibrary()
    soundData = {}
    pools = {}

    for _, switchType in ipairs({ "linear", "tactile", "clicky" }) do
        local name = "key_" .. switchType
        soundData[name] = loadRealAsset(name) or synthKeyThock(switchType)
    end

    for _, name in ipairs(SFX_NAMES) do
        soundData[name] = loadRealAsset(name) or SFX_SYNTH[name]()
    end
end

------------------------------------------------------------------
-- Music: looping + crossfade, driven from Audio.update(dt). With no music
-- files present we play nothing -- a bad generated loop is worse than
-- silence, per the roadmap.
------------------------------------------------------------------

local MUSIC_TRACKS = { "menu", "game", "shop" }
local DEFAULT_FADE = 0.6

local musicState = {
    active = nil,   -- { name, source }
    incoming = nil, -- { source, elapsed, duration, target }
    outgoing = nil, -- { source, elapsed, duration, from }
}

local function findMusicFile(track)
    if not love.filesystem then return nil end
    for _, ext in ipairs({ "ogg", "wav" }) do
        local path = "resources/sounds/music_" .. track .. "." .. ext
        if love.filesystem.getInfo(path) then return path end
    end
    return nil
end

-- Shared elapsed/duration -> 0..1 progress step for both fade directions.
local function fadeProgress(fade, dt)
    fade.elapsed = fade.elapsed + dt
    if fade.duration <= 0 then return 1 end
    return math.min(1, fade.elapsed / fade.duration)
end

local function logMissingMusic()
    if not _G.DEBUG_MODE then return end
    local missing = {}
    for _, track in ipairs(MUSIC_TRACKS) do
        if not findMusicFile(track) then missing[#missing + 1] = track end
    end
    if #missing > 0 then
        print("Audio: no music files for track(s): " .. table.concat(missing, ", ") ..
            " (see resources/sounds/README.md) -- playing silence")
    end
end

------------------------------------------------------------------
-- Public API
------------------------------------------------------------------

local ready = false

function Audio.init()
    -- Volume load/persist only touches ConfigManager (love.filesystem), so
    -- this must happen even headless -- it is what makes "set then re-init"
    -- persistence testable without a real audio device.
    loadVolumesFromConfig()

    if not audioAvailable() then
        ready = false
        return false
    end

    local ok = pcall(buildSoundLibrary)
    if not ok then
        ready = false
        return false
    end

    logMissingMusic()

    ready = true
    return true
end

function Audio.isReady()
    return ready
end

function Audio.playSfx(name, opts)
    if not ready or not audioAvailable() then return end
    local data = soundData[name]
    if not data then return end
    opts = opts or {}

    local pool = poolFor(name, data)
    local ok, source = pcall(pool.acquire, pool, pool.factory, sourceIsIdle)
    if not ok or not source then return end

    source:stop()
    source:setPitch(math.max(0.01, opts.pitch or randomPitch()))
    source:setVolume(clamp01(opts.volume or 1) * effectiveVolume("sfx"))
    source:play()
end

function Audio.playKey(switchType, correct)
    if not ready or not audioAvailable() then return end

    local name = "key_" .. (KEY_SPECS[switchType] and switchType or "linear")
    Audio.playSfx(name, { pitch = randomPitch(), volume = correct and 1.0 or 0.7 })

    if not correct then
        Audio.playSfx("error", { volume = 0.5 })
    end
end

function Audio.playMusic(track, opts)
    if not ready or not audioAvailable() then return end
    opts = opts or {}

    if musicState.active and musicState.active.name == track then return end

    local path = findMusicFile(track)
    if not path then return end -- silence, not a bad synthesized loop

    local ok, source = pcall(love.audio.newSource, path, "stream")
    if not ok or not source then return end

    source:setLooping(opts.loop == nil or opts.loop)
    source:setVolume(0)
    source:play()

    local fadeDur = opts.fade or DEFAULT_FADE
    if musicState.active then
        musicState.outgoing = {
            source = musicState.active.source,
            elapsed = 0,
            duration = fadeDur,
            from = musicState.active.source:getVolume(),
        }
    end
    musicState.incoming = { source = source, elapsed = 0, duration = fadeDur, target = effectiveVolume("music") }
    musicState.active = { name = track, source = source }
end

function Audio.stopMusic(fade)
    if not ready or not audioAvailable() then return end
    if not musicState.active then return end

    local dur = fade or 0
    if dur <= 0 then
        musicState.active.source:stop()
    else
        musicState.outgoing = {
            source = musicState.active.source,
            elapsed = 0,
            duration = dur,
            from = musicState.active.source:getVolume(),
        }
    end
    musicState.active = nil
    musicState.incoming = nil
end

function Audio.setVolume(category, value)
    if volumes[category] == nil then return end
    volumes[category] = clamp01(value)
    writeConfigVolume(CONFIG_KEYS[category], volumes[category])

    -- Live-update currently playing music so settings sliders are heard
    -- immediately; skip while a crossfade owns the volume ramp.
    if ready and audioAvailable() and musicState.active and not musicState.incoming and not musicState.outgoing then
        if category == "music" or category == "master" then
            musicState.active.source:setVolume(effectiveVolume("music"))
        end
    end
end

function Audio.getVolume(category)
    return volumes[category] or 1.0
end

function Audio.update(dt)
    if not ready or not audioAvailable() then return end

    if musicState.incoming then
        local m = musicState.incoming
        local t = fadeProgress(m, dt)
        m.source:setVolume(t * m.target)
        if t >= 1 then musicState.incoming = nil end
    end

    if musicState.outgoing then
        local m = musicState.outgoing
        local t = fadeProgress(m, dt)
        m.source:setVolume(m.from * (1 - t))
        if t >= 1 then
            m.source:stop()
            musicState.outgoing = nil
        end
    end
end

-- White-box hooks for tests/test_audio.lua, which runs with no love.audio at
-- all. Nothing here touches love.sound/love.audio, so it is exercised
-- directly without a real device.
Audio._test = {
    clamp01 = clamp01,
    clampSample = clampSample,
    effectiveVolume = effectiveVolume,
    randomPitch = randomPitch,
    Pool = Pool,
    sampleCount = sampleCount,
    envelopeSample = envelopeSample,
    keySpecs = KEY_SPECS,
    audioAvailable = audioAvailable,
}

return Audio
