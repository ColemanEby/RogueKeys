-- modules/typing/trainer.lua
-- Enhanced typing trainer with more features and extensibility

local ResourceManager = require("engine/resourceManager")

local TypingTrainer = {}
TypingTrainer.__index = TypingTrainer

-- Create a new typing trainer instance
function TypingTrainer.new(options)
    local self = setmetatable({}, TypingTrainer)

    options = options or {}

    -- Target text and options
    self.text = options.text or "Default text"
    self.displayName = options.displayName or "Standard Typing Challenge"
    self.difficulty = options.difficulty or "medium"
    self.timeLimit = options.timeLimit or 0  -- 0 means no time limit
    self.keyboardModel = options.keyboardModel  -- Optional reference to player's keyboard

    -- Typing progress state
    self.typed = {}           -- Stores each keystroke as { char, correct = true/false }
    self.startTime = love.timer.getTime()
    self.finished = false
    self.correctCount = 0
    self.mistakes = 0
    self.currentStreak = 0
    self.longestStreak = 0
    self.score = 0            -- Accumulated score
    self.highscore = options.highscore or 0

    -- UI options
    self.uiStyle = options.uiStyle or {
        backgroundColor = {0.12, 0.12, 0.15, 1.0},
        titleColor = {1.0, 1.0, 1.0, 1.0},
        promptColor = {0.8, 0.8, 0.8, 1.0},
        correctColor = {0.2, 0.9, 0.2, 1.0},
        incorrectColor = {0.9, 0.2, 0.2, 1.0},
        cursorColor = {0.2, 0.6, 1.0, 1.0},
        statsColor = {0.9, 0.9, 0.9, 1.0},
        statsBgColor = {0.2, 0.2, 0.2, 0.8},
        padding = 20,
        titleFont = "default",
        titleFontSize = 24,
        textFont = "default",
        textFontSize = 18,
        statsFont = "default",
        statsFontSize = 16
    }

    -- Load fonts
    self:loadFonts()

    -- Event callbacks
    self.onKeyPressed = options.onKeyPressed
    self.onKeyMissed = options.onKeyMissed
    self.onComplete = options.onComplete

    -- Timers and animation
    self.cursorBlinkTimer = 0
    self.cursorVisible = true
    self.shakingText = false
    self.shakeTimer = 0
    self.shakeIntensity = 0

    return self
end

-- Load fonts for rendering
function TypingTrainer:loadFonts()
    local style = self.uiStyle
    self.titleFont = ResourceManager:getFont(style.titleFont, style.titleFontSize)
    self.textFont = ResourceManager:getFont(style.textFont, style.textFontSize)
    self.statsFont = ResourceManager:getFont(style.statsFont, style.statsFontSize)
end

-- Handle input from the user
function TypingTrainer:handleInput(char)
    if self.finished then return end

    local index = #self.typed + 1
    local expectedChar = self.text:sub(index, index)
    local isCorrect = (char == expectedChar)
    table.insert(self.typed, { char = char, correct = isCorrect })

    if isCorrect then
        self.correctCount = self.correctCount + 1
        self.currentStreak = self.currentStreak + 1

        if self.currentStreak > self.longestStreak then
            self.longestStreak = self.currentStreak
        end

        -- Base score for a correct keystroke
        local baseScore = 1

        -- Add keyboard bonus if available
        if self.keyboardModel then
            -- Global multiplier
            local multiplier = self.keyboardModel:getTotalMultiplier() or 1.0

            -- Per-key bonus
            local keyLower = char:lower()
            local bonus = self.keyboardModel:getKeyBonus(keyLower) or 0

            -- Apply both bonuses
            self.score = self.score + (baseScore * multiplier) + bonus
        else
            self.score = self.score + baseScore
        end

        -- Trigger callback if provided
        if self.onKeyPressed then
            self.onKeyPressed(char, true)
        end
    else
        self.mistakes = self.mistakes + 1
        self.currentStreak = 0

        -- Shake effect for incorrect keypress
        self:startShake(0.3, 5)

        -- Trigger callback if provided
        if self.onKeyMissed then
            self.onKeyMissed(char, expectedChar)
        end
    end

    -- Auto-finish if we've typed the entire text
    if #self.typed >= #self.text then
        self:finish()
    end
