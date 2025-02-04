-- modules/typingtrainer.lua
local TypingTrainer = {}
TypingTrainer.__index = TypingTrainer

local Player = require("modules/player")  -- so we can access Player.keyboard.upgrades

function TypingTrainer.new(text)
    local self = setmetatable({}, TypingTrainer)
    self.text = text or "Default text"
    self.typed = {}          -- stores each keystroke as { char, correct = true/false }
    self.startTime = love.timer.getTime()
    self.finished = false
    self.correctCount = 0
    self.mistakes = 0
    self.currentStreak = 0
    self.longestStreak = 0
    self.score = 0           -- accumulated score (base 1 per correct keystroke + per-key bonus)

    -- Create a base font size relative to the window width.
    local windowWidth = love.graphics.getWidth()
    local baseFontSize = math.floor(windowWidth / 30) -- adjust divisor to taste
    self.font = love.graphics.newFont(baseFontSize)
    return self
end

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
         -- Base score for a correct keystroke:
         self.score = self.score + 1
         -- Add bonus if the player's keyboard has an upgrade for this key.
         local keyLower = char:lower()
         if Player.keyboard and Player.keyboard.upgrades then
             local bonus = Player.keyboard.upgrades[keyLower] or 0
             self.score = self.score + bonus
         end
    else
         self.mistakes = self.mistakes + 1
         self.currentStreak = 0
    end
end

function TypingTrainer:backspace()
    if self.finished then return end
    if #self.typed > 0 then
         local removed = table.remove(self.typed)
         if removed.correct then
             self.correctCount = self.correctCount - 1
             self.score = self.score - 1
             local keyLower = removed.char:lower()
             if Player.keyboard and Player.keyboard.upgrades then
                 local bonus = Player.keyboard.upgrades[keyLower] or 0
                 self.score = self.score - bonus
             end
         else
             self.mistakes = self.mistakes - 1
         end

         -- Recalculate the current streak from the end of the typed array.
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
end

function TypingTrainer:finish()
    if not self.finished and #self.typed == #self.text then
         self.finished = true
         self.endTime = love.timer.getTime()
    end
end


function TypingTrainer:getTimeTaken()
    if not self.finished then
        return love.timer.getTime() - self.startTime
    else
        return self.endTime - self.startTime
    end
end

function TypingTrainer:getAccuracy()
    local total = #self.typed
    if total == 0 then return 0 end
    return (self.correctCount / total) * 100
end

function TypingTrainer:getAPM()
    local timeTaken = self:getTimeTaken()
    if timeTaken == 0 then return 0 end
    local keystrokes = #self.typed
    return (keystrokes / timeTaken) * 60
end

-- The draw method displays the prompt text, typed characters, and stats.
function TypingTrainer:draw(x, y)
    x = x or 20
    y = y or 20
    local screenWidth = love.graphics.getWidth()
    local margin = 20

    -- Set our font for all text.
    love.graphics.setFont(self.font)

    ---------------------------
    -- Draw Header in a Box --
    ---------------------------
    local header = "Type the text below:"
    local headerWidth = self.font:getWidth(header)
    local headerHeight = self.font:getHeight()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x - 5, y - 5, headerWidth + 10, headerHeight + 10)
    love.graphics.print(header, x, y)
    y = y + headerHeight + 20

    -----------------------------------------------------
    -- Draw the Target Text (letter-by-letter with boxes) --
    -----------------------------------------------------
    -- Calculate available width for the target text (with margins)
    local availableWidth = screenWidth - margin * 2

    -- First, compute the unscaled total width of the target text (if drawn on one line)
    local totalWidth = 0
    for i = 1, #self.text do
        local char = self.text:sub(i, i)
        totalWidth = totalWidth + self.font:getWidth(char)
    end

    -- Determine a scale factor to ensure the text does not overflow.
    local scaleFactor = 1
    if totalWidth > availableWidth then
        scaleFactor = availableWidth / totalWidth
    end

    -- We'll draw the target text inside its own box(es) using a scaled coordinate system.
    love.graphics.push()
    love.graphics.translate(margin, y)
    love.graphics.scale(scaleFactor, scaleFactor)
    
    -- In the scaled coordinates, the available width becomes:
    local scaledAvailableWidth = availableWidth / scaleFactor

    -- Draw each letter with its own box.
    local offsetX = 0
    local offsetY = 0
    local lineHeight = self.font:getHeight() + 8  -- additional spacing for the box

    for i = 1, #self.text do
        local char = self.text:sub(i, i)
        local letterWidth = self.font:getWidth(char)

        -- Wrap to next line if drawing the next letter would exceed the available width.
        if offsetX + letterWidth > scaledAvailableWidth then
            offsetX = 0
            offsetY = offsetY + lineHeight
        end

        -- Determine the color based on typing feedback.
        local drawColor = {1, 1, 1}  -- default white
        if i <= #self.typed then
            local entry = self.typed[i]
            if entry.correct then
                drawColor = {0, 1, 0}  -- green if correct
            else
                drawColor = {1, 0, 0}  -- red if incorrect
            end
        elseif i == #self.typed + 1 then
            drawColor = {0, 0, 1}      -- blue indicates the next expected letter
        end

        -- -- Draw a box behind the letter.
        -- love.graphics.setColor(1, 1, 1)  -- white box outline
        -- love.graphics.rectangle("line", offsetX - 2, offsetY - 2, letterWidth + 4, self.font:getHeight() + 4)

        -- Draw the letter.
        love.graphics.setColor(drawColor)
        love.graphics.print(char, offsetX, offsetY)

        offsetX = offsetX + letterWidth
    end
    love.graphics.pop()

    -- Adjust y to be after the target text.
    local linesUsed = math.ceil((totalWidth * scaleFactor) / availableWidth)
    y = y + (lineHeight * linesUsed) + 20

    ----------------------------
    -- Draw Session Stats Boxes --
    ----------------------------
    local statsData = {
        string.format("Time: %.2fs", self:getTimeTaken()),
        string.format("Accuracy: %.2f%%", self:getAccuracy()),
        string.format("APM: %.2f", self:getAPM()),
        string.format("Errors: %d", self.mistakes),
        string.format("Longest Streak: %d", self.longestStreak)
    }

    for _, textLine in ipairs(statsData) do
        local textWidth = self.font:getWidth(textLine)
        local textHeight = self.font:getHeight()
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x - 5, y - 5, textWidth + 10, textHeight + 10)
        love.graphics.print(textLine, x, y)
        y = y + textHeight + 20
    end

    love.graphics.setColor(1, 1, 1)
end

return TypingTrainer
