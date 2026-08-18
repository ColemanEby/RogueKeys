-- modules/steam/steam.lua
-- Thin wrapper around luasteam (https://github.com/uspgamedev/luasteam,
-- PascalCase API mirroring the Steamworks C++ SDK: Steam.Init(),
-- Steam.RunCallbacks(), Steam.UserStats.SetAchievement(), etc).
--
-- There is no Steamworks SDK, no steam_appid.txt and no registered appid in
-- this repository, so `require("luasteam")` never succeeds here -- this is
-- the normal, permanent state for every non-Steam build (source checkouts,
-- itch.io demo, CI). Every function below degrades to a safe no-op in that
-- case. Nothing else in the game should ever need to check
-- `Steam.isAvailable()` before calling in -- it is always safe to call these.
--
-- Contract:
--   Steam.init()                 -> bool, available
--   Steam.isAvailable()          -> bool
--   Steam.unlockAchievement(id)  -- queues; call Steam.store() to flush
--   Steam.setStat(name, value)   -- queues; call Steam.store() to flush
--   Steam.store()                -- flush pending stats/achievements
--   Steam.shutdown()
--   Steam.update()               -- pump callbacks; call once per frame

local Steam = {}

local luasteam = nil
local available = false

-- Achievements/stats already sent this session, so a caller can unlock the
-- same achievement every time its trigger condition is true without needing
-- to track "have I already done this" itself.
local sentAchievements = {}

local function safeCall(fn, ...)
    if not fn then return false end
    local ok, err = pcall(fn, ...)
    if not ok and _G.DEBUG_MODE then
        print("Steam: " .. tostring(err))
    end
    return ok
end

-- Called once from love.load. Safe to call even when Steam is never present.
function Steam.init()
    if _G.HEADLESS then
        available = false
        return false
    end

    local ok, mod = pcall(require, "luasteam")
    if not ok or not mod then
        available = false
        return false
    end

    -- luasteam.Init() requires a steam_appid.txt next to the executable (or
    -- a real appid + a running Steam client). Neither exists during
    -- development, so failure here is expected, not an error.
    local initOk = mod.Init and safeCall(mod.Init)
    if not initOk then
        available = false
        return false
    end

    luasteam = mod
    available = true
    return true
end

function Steam.isAvailable()
    return available
end

function Steam.unlockAchievement(id)
    if not id or sentAchievements[id] then return end
    sentAchievements[id] = true
    if not available then return end
    safeCall(function() luasteam.UserStats.SetAchievement(id) end)
end

function Steam.isAchievementSent(id)
    return not not sentAchievements[id]
end

function Steam.setStat(name, value)
    if not name or not available then return end
    safeCall(function() luasteam.UserStats.SetStat(name, value) end)
end

-- Flushes queued achievements/stats to Steam. Cheap to call after every
-- round; a no-op when Steam is unavailable.
function Steam.store()
    if not available then return end
    safeCall(function() luasteam.UserStats.StoreStats() end)
end

-- Pumps luasteam's callback queue. Call once per frame from love.update;
-- a no-op when Steam is unavailable.
function Steam.update()
    if not available then return end
    safeCall(function() luasteam.RunCallbacks() end)
end

function Steam.shutdown()
    if available then
        safeCall(function() luasteam.Shutdown() end)
    end
    available = false
    luasteam = nil
    sentAchievements = {}
end

return Steam
