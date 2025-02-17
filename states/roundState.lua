-- states/roundState.lua
local TypingTrainer = require("modules/typingtrainer")
local TextGenerator = require("modules/textgenerator")
local StatTracker   = require("modules/statstracker")
local StateManager  = require("modules/statemanager")
local Player        = require("modules/player")
local progressState = require("states/progressState")

local roundState = {}
roundState.name = "RoundState"
roundState.currentRound = 1  -- persists between rounds

local trainer = nil

function roundState.enter()
    trainer = TypingTrainer.new(TextGenerator:getRandomText())
end

function roundState.update(dt)
end

function roundState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Round " .. roundState.currentRound, 0, 10, love.graphics.getWidth(), "center")
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
        elseif #trainer.typed >= #trainer.text then
            trainer:finish()
        end
    else
        if (key == "return") or (key == "kpenter") then
            local finalScore = trainer.score
            local requiredScore = 20 * roundState.currentRound
            local passed = finalScore >= requiredScore

            local sessionStats = {
                keystrokes = #trainer.typed,
                mistakes = trainer.mistakes,
                correct = trainer.correctCount,
                time = trainer:getTimeTaken(),
                score = finalScore,
                requiredScore = requiredScore,
                roundNumber = roundState.currentRound,
                moneyEarned = 0,
            }
            if passed then
                sessionStats.moneyEarned = math.floor(finalScore)
                Player.totalMoney = Player.totalMoney + sessionStats.moneyEarned
                roundState.currentRound = roundState.currentRound + 1
            else
                roundState.currentRound = 1
            end

            progressState.setData(sessionStats, passed)
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
