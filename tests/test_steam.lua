-- tests/test_steam.lua
-- The dev/CI environment has no Steamworks SDK and no steam_appid.txt, so
-- luasteam never loads here. This suite locks down the property that matters
-- most: every call is a safe no-op in that state, so game code never has to
-- guard calls behind Steam.isAvailable().

local H = require("tests/helpers")
local Steam = require("modules/steam/steam")

local T = {}

function T.init_reports_unavailable_when_luasteam_is_absent()
    -- Headless tests run with no window and no Steamworks SDK -- init must
    -- report false, not raise.
    local ok = Steam.init()
    H.isFalse(ok, "Steam.init() must return false with no luasteam module present")
    H.isFalse(Steam.isAvailable())
end

function T.all_calls_are_safe_noops_when_unavailable()
    H.succeeds(function() Steam.unlockAchievement("FIRST_RUN") end)
    H.succeeds(function() Steam.setStat("rounds_played", 1) end)
    H.succeeds(function() Steam.store() end)
    H.succeeds(function() Steam.update() end)
    H.succeeds(function() Steam.shutdown() end)
end

function T.unlock_achievement_ignores_nil_id()
    H.succeeds(function() Steam.unlockAchievement(nil) end)
end

function T.set_stat_ignores_nil_name()
    H.succeeds(function() Steam.setStat(nil, 5) end)
end

function T.repeated_unlocks_of_the_same_achievement_are_cheap_and_safe()
    for _ = 1, 5 do
        H.succeeds(function() Steam.unlockAchievement("PERFECT_ROUND") end)
    end
end

return T
