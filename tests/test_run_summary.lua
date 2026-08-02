-- tests/test_run_summary.lua
-- Pure-logic tests for the run bookend screens (states/gameOverState.lua,
-- states/victoryState.lua). No graphics, no audio -- just the stat
-- comparisons and MVP selection that drive what those screens show.

local H = require("tests/helpers")
local Context = require("modules/game/context")

local GameOverState = require("states/gameOverState")
local VictoryState = require("states/victoryState")

local T = {}

-- Both screens duplicate the same small logic (they are two standalone new
-- states, neither owns a shared module); run every case against both
-- implementations so they can't silently diverge.
local IMPLS = { gameOver = GameOverState, victory = VictoryState }

-- ---------------------------------------------------------------------------
-- isNewBest: strict improvement only, not a tie
-- ---------------------------------------------------------------------------

for name, State in pairs(IMPLS) do
    T["new_best_fires_on_strict_improvement_" .. name] = function()
        H.isTrue(State.isNewBest(105, 100), "105 should beat a best of 100")
    end

    T["new_best_does_not_fire_on_tie_" .. name] = function()
        H.isFalse(State.isNewBest(100, 100), "matching the record is not a new one")
    end

    T["new_best_does_not_fire_when_worse_" .. name] = function()
        H.isFalse(State.isNewBest(90, 100))
    end

    T["new_best_rejects_non_numeric_input_" .. name] = function()
        H.isFalse(State.isNewBest(nil, 100))
        H.isFalse(State.isNewBest(100, nil))
        H.isFalse(State.isNewBest("105", 100))
    end
end

-- ---------------------------------------------------------------------------
-- Stat accessor: getRunStats() first, getStats() fallback
-- ---------------------------------------------------------------------------

for name, State in pairs(IMPLS) do
    T["stat_accessor_prefers_run_stats_" .. name] = function()
        local player = {
            getRunStats = function() return { keystrokes = 10 } end,
            getStats = function() return { keystrokes = 999 } end,
        }
        H.equal(State.getStatsSource(player).keystrokes, 10)
    end

    T["stat_accessor_falls_back_without_run_stats_" .. name] = function()
        local player = {
            getStats = function() return { keystrokes = 42 } end,
        }
        H.equal(State.getStatsSource(player).keystrokes, 42)
    end

    T["stat_accessor_falls_back_when_run_stats_errors_" .. name] = function()
        local player = {
            getRunStats = function() error("not implemented") end,
            getStats = function() return { keystrokes = 7 } end,
        }
        H.equal(State.getStatsSource(player).keystrokes, 7)
    end

    T["stat_accessor_falls_back_when_run_stats_returns_nil_" .. name] = function()
        local player = {
            getRunStats = function() return nil end,
            getStats = function() return { keystrokes = 3 } end,
        }
        H.equal(State.getStatsSource(player).keystrokes, 3)
    end

    T["stat_accessor_handles_missing_player_" .. name] = function()
        H.deepEqual(State.getStatsSource(nil), {})
    end
end

-- ---------------------------------------------------------------------------
-- MVP-key selection
-- ---------------------------------------------------------------------------

for name, State in pairs(IMPLS) do
    T["mvp_selection_with_zero_upgrades_" .. name] = function()
        H.equal(State.selectMvpKey({ upgrades = {} }), nil)
        H.equal(State.selectMvpKey({ upgrades = nil }), nil)
        H.equal(State.selectMvpKey(nil), nil)
    end

    T["mvp_selection_with_one_upgrade_" .. name] = function()
        local mvp = State.selectMvpKey({ upgrades = { e = 0.15 } })
        H.isTrue(mvp ~= nil)
        H.equal(mvp.key, "e")
        H.near(mvp.bonus, 0.15)
    end

    T["mvp_selection_picks_the_highest_bonus_" .. name] = function()
        local mvp = State.selectMvpKey({ upgrades = { e = 0.10, a = 0.25, t = 0.05 } })
        H.equal(mvp.key, "a")
        H.near(mvp.bonus, 0.25)
    end

    T["mvp_selection_breaks_ties_deterministically_" .. name] = function()
        local mvp1 = State.selectMvpKey({ upgrades = { t = 0.20, a = 0.20 } })
        local mvp2 = State.selectMvpKey({ upgrades = { a = 0.20, t = 0.20 } })
        H.equal(mvp1.key, mvp2.key, "tie-break must not depend on table insertion order")
        H.equal(mvp1.key, "a", "ties break alphabetically")
    end

    T["mvp_selection_handles_item_def_shaped_upgrades_" .. name] = function()
        -- Defensive: unit 13 may eventually store item defs rather than raw
        -- numbers. { effect = { value = n } } and { bonus = n } shapes must
        -- not crash the selector.
        local mvp = State.selectMvpKey({ upgrades = { e = { effect = { value = 0.3 } } } })
        H.equal(mvp.key, "e")
        H.near(mvp.bonus, 0.3)

        local mvp2 = State.selectMvpKey({ upgrades = { r = { bonus = 0.2 } } })
        H.equal(mvp2.key, "r")
        H.near(mvp2.bonus, 0.2)
    end
end

-- ---------------------------------------------------------------------------
-- enter() must handle nil params without throwing, cold or warm.
-- ---------------------------------------------------------------------------

function T.game_over_enter_handles_nil_params()
    Context.reset()
    H.succeeds(function() GameOverState.enter(nil) end)
    H.succeeds(function() GameOverState.enter() end)
    Context.reset()
end

function T.victory_enter_handles_nil_params()
    Context.reset()
    H.succeeds(function() VictoryState.enter(nil) end)
    H.succeeds(function() VictoryState.enter() end)
    Context.reset()
end

function T.game_over_enter_handles_partial_params()
    Context.reset()
    H.succeeds(function() GameOverState.enter({ reason = "abandoned" }) end)
    H.succeeds(function() GameOverState.enter({ round = 4 }) end)
    Context.reset()
end

function T.game_over_enter_never_awards_money_on_abandon()
    Context.reset()
    local player = Context.player()
    local moneyBefore = player.totalMoney

    GameOverState.enter({ reason = "abandoned", round = 3 })

    H.equal(Context.player().totalMoney, moneyBefore, "abandoning must not award money")
    Context.reset()
end

return T
