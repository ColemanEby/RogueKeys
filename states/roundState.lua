-- states/roundState.lua
local TypingTrainer = require("modules/typingtrainer")
local TextGenerator = require("modules/textgenerator")
local StatTracker   = require("modules/statstracker")
local StateManager  = require("modules/statemanager")
local progressState = require("states/progressState")
local Player        = require("modules/player")

local roundState = {}
roundState.currentRound = 1  -- persists between rounds

local trainer = nil

function roundState.enter()
    -- When entering a new round, generate a new phrase.
    local text = TextGenerator.getRandomText()  -- Could be enhanced based on round number.
    trainer = TypingTrainer.new(text)
end

function roundState.update(dt)
    -- (Additional mechanics can be applied here.)
end

function roundState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    
    -- Show round info at the top.
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Round " .. roundState.currentRound, 0, 10, love.graphics.getWidth(), "center")
    
    -- Draw the typing trainer interface below.
    trainer:draw(20, 60)
    
    if trainer.finished then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("Press Enter to complete round", 0, love.graphics.getHeight() - 40, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1)
    end
end

function roundState.keypressed(key)
    if not trainer.finished then
        if key == "backspace" then
            trainer:backspace()
        elseif key == "return" or key == "kpenter" then
            if #trainer.typed == #trainer.text then
                trainer:finish()
            end
        end
    else
        if key == "return" or key == "kpenter" then
            -- Evaluate the round.
            local accuracy = trainer:getAccuracy()  -- percentage
            local apm = trainer:getAPM()
            local rawScore = (accuracy / 100) * apm

            -- Incorporate keyboard multiplier.
            local finalScore = rawScore * Player.keyboard.multiplier

            local requiredAccuracy = math.min(100, 80 + roundState.currentRound - 1)
            local requiredScore    = 40 * roundState.currentRound

            local passed = (accuracy >= requiredAccuracy) and (finalScore >= requiredScore)

            -- If passed, award money (for example, money earned equals the floor of the final score).
            local moneyEarned = 0
            if passed then
                moneyEarned = math.floor(finalScore)
                Player.totalMoney = Player.totalMoney + moneyEarned
            end

            -- Record the round’s stats.
            local sessionStats = {
                keystrokes       = #trainer.typed,
                mistakes         = trainer.mistakes,
                correct          = trainer.correctCount,
                time             = trainer:getTimeTaken(),
                apm              = apm,
                accuracy         = accuracy,
                longestStreak    = trainer.longestStreak,
                rawScore         = rawScore,
                finalScore       = finalScore,
                requiredAccuracy = requiredAccuracy,
                requiredScore    = requiredScore,
                roundNumber      = roundState.currentRound,
                moneyEarned      = moneyEarned,
                totalMoney       = Player.totalMoney,
                keyboardMultiplier = Player.keyboard.multiplier
            }
            StatTracker.recordSession(sessionStats)
            
            -- Prepare progressState.
            local progressState = require("states/progressState")
            progressState.setData(sessionStats, passed)
            
            if passed then
                roundState.currentRound = roundState.currentRound + 1
            else
                roundState.currentRound = 1  -- Reset round count on failure.
            end
            
            StateManager.switch(progressState)
        end
    end
end

function roundState.textinput(t)
    if not trainer.finished then
        trainer:handleInput(t)
    end
end

return roundState
