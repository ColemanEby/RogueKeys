-- modules/game/run.lua
-- Defines the shape of a session: a fixed number of rounds with escalating
-- score gates, boss rounds carrying a mutator, a win state and an endless
-- "tier" continuation. Consumed via Context.run by the round/results/game-over
-- states (units 7, 10, 11) and the mutator-aware trainer/text-gen (unit 15).

local ConfigManager = require("engine/configManager")
local Steam = require("modules/steam/steam")

local Run = {}
Run.__index = Run

local DEFAULT_ROUNDS = 8
local BOSS_INTERVAL = 3

-- Fixed contract -- the trainer and text generator switch on these exact
-- strings. Do not rename or reorder without updating unit 15/17.
local MUTATOR_IDS = { "no_backspace", "decaying_text", "timed_burst" }

-- Each higher endless tier scales the score gates up on top of the base
-- curve, so "tier 2" is a harder replay of the same 8 rounds rather than a
-- fresh set of numbers to balance.
local TIER_SCORE_MULTIPLIER = 0.25

local function configNumber(path, default)
    local ok, value = pcall(function() return ConfigManager:get(path, default) end)
    if ok and type(value) == "number" then
        return value
    end
    return default
end

-- Pick the boss mutator for a given round from the run's seed rather than the
-- global RNG, so a run's mutator sequence is reproducible independent of
-- whatever else in the game has been calling love.math.random, and so it can
-- be recomputed after a save/load without storing extra state.
local function mutatorForRound(seed, round)
    local rng = love.math.newRandomGenerator(seed, round)
    local index = rng:random(1, #MUTATOR_IDS)
    return MUTATOR_IDS[index]
end

-- Create a new run. opts = { rounds = 8, tier = 1, seed = n }
function Run.new(opts)
    opts = opts or {}

    local self = setmetatable({}, Run)
    self.totalRounds = opts.rounds or DEFAULT_ROUNDS
    self.tier = opts.tier or 1
    self.seed = opts.seed or os.time()
    self.round = 1
    self.complete = false
    self.failed = false

    return self
end

function Run:getRound()
    return self.round
end

function Run:getTotalRounds()
    return self.totalRounds
end

function Run:getTier()
    return self.tier
end

-- Same curve as PlayerModel:getRequiredScore (floor(base * round^scale)),
-- read from the same config keys so the two implementations cannot drift,
-- with a flat multiplier per endless tier on top.
function Run:getRequiredScore(round)
    round = round or self.round

    local base = configNumber("progression.baseRequiredScore", 20)
    local scale = configNumber("progression.roundDifficultyScale", 1.2)

    local tierMultiplier = 1 + (self.tier - 1) * TIER_SCORE_MULTIPLIER
    return math.floor(base * (round ^ scale) * tierMultiplier)
end

function Run:isBossRound(round)
    round = round or self.round
    return round % BOSS_INTERVAL == 0
end

-- Empty on normal rounds; exactly one mutator id on boss rounds.
function Run:getMutators(round)
    round = round or self.round
    if not self:isBossRound(round) then
        return {}
    end
    return { mutatorForRound(self.seed, round) }
end

-- Mutates the run and reports what happened. No retries within a run: once
-- failed or complete, further submissions are no-ops that just echo state.
function Run:submitScore(score)
    local round = self.round
    local requiredScore = self:getRequiredScore(round)

    if self.failed or self.complete then
        return {
            passed = false,
            requiredScore = requiredScore,
            round = round,
            advanced = false,
            complete = self.complete,
            failed = self.failed,
        }
    end

    local passed = (score or 0) >= requiredScore
    local advanced = false

    if not passed then
        self.failed = true
    elseif round >= self.totalRounds then
        self.complete = true
    else
        self.round = round + 1
        advanced = true
    end

    if self.complete or self.failed then
        Steam.unlockAchievement("FIRST_RUN_COMPLETE")
    end
    if self.complete and not self.failed then
        Steam.unlockAchievement("VICTORY_RUN")
    end

    return {
        passed = passed,
        requiredScore = requiredScore,
        round = round,
        advanced = advanced,
        complete = self.complete,
        failed = self.failed,
    }
end

function Run:isComplete()
    return self.complete
end

function Run:isFailed()
    return self.failed
end

-- A fresh run at the next endless difficulty tier: same round count, raised
-- gates, round reset to 1. A new seed keeps the boss mutator sequence from
-- repeating tier over tier.
function Run:nextTier()
    return Run.new({
        rounds = self.totalRounds,
        tier = self.tier + 1,
        seed = self.seed + 1,
    })
end

function Run:serialize()
    return {
        totalRounds = self.totalRounds,
        tier = self.tier,
        seed = self.seed,
        round = self.round,
        complete = self.complete,
        failed = self.failed,
    }
end

function Run.deserialize(data)
    if type(data) ~= "table" then
        return Run.new()
    end

    local run = Run.new({
        rounds = data.totalRounds,
        tier = data.tier,
        seed = data.seed,
    })

    if type(data.round) == "number" then
        run.round = data.round
    end
    run.complete = data.complete == true
    run.failed = data.failed == true

    return run
end

return Run
