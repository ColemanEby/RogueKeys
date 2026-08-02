-- modules/audio/audio.lua
-- Audio facade. This is the FOUNDATION STUB: the API is final, the
-- implementation is not. Every call is a safe no-op until the audio unit fills
-- it in, so callers can be written against it today.
--
-- Contract:
--   Audio.init()                       -- called once from love.load
--   Audio.playSfx(name, opts)          -- opts = { pitch, volume }
--   Audio.playKey(switchType, correct) -- per-keystroke thock
--   Audio.playMusic(track, opts)       -- opts = { loop, fade }
--   Audio.stopMusic(fade)
--   Audio.setVolume(category, value)   -- "master" | "sfx" | "music"
--   Audio.getVolume(category)
--   Audio.update(dt)

local Audio = {}

local volumes = {
    master = 1.0,
    sfx = 1.0,
    music = 1.0,
}

local ready = false

function Audio.init()
    if _G.HEADLESS or not love.audio then
        ready = false
        return false
    end

    -- Volumes are persisted by ConfigManager; read them if available.
    local ok, ConfigManager = pcall(require, "engine/configManager")
    if ok and ConfigManager and ConfigManager.get then
        local function read(path, fallback)
            local got, value = pcall(function() return ConfigManager:get(path, fallback) end)
            if got and type(value) == "number" then return value end
            return fallback
        end
        volumes.master = read("audio.masterVolume", volumes.master)
        volumes.sfx = read("audio.sfxVolume", volumes.sfx)
        volumes.music = read("audio.musicVolume", volumes.music)
    end

    ready = true
    return true
end

function Audio.isReady()
    return ready
end

function Audio.playSfx(name, opts) end

function Audio.playKey(switchType, correct) end

function Audio.playMusic(track, opts) end

function Audio.stopMusic(fade) end

function Audio.setVolume(category, value)
    if volumes[category] == nil then return end
    volumes[category] = math.max(0, math.min(1, tonumber(value) or 0))
    if ready and love.audio and category == "master" then
        love.audio.setVolume(volumes.master)
    end
end

function Audio.getVolume(category)
    return volumes[category] or 1.0
end

function Audio.update(dt) end

return Audio