end

-- Handle backspace key
function TypingTrainer:backspace()
    if self.finished then return end
    if #self.typed == 0 then return end

    local removed = table.remove(self.typed)

    if removed.correct then
        self.correctCount = self.correctCount - 1

        -- Adjust score (approximate, as we don't store the exact bonus per keystroke)
        if self.keyboardModel then
            local keyLower = removed.char:lower()
            local bonus = self.keyboardModel:getKeyBonus(keyLower) or 0
            local multiplier = self.keyboardModel:getTotalMultiplier() or 1.0

            self.score = self.score - ((1 * multiplier) + bonus)
        else
            self.score = self.score - 1
        end
    else
        self.mistakes = self.mistakes - 1
    end

    -- Recalculate current streak
    local streak = 0
    for i = #self.typed, 1, -1 do
        if self.typed[i].correct then
            streak = streak + 1
        else
            break
        end
    end
    self.currentStreak = streak
end

-- Finish the typing session
function TypingTrainer:finish()
    if not self.finished then
        self.finished = true
        self.endTime = love.timer.getTime()

        -- Check for high score
        if self.score > self.highscore then
            self.highscore = self.score
        end

        -- Call the completion callback if provided
        if self.onComplete then
            local stats = self:getStats()
            self.onComplete(stats)
        end
    end
end

-- Calculate time taken
function TypingTrainer:getTimeTaken()
    if self.finished then
        return self.endTime - self.startTime
    else
        return love.timer.getTime() - self.startTime
    end
end

-- Calculate typing accuracy
function TypingTrainer:getAccuracy()
    local total = #self.typed
    if total == 0 then return 0 end
    return (self.correctCount / total) * 100
end

-- Calculate actions per minute (keystrokes)
function TypingTrainer:getAPM()
    local timeTaken = self:getTimeTaken()
    if timeTaken < 0.01 then return 0 end  -- Avoid division by zero
    local keystrokes = #self.typed
    return (keystrokes / timeTaken) * 60
end

-- Get words per minute (based on standard 5 chars per word)
function TypingTrainer:getWPM()
    local timeTaken = self:getTimeTaken()
    if timeTaken < 0.01 then return 0 end  -- Avoid division by zero
    return (self.correctCount / 5) / (timeTaken / 60)
end

-- Get complete stats for the session
function TypingTrainer:getStats()
    return {
        displayName = self.displayName,
        difficulty = self.difficulty,
        keystrokes = #self.typed,
        correct = self.correctCount,
        mistakes = self.mistakes,
        accuracy = self:getAccuracy(),
        timeTaken = self:getTimeTaken(),
        apm = self:getAPM(),
        wpm = self:getWPM(),
        longestStreak = self.longestStreak,
        score = self.score,
        highscore = self.highscore,
        completed = self.finished
    }
end

-- Start a shake animation
function TypingTrainer:startShake(duration, intensity)
    self.shakingText = true
    self.shakeTimer = duration or 0.3
    self.shakeIntensity = intensity or 5
end

-- Update animations and timers
function TypingTrainer:update(dt)
    -- Update cursor blink
    self.cursorBlinkTimer = self.cursorBlinkTimer + dt
    if self.cursorBlinkTimer >= 0.5 then
        self.cursorBlinkTimer = self.cursorBlinkTimer - 0.5
        self.cursorVisible = not self.cursorVisible
    end

    -- Update shake effect
    if self.shakingText then
        self.shakeTimer = self.shakeTimer - dt
        if self.shakeTimer <= 0 then
            self.shakingText = false
        end
    end

    -- Check for time limit
    if not self.finished and self.timeLimit > 0 then
        if self:getTimeTaken() >= self.timeLimit then
            self:finish()
        end
    end
end

-- Draw the typing interface
function TypingTrainer:draw(x, y, width, height)
    local style = self.uiStyle
    x = x or style.padding
    y = y or style.padding
    width = width or (love.graphics.getWidth() - style.padding * 2)
    height = height or (love.graphics.getHeight() - style.padding * 2)

    -- Set up fonts
    love.graphics.setFont(self.titleFont)

    -- Draw title
    love.graphics.setColor(style.titleColor)
    love.graphics.printf(self.displayName, x, y, width, "center")
    y = y + self.titleFont:getHeight() + style.padding

    -- Draw prompt
    love.graphics.setFont(self.textFont)
    local promptText = "Type the text below:"
    love.graphics.setColor(style.promptColor)
    love.graphics.printf(promptText, x, y, width, "left")
    y = y + self.textFont:getHeight() + style.padding / 2

    -- Calculate the text area bounds
    local textAreaWidth = width
    local textAreaHeight = self.textFont:getHeight() * 3 -- Adjust for multi-line

    -- Draw text area background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
    love.graphics.rectangle("fill", x, y, textAreaWidth, textAreaHeight, 5, 5)
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("line", x, y, textAreaWidth, textAreaHeight, 5, 5)

    -- Draw the text content with color highlighting
    local textX = x + style.padding / 2
    local textY = y + style.padding / 2

    -- Apply shake if active
    if self.shakingText then
        local shakeX = love.math.random(-self.shakeIntensity, self.shakeIntensity)
        local shakeY = love.math.random(-self.shakeIntensity, self.shakeIntensity)
        textX = textX + shakeX
        textY = textY + shakeY
    end

    -- Draw each character with appropriate color
    local currentX = textX
    local lineHeight = self.textFont:getHeight()
    local lineWidth = 0
    local maxLineWidth = textAreaWidth - style.padding

    for i = 1, #self.text do
        local char = self.text:sub(i, i)
        local charWidth = self.textFont:getWidth(char)

        -- Wrap to next line if needed
        if lineWidth + charWidth > maxLineWidth then
            currentX = textX
            textY = textY + lineHeight
            lineWidth = 0
        end

        -- Determine character color based on typing progress
        local color
        if i <= #self.typed then
            if self.typed[i].correct then
                color = style.correctColor
            else
                color = style.incorrectColor
            end
        else
            color = style.promptColor
        end

        -- Draw the character
        love.graphics.setColor(color)
        love.graphics.print(char, currentX, textY)

        -- Draw cursor at current position
        if i == #self.typed + 1 and self.cursorVisible and not self.finished then
            love.graphics.setColor(style.cursorColor)
            love.graphics.rectangle("fill", currentX, textY, 2, lineHeight)
        end

        -- Move to next character position
        currentX = currentX + charWidth
        lineWidth = lineWidth + charWidth
    end

    -- Move below the text area for stats
    y = y + textAreaHeight + style.padding

    -- Draw stats in a grid layout
    love.graphics.setFont(self.statsFont)
    local statsBoxWidth = width / 2 - style.padding / 2
    local statsBoxHeight = self.statsFont:getHeight() + style.padding

    -- Stats to display (in left/right columns)
    local stats = {
        { label = "Time", value = string.format("%.1fs", self:getTimeTaken()) },
        { label = "Accuracy", value = string.format("%.1f%%", self:getAccuracy()) },
        { label = "WPM", value = string.format("%.1f", self:getWPM()) },
        { label = "APM", value = string.format("%.1f", self:getAPM()) },
        { label = "Errors", value = tostring(self.mistakes) },
        { label = "Score", value = string.format("%.0f", self.score) }
    }

    -- Draw stats boxes
    for i, stat in ipairs(stats) do
        local col = (i - 1) % 2  -- 0 for left column, 1 for right
        local row = math.floor((i - 1) / 2)

        local boxX = x + col * (statsBoxWidth + style.padding)
        local boxY = y + row * (statsBoxHeight + style.padding / 2)

        -- Draw box background
        love.graphics.setColor(style.statsBgColor)
        love.graphics.rectangle("fill", boxX, boxY, statsBoxWidth, statsBoxHeight, 3, 3)

        -- Draw label and value
        love.graphics.setColor(style.statsColor)
        love.graphics.print(stat.label .. ": " .. stat.value, boxX + style.padding / 2, boxY + style.padding / 4)
    end

    -- Draw completion message
    if self.finished then
        y = y + 3 * (statsBoxHeight + style.padding / 2) + style.padding

        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("Press Enter to continue", x, y, width, "center")
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return TypingTrainer