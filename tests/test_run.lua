-- tests/test_run.lua
-- Run structure: score gates, boss rounds/mutators, pass/fail flow, tiers and
-- the save/load round-trip.

local H = require("tests/helpers")
local Run = require("modules/game/run")
local Serialize = require("modules/util/serialize")
local ConfigManager = require("engine/configManager")

local T = {}

local LEGAL_MUTATORS = { no_backspace = true, decaying_text = true, timed_burst = true }

function T.gate_values_match_the_base_curve()
    local run = Run.new({ seed = 1 })
    for round = 1, 8 do
        local expected = math.floor(20 * (round ^ 1.2))
        H.equal(run:getRequiredScore(round), expected, "round " .. round .. " gate mismatch")
    end
end

function T.boss_rounds_are_every_third_round()
    local run = Run.new({ seed = 1 })
    local expectedBoss = { [1] = false, [2] = false, [3] = true, [4] = false,
                            [5] = false, [6] = true, [7] = false, [8] = false }
    for round = 1, 8 do
        H.equal(run:isBossRound(round), expectedBoss[round], "round " .. round)
    end
end

function T.boss_rounds_carry_exactly_one_legal_mutator()
    local run = Run.new({ seed = 42 })

    local bossMutators = run:getMutators(3)
    H.equal(#bossMutators, 1)
    H.isTrue(LEGAL_MUTATORS[bossMutators[1]], "unexpected mutator id: " .. tostring(bossMutators[1]))

    local bossMutators2 = run:getMutators(6)
    H.equal(#bossMutators2, 1)
    H.isTrue(LEGAL_MUTATORS[bossMutators2[1]], "unexpected mutator id: " .. tostring(bossMutators2[1]))
end

function T.normal_rounds_have_no_mutators()
    local run = Run.new({ seed = 42 })
    for _, round in ipairs({ 1, 2, 4, 5, 7, 8 }) do
        H.equal(#run:getMutators(round), 0, "round " .. round .. " should have no mutators")
    end
end

function T.same_seed_reproduces_the_same_mutator_sequence()
    local a = Run.new({ seed = 7 })
    local b = Run.new({ seed = 7 })

    H.equal(a:getMutators(3)[1], b:getMutators(3)[1])
    H.equal(a:getMutators(6)[1], b:getMutators(6)[1])
end

function T.different_seeds_generally_differ()
    local samples = {}
    local distinct = {}
    for seed = 1, 25 do
        local run = Run.new({ seed = seed })
        local m = run:getMutators(3)[1]
        samples[#samples + 1] = m
        distinct[m] = true
    end

    local distinctCount = H.count(distinct)
    H.isTrue(distinctCount > 1, "25 different seeds all produced the same boss mutator")
end

function T.passing_the_gate_advances_the_round()
    local run = Run.new({ seed = 1 })
    local required = run:getRequiredScore(1)

    local result = run:submitScore(required)

    H.isTrue(result.passed)
    H.isTrue(result.advanced)
    H.isFalse(result.failed)
    H.isFalse(result.complete)
    H.equal(run:getRound(), 2)
    H.isFalse(run:isFailed())
end

function T.missing_the_gate_fails_the_run()
    local run = Run.new({ seed = 1 })
    local required = run:getRequiredScore(1)

    local result = run:submitScore(required - 1)

    H.isFalse(result.passed)
    H.isFalse(result.advanced)
    H.isTrue(result.failed)
    H.isTrue(run:isFailed())
    H.equal(run:getRound(), 1, "a failed run must not advance")
end

function T.further_submissions_after_failure_do_not_silently_advance()
    local run = Run.new({ seed = 1 })
    run:submitScore(0) -- guaranteed fail on round 1

    H.isTrue(run:isFailed())
    local roundBefore = run:getRound()

    -- Even an enormous score must not resurrect or advance a failed run.
    local result = run:submitScore(999999)

    H.isFalse(result.passed)
    H.isFalse(result.advanced)
    H.isTrue(result.failed)
    H.equal(run:getRound(), roundBefore)
end

function T.clearing_the_final_round_completes_the_run()
    local run = Run.new({ rounds = 8, seed = 1 })

    local lastResult
    for round = 1, 8 do
        lastResult = run:submitScore(run:getRequiredScore(round))
    end

    H.isTrue(run:isComplete())
    H.isFalse(run:isFailed())
    H.isTrue(lastResult.complete)
    H.isFalse(lastResult.failed)
end

function T.further_submissions_after_completion_do_not_reopen_the_run()
    local run = Run.new({ rounds = 1, seed = 1 })
    run:submitScore(run:getRequiredScore(1))
    H.isTrue(run:isComplete())

    local result = run:submitScore(0)
    H.isFalse(result.passed)
    H.isFalse(result.advanced)
    H.isTrue(result.complete)
    H.equal(run:getRound(), 1)
end

function T.next_tier_raises_gates_and_resets_to_round_one()
    local run = Run.new({ rounds = 8, tier = 1, seed = 1 })
    for round = 1, 8 do
        run:submitScore(run:getRequiredScore(round))
    end
    H.isTrue(run:isComplete())

    local nextRun = run:nextTier()

    H.equal(nextRun:getTier(), 2)
    H.equal(nextRun:getRound(), 1)
    H.isFalse(nextRun:isComplete())
    H.isFalse(nextRun:isFailed())
    H.isTrue(nextRun:getRequiredScore(1) > run:getRequiredScore(1),
        "tier 2 gate should be harder than tier 1's gate for the same round")
end

function T.serialize_round_trips_through_the_shared_codec()
    local run = Run.new({ rounds = 8, tier = 3, seed = 99 })
    run:submitScore(run:getRequiredScore(1)) -- now on round 2

    local chunk, err = Serialize.encode(run:serialize())
    H.isTrue(chunk ~= nil, "encode failed: " .. tostring(err))

    local data, decodeErr = Serialize.decode(chunk)
    H.isTrue(data ~= nil, "decode failed: " .. tostring(decodeErr))

    local restored = Run.deserialize(data)

    H.equal(restored:getRound(), run:getRound())
    H.equal(restored:getTier(), run:getTier())
    H.equal(restored:getTotalRounds(), run:getTotalRounds())
    H.equal(restored:isComplete(), run:isComplete())
    H.equal(restored:isFailed(), run:isFailed())
    H.equal(restored:getMutators(3)[1], run:getMutators(3)[1],
        "restored run must produce the same next boss mutator")
end

function T.serialize_shape_is_flat_and_plain()
    local run = Run.new({ seed = 5 })
    local data = run:serialize()

    for k, v in pairs(data) do
        local t = type(v)
        H.isTrue(t == "number" or t == "boolean" or t == "string",
            "serialize() must be flat/plain, found " .. t .. " at key " .. tostring(k))
    end
    H.equal(getmetatable(data), nil, "serialized run must not carry a metatable")
end

function T.config_overrides_for_base_and_scale_are_honoured()
    ConfigManager.configs.progression = ConfigManager.configs.progression or {}
    local prevBase = ConfigManager.configs.progression.baseRequiredScore
    local prevScale = ConfigManager.configs.progression.roundDifficultyScale

    ConfigManager.configs.progression.baseRequiredScore = 50
    ConfigManager.configs.progression.roundDifficultyScale = 1.5

    local ok, err = pcall(function()
        local run = Run.new({ seed = 1 })
        local expected = math.floor(50 * (3 ^ 1.5))
        H.equal(run:getRequiredScore(3), expected)
    end)

    ConfigManager.configs.progression.baseRequiredScore = prevBase
    ConfigManager.configs.progression.roundDifficultyScale = prevScale

    H.isTrue(ok, "config override test raised: " .. tostring(err))
end

function T.default_total_rounds_is_eight()
    local run = Run.new()
    H.equal(run:getTotalRounds(), 8)
end

return T
