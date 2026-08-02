-- tests/test_stats_graph.lua
-- Pure-logic coverage for the stats screen's graph math and stat accessors.
-- statsState.lua exposes these as StatsState._internal precisely so they can
-- be exercised headless, without a graphics context.

local H = require("tests/helpers")
local StatsState = require("states/statsState")
local I = StatsState._internal

local T = {}

-- ---------------------------------------------------------------------------
-- Bar-index mapping: matchHistory is newest-first (index 1 = most recent).
-- The oldest of the displayed matches must land on the left (position 1),
-- the newest on the right (position == displayCount).
-- ---------------------------------------------------------------------------

function T.bar_index_puts_newest_on_the_right_and_oldest_on_the_left()
    for _, n in ipairs({ 1, 2, 5, 30 }) do
        H.equal(I.barMatchIndex(1, n), n, "leftmost position must read the oldest match (index n) for n=" .. n)
        H.equal(I.barMatchIndex(n, n), 1, "rightmost position must read the newest match (index 1) for n=" .. n)
    end
end

function T.bar_index_is_a_reflection_around_the_midpoint()
    -- For n=5, position 3 (the middle) must map to index 3 (also the middle).
    H.equal(I.barMatchIndex(3, 5), 3)

    -- For n=30, position 15 maps to index 16, position 16 to index 15.
    H.equal(I.barMatchIndex(15, 30), 16)
    H.equal(I.barMatchIndex(16, 30), 15)
end

function T.match_series_reads_oldest_to_newest()
    -- index 1 = newest (30 wpm), index 3 = oldest (10 wpm).
    local history = { { wpm = 30 }, { wpm = 20 }, { wpm = 10 } }
    local series = I.matchSeries(history, "wpm")

    H.equal(#series, 3)
    H.equal(series[1], 10, "series[1] (leftmost/oldest) should be the oldest match's wpm")
    H.equal(series[2], 20)
    H.equal(series[3], 30, "series[3] (rightmost/newest) should be the newest match's wpm")
end

function T.match_series_tolerates_malformed_entries()
    local history = { { wpm = 5 }, "corrupted-entry", { wpm = 1 }, nil }
    -- #history is ambiguous with a trailing nil, but the entries that exist
    -- must not raise and non-tables must read as 0.
    H.succeeds(function() I.matchSeries(history, "wpm") end)
end

-- ---------------------------------------------------------------------------
-- Stat accessors: must return 0 (or a sane default) instead of throwing for
-- stats tables missing keys, or a nil stats table entirely (older saves).
-- ---------------------------------------------------------------------------

function T.get_accuracy_handles_missing_and_nil_stats()
    H.equal(I.getAccuracy(nil), 0)
    H.equal(I.getAccuracy({}), 0)
    H.equal(I.getAccuracy({ totalCorrect = 0, totalMistakes = 0 }), 0)
    H.near(I.getAccuracy({ totalCorrect = 90, totalMistakes = 10 }), 90)
end

function T.get_savings_rate_handles_missing_and_nil_stats()
    H.equal(I.getSavingsRate(nil), 0)
    H.equal(I.getSavingsRate({}), 0)
    H.near(I.getSavingsRate({ moneyEarned = 100, moneySpent = 40 }), 60)
    -- Overspending (shouldn't happen, but must not go negative) clamps to 0.
    H.equal(I.getSavingsRate({ moneyEarned = 100, moneySpent = 500 }), 0)
end

function T.count_upgrades_handles_missing_and_nil()
    H.equal(I.countUpgrades(nil), 0)
    H.equal(I.countUpgrades({}), 0)
    H.equal(I.countUpgrades({ e = 1, r = 2 }), 2)
end

function T.format_time_handles_missing_and_negative()
    H.equal(I.formatTime(nil), "0m 0s")
    H.equal(I.formatTime(-5), "0m 0s")
    H.equal(I.formatTime(65), "1m 5s")
    H.equal(I.formatTime(3661), "1h 1m 1s")
end

-- ---------------------------------------------------------------------------
-- Line-graph scaling must never divide by zero, for empty, single-point, and
-- all-equal series.
-- ---------------------------------------------------------------------------

function T.line_graph_range_handles_empty_series()
    local lo, hi = I.lineGraphRange({})
    H.isTrue(hi > lo, "range must be non-degenerate even for an empty series")
end

function T.line_graph_range_handles_single_point()
    local lo, hi = I.lineGraphRange({ 42 })
    H.isTrue(hi > lo, "range must be non-degenerate for a single data point")
    H.isTrue(42 >= lo and 42 <= hi, "the single point must fall inside its own range")
end

function T.line_graph_range_handles_all_equal_values()
    local lo, hi = I.lineGraphRange({ 7, 7, 7, 7 })
    H.isTrue(hi > lo, "range must be non-degenerate when every value is equal")
end

function T.line_graph_range_covers_the_real_spread()
    local lo, hi = I.lineGraphRange({ 10, 40, 25, 5, 60 })
    H.equal(lo, 5)
    H.equal(hi, 60)
end

return T
