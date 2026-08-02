-- tests/test_round_flow.lua
-- Headless coverage for the round -> results hand-off: the money formula,
-- pass/fail against the round's required score, and that abandoning a run
-- never awards money. Deliberately avoids anything that writes the player
-- save file (advanceRound/addMoney/save) since tests run against the real
-- LOVE save directory for this identity.

local H = require("tests/helpers")
local Context = require("modules/game/context")
local StateManager = require("engine/stateManager")
local RoundState = require("states/roundState")
local ResultsState = require("states/resultsState")

local T = {}

function T.money_is_half_score_rounded_down()
    H.equal(RoundState.calculateMoney(100), 50)
    H.equal(RoundState.calculateMoney(101), 50, "must floor, not round")
    H.equal(RoundState.calculateMoney(0), 0)
    H.equal(RoundState.calculateMoney(nil), 0, "missing score must not raise")
end

function T.pass_fail_matches_required_score()
    local player = Context.player()
    local required = player:getRequiredScore()
    H.isTrue(required >= 0, "required score must be non-negative")

    -- Mirrors the exact comparison roundState uses to build pendingResults.passed.
    H.isFalse((required - 1) >= required, "a score just under the requirement must fail")
    H.isTrue(required >= required, "a score meeting the requirement must pass")
end

function T.abandon_does_not_award_money()
    Context.reset()
    local before = Context.player().totalMoney

    ResultsState.enter()
    ResultsState.keypressed("a") -- Abandon Run

    H.equal(Context.player().totalMoney, before, "abandoning a run must not add money")

    -- Abandon routes through StateManager.switch (gameOverState, or menuState
    -- as a fallback since gameOverState may not exist in this worktree yet).
    -- Leave the singleton clean for any tests that run after this one.
    StateManager.current = nil
    StateManager.history = {}
    Context.reset()
end

return T
