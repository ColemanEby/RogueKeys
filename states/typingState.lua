-- states/typingState.lua
local TypingTrainer = require("modules/typingtrainer")
local TextGenerator = require("modules.textgenerator")
local StatTracker = require("modules.statstracker")
local StateManager = require("modules.statemanager")
-- (Lazy-load mainMenuState when needed to avoid circular dependencies)

local typingState = {}
local trainer = nil
local sessionRecorded = false

function typingState.enter()
    local text = TextGenerator.getRandomText()
    trainer = TypingTrainer.new(text)
    sessionRecorded = false
end

function typingState.update(dt)
    -- Future rogue‑like updates can go here.
end

function typingState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    trainer:draw(20, 20)

    if trainer.finished then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Press R to restart, M for main menu", 20, love.graphics.getHeight() - 40)
        love.graphics.setColor(1, 1, 1)
        if not sessionRecorded then
            local sessionTime = trainer:getTimeTaken()
            local keystrokes = #trainer.typed
            local sessionStats = {
                keystrokes = keystrokes,
                mistakes = trainer.mistakes,
                correct = trainer.correctCount,
                time = sessionTime,
                apm = trainer:getAPM(),
                accuracy = trainer:getAccuracy(),
                longestStreak = trainer.longestStreak,
            }
            StatTracker.recordSession(sessionStats)
            sessionRecorded = true
        end
    end
end

function typingState.keypressed(key)
    if not trainer.finished then
        if key == "backspace" then
            trainer:backspace()
        elseif key == "return" or key == "kpenter" then
            if #trainer.typed == #trainer.text then
                trainer:finish()
            end
        end
    else
        if key == "r" then
            typingState.enter()  -- Restart the session.
        elseif key == "m" then
            local mainMenuState = require("states.mainMenuState")
            StateManager.switch(mainMenuState)
        end
    end
end

function typingState.textinput(t)
    if not trainer.finished then
        trainer:handleInput(t)
    end
end

return typingState
