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

-- The draw method displays the prompt text, typed characters, and stats.
function TypingTrainer:draw(x, y)
    x = x or 20
    y = y or 20

    -- Draw a header.
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Type the text below:", x, y, love.graphics.getWidth() - 40, "left")
    y = y + 30

    -- Display the text that has been typed.
    local typedStr = self.text:sub(1, #self.typed)
    local remainingStr = self.text:sub(#self.typed + 1)
    love.graphics.setColor(0, 1, 0)  -- green for correctly typed text
    love.graphics.print(typedStr, x, y)
    local typedWidth = love.graphics.getFont():getWidth(typedStr)
    love.graphics.setColor(1, 1, 1)  -- white for remaining text
    love.graphics.print(remainingStr, x + typedWidth, y)
    y = y + 30

    -- Display stats.
    local accuracy = (#self.typed > 0) and (self.correctCount / #self.typed * 100) or 0
    love.graphics.printf(string.format("Score: %.2f", self.score), x, y, love.graphics.getWidth() - 40, "left")
    y = y + 20
    love.graphics.printf(string.format("Accuracy: %.2f%%", accuracy), x, y, love.graphics.getWidth() - 40, "left")
    y = y + 20
    love.graphics.printf(string.format("Time: %.2fs", self:getTimeTaken()), x, y, love.graphics.getWidth() - 40, "left")
end

return TypingTrainer
