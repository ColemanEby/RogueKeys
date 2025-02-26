-- states/roundState.lua
-- Enhanced round state with proper stats tracking

local StateManager = require("engine/stateManager")
local TypingTrainer = require("modules/typing/trainer")
local TextGenerator = require("modules/typing/textGenerator")
local PlayerModel = require("modules/player/playerModel")

local RoundState = {
    name = "RoundState"
}

-- Local variables
local trainer = nil
local player = nil
local roundStats = nil
local sampleText = "The quick brown fox jumps over the lazy dog."

-- Initialize the round state
function RoundState.enter()
    print("RoundState: Entered")

    -- Load player data
    player = player or PlayerModel.load()

    -- Start player session tracking
    player:startSession()

    -- Create typing trainer with sample text if text generator fails
    local text = nil

    -- Try to get text from generator with appropriate difficulty
    local difficulty = player:getCurrentDifficulty()
    local success, result = pcall(function()
        return TextGenerator:getRandomText(difficulty)
    end)

    if success and result then
        text = result
    else
        print("Failed to get text from generator, using sample text")
        text = sampleText
    end

    -- Create typing trainer with proper callbacks
    trainer = TypingTrainer.new({
        text = text,
        difficulty = difficulty,
        displayName = "Round " .. player.currentRound,
        keyboardModel = player.keyboard,
        onComplete = function(stats)
            -- Calculate money earned based on score
            local moneyEarned = math.floor(stats.score * 0.5)
            stats.moneyEarned = moneyEarned

            -- Record session stats to player model
            player:endSession(stats)

            -- Add money to player
            player:addMoney(moneyEarned)

            -- Save player data
            player:save()

            -- Store round stats for potential progress screen
            roundStats = stats
        end
    })
end

-- Update the round state
function RoundState.update(dt)
    -- Update trainer animations
    if trainer then
        trainer:update(dt)
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

    -- Draw the typing trainer interface
    trainer:draw(50, 50, screenWidth - 100, screenHeight - 100)
end

-- Handle keyboard input
function RoundState.keypressed(key)
    if not trainer then return end

    if not trainer.finished then
        if key == "backspace" then
            -- Handle backspace
            trainer:backspace()
        elseif key == "escape" then
            -- Finish early and return to menu
            trainer:finish()
        end
    else
        -- Handle post-completion navigation
        if key == "return" or key == "kpenter" then
            -- Check if player advanced to next round
            if roundStats then
                local advanced = player:advanceRound(roundStats.score)
                if advanced then
                    -- Proceed to next round
                    StateManager.switch("roundState")
                else
                    -- Go to shop
                    StateManager.switch("shopState")
                end
            else
                -- Default to menu if no stats
                StateManager.switch("menuState")
            end
        elseif key == "escape" then
            StateManager.switch("menuState")
        end
    end
end

-- Handle text input for typing
function RoundState.textinput(text)
    if not trainer or trainer.finished then return end
    trainer:handleInput(text)
end

return RoundState