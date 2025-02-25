-- states/roundState.lua
-- Simplified round state with minimal dependencies for debugging

local StateManager = require("engine/stateManager")
local TypingTrainer = require("modules/typing/trainer")
local TextGenerator = require("modules/typing/textGenerator")

local RoundState = {
    name = "RoundState"
}

-- Local variables
local trainer = nil
local roundStats = nil
local sampleText = "The quick brown fox jumps over the lazy dog."

-- Initialize the round state
function RoundState.enter()
    print("RoundState: Entered")

    -- Create typing trainer with sample text if text generator fails
    local text = nil

    -- Try to get text from generator
    local success, result = pcall(function()
        return TextGenerator:getRandomText("medium")
    end)

    if success and result then
        text = result
    else
        print("Failed to get text from generator, using sample text")
        text = sampleText
    end

    -- Create a simple trainer with minimal dependencies
    trainer = {
        text = text,
        typed = {},
        finished = false,
        correctCount = 0,
        mistakes = 0,
        score = 0,
        startTime = love.timer.getTime(),
        cursorPosition = 1,
        cursorVisible = true,
        cursorBlinkTimer = 0
    }
end

-- Update the round state
function RoundState.update(dt)
    -- Update cursor blink
    if trainer then
        trainer.cursorBlinkTimer = (trainer.cursorBlinkTimer or 0) + dt
        if trainer.cursorBlinkTimer >= 0.5 then
            trainer.cursorBlinkTimer = trainer.cursorBlinkTimer - 0.5
            trainer.cursorVisible = not trainer.cursorVisible
        end
    end
end

-- Draw the round state
function RoundState.draw()
    -- Clear background
    love.graphics.clear(0.1, 0.1, 0.15)

    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    if not trainer then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Error: No trainer available", 0, screenHeight / 2, screenWidth, "center")
        return
    end

    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Typing Trainer", 0, 50, screenWidth, "center")

    -- Draw the typing text
    local textY = 150
    local textAreaWidth = screenWidth - 100
    local padding = 20

    -- Draw text area background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 50, textY, textAreaWidth, 100, 5, 5)

    -- Draw text with highlighting
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local x = 50 + padding
    local y = textY + padding

    for i = 1, #trainer.text do
        local char = trainer.text:sub(i, i)
        local color = {1, 1, 1} -- Default white

        -- Color based on typing status
        if i <= #trainer.typed then
            if trainer.typed[i] == char then
                color = {0, 1, 0} -- Correct: green
            else
                color = {1, 0, 0} -- Incorrect: red
            end
        end

        -- Draw character
        love.graphics.setColor(unpack(color))
        love.graphics.print(char, x, y)

        -- Draw cursor
        if i == trainer.cursorPosition and trainer.cursorVisible and not trainer.finished then
            love.graphics.setColor(0, 0.7, 1)
            love.graphics.rectangle("fill", x, y, 2, font:getHeight())
        end

        x = x + font:getWidth(char)

        -- Wrap text if needed
        if x > 50 + textAreaWidth - padding * 2 then
            x = 50 + padding
            y = y + font:getHeight() * 1.5
        end
    end

    -- Draw stats
    love.graphics.setColor(1, 1, 1)
    local statsY = textY + 120
    love.graphics.printf("Correct: " .. trainer.correctCount .. " | Mistakes: " .. trainer.mistakes, 0, statsY, screenWidth, "center")

    -- Draw instructions
    if trainer.finished then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("Press Enter to continue or Escape to return to menu", 0, statsY + 40, screenWidth, "center")
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Handle keyboard input
function RoundState.keypressed(key)
    if not trainer then return end

    if not trainer.finished then
        if key == "backspace" then
            -- Handle backspace
            if #trainer.typed > 0 then
                local lastChar = trainer.text:sub(#trainer.typed, #trainer.typed)
                local typedChar = trainer.typed[#trainer.typed]

                if typedChar == lastChar then
                    trainer.correctCount = trainer.correctCount - 1
                else
                    trainer.mistakes = trainer.mistakes - 1
                end

                table.remove(trainer.typed)
                trainer.cursorPosition = #trainer.typed + 1
            end
        elseif key == "escape" then
            -- Finish early
            trainer.finished = true
        end
    else
        -- Handle post-completion navigation
        if key == "return" or key == "kpenter" then
            -- Go back to menu for now
            StateManager.switch("menuState")
        elseif key == "escape" then
            StateManager.switch("menuState")
        end
    end
end

-- Handle text input for typing
function RoundState.textinput(text)
    if not trainer or trainer.finished then return end

    local expectedChar = trainer.text:sub(trainer.cursorPosition, trainer.cursorPosition)

    -- Store the typed character
    trainer.typed[trainer.cursorPosition] = text

    -- Check if correct
    if text == expectedChar then
        trainer.correctCount = trainer.correctCount + 1
        trainer.score = trainer.score + 1
    else
        trainer.mistakes = trainer.mistakes + 1
    end

    -- Move cursor
    trainer.cursorPosition = trainer.cursorPosition + 1

    -- Check if completed
    if trainer.cursorPosition > #trainer.text then
        trainer.finished = true
    end
end

return RoundState