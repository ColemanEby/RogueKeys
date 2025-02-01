-- states/typingState.lua
local TypingTrainer = require("modules.typingtrainer")
local TextGenerator = require("modules.textgenerator")

local typingState = {}
local trainer = nil

function typingState.enter()
    local text = TextGenerator.getRandomText()
    trainer = TypingTrainer.new(text)
end

function typingState.update(dt)
    -- Future rogue-like updates (e.g., item effects, enemy actions) would go here.
end

function typingState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    trainer:draw(20, 20)

    if trainer.finished then
         love.graphics.setColor(1, 1, 0)
         love.graphics.print("Press R to restart", 20, 150)
         love.graphics.setColor(1, 1, 1)
    end
end

function typingState.keypressed(key)
    if key == "r" and trainer.finished then
         typingState.enter()  -- Restart the session
    end
end

function typingState.textinput(t)
    if not trainer.finished then
         trainer:update(t)
    end
end

return typingState
