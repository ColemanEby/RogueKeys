-- states/roundState.lua
-- The typing round itself. On completion it hands off to resultsState rather
-- than deciding navigation here -- that used to live in this file's key
-- handling and made "press S for shop" pay out full round money on Escape.

local StateManager = require("engine/stateManager")
local TypingTrainer = require("modules/typing/trainer")
local TextGenerator = require("modules/typing/textGenerator")
local Context = require("modules/game/context")
local Screen = require("modules/ui/screen")
local Theme = require("modules/ui/theme")
local Steam = require("modules/steam/steam")

local RoundState = {
    name = "RoundState",
    logical = true,
}

local trainer = nil
local player = nil
local sampleText = "The quick brown fox jumps over the lazy dog."

-- Money earned for a round. Pulled out to a named function so it is testable
-- headless without standing up a trainer/graphics context.
function RoundState.calculateMoney(score)
    return math.floor((score or 0) * 0.5)
end

function RoundState.enter()
    -- Context.player() is the one memoized instance; never PlayerModel.load()
    -- here, that was the source of the three-divergent-copies money desync.
    player = Context.player()
    player:startSession()

    local difficulty = player:getCurrentDifficulty()
    local ok, generated = pcall(function()
        return TextGenerator:getRandomText(difficulty)
    end)
    local text = (ok and generated) or sampleText

    local options = {
        text = text,
        difficulty = difficulty,
        displayName = "Round " .. player.currentRound,
        keyboardModel = player.keyboard,
        onComplete = function(stats)
            local moneyEarned = RoundState.calculateMoney(stats.score)
            stats.moneyEarned = moneyEarned

            -- endSession and addMoney both persist; do not save a third time.
            if (player.stats.totalSessions or 0) == 0 then
                Steam.unlockAchievement("FIRST_ROUND_COMPLETE")
            end
            player:endSession(stats)
            player:addMoney(moneyEarned)

            local requiredScore = player:getRequiredScore()
            Context.setPendingResults({
                stats = stats,
                moneyEarned = moneyEarned,
                requiredScore = requiredScore,
                passed = stats.score >= requiredScore,
                round = player.currentRound,
            })

            StateManager.switch("resultsState")
        end,
    }

    -- Run mutators are unit 12's territory; only wire them in if a run is
    -- active and actually exposes some, so this is a no-op until then.
    if Context.run and Context.run.mutators then
        options.mutators = Context.run.mutators
    end

    trainer = TypingTrainer.new(options)
end

function RoundState.exit()
    -- Drop everything so re-entering (next round, or after a game over) never
    -- sees a stale trainer or player reference from a previous visit.
    trainer = nil
    player = nil
end

-- Called by StateManager when an overlay pushed on top of us (pauseState)
-- pops back. The trainer holds its own state, so there is nothing to rebuild.
function RoundState.resume()
end

function RoundState.update(dt)
    if trainer then
        trainer:update(dt)
    end
end

function RoundState.draw()
    local base = Theme.color("base")
    love.graphics.clear(base[1], base[2], base[3], base[4] or 1)

    if not trainer then
        Theme.setColor("error")
        love.graphics.printf("Error: No trainer available", 0, Screen.getHeight() / 2,
            Screen.getWidth(), "center")
        return
    end

    local margin = Theme.spacing.xl
    trainer:draw(margin, margin, Screen.getWidth() - margin * 2, Screen.getHeight() - margin * 2)
end

function RoundState.keypressed(key)
    if not trainer or trainer.finished then return end

    if key == "backspace" then
        trainer:backspace()
    elseif key == "escape" then
        -- Pause, don't pay out. StateManager.push/pop are unit 4's addition;
        -- fall back to the menu (without finishing the trainer, so no money
        -- is awarded) if pauseState or the push API isn't available yet.
        local pushed = false
        if StateManager.push then
            local exists = not StateManager.loadState or StateManager.loadState("pauseState")
            if exists then
                pushed = pcall(StateManager.push, "pauseState")
            end
        end
        if not pushed then
            StateManager.switch("menuState")
        end
    end
end

function RoundState.textinput(text)
    if not trainer or trainer.finished then return end
    trainer:handleInput(text)
end

return RoundState
