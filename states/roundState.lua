-- states/roundState.lua
local TypingTrainer = require("modules.typingtrainer")
local TextGenerator = require("modules.textgenerator")
local StatTracker   = require("modules.statstracker")
local StateManager  = require("modules.statemanager")
local progressState = require("states.progressState")

local roundState = {}
roundState.currentRound = 1  -- persists between rounds

local trainer = nil

function roundState.enter()
    -- If coming from progressState after a passed round, currentRound is already updated.
    local text = TextGenerator.getRandomText()  -- (Could be enhanced with round difficulty.)
    trainer = TypingTrainer.new(text)
end

function roundState.update(dt)
    -- (Additional mechanics or rogue‑like effects could be applied here.)
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
            -- Only allow finishing if the player has typed the entire phrase.
            if #trainer.typed == #trainer.text then
                trainer:finish()
            end
        end
    else
        if key == "return" or key == "kpenter" then
            -- Evaluate the round only after the round is finished.
            local accuracy = trainer:getAccuracy()  -- percentage
            local apm = trainer:getAPM()
            local roundScore = (accuracy / 100) * apm

            local requiredAccuracy = math.min(100, 80 + roundState.currentRound - 1)
            local requiredScore    = 40 * roundState.currentRound

            local passed = (accuracy >= requiredAccuracy) and (roundScore >= requiredScore)

            -- Record the round’s stats.
            local sessionStats = {
                keystrokes       = #trainer.typed,
                mistakes         = trainer.mistakes,
                correct          = trainer.correctCount,
                time             = trainer:getTimeTaken(),
                apm              = apm,
                accuracy         = accuracy,
                longestStreak    = trainer.longestStreak,
                roundScore       = roundScore,
                requiredAccuracy = requiredAccuracy,
                requiredScore    = requiredScore,
                roundNumber      = roundState.currentRound,
            }
            StatTracker.recordSession(sessionStats)
            
            -- Pass the round data to progressState.
            progressState.setData(sessionStats, passed)
            
            -- If the round is passed, prepare for the next round.
            if passed then
                roundState.currentRound = roundState.currentRound + 1
            else
                roundState.currentRound = 1  -- Reset on failure (game over).
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
