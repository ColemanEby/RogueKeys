-- modules/typingtrainer.lua
local TypingTrainer = {}
TypingTrainer.__index = TypingTrainer

function TypingTrainer.new(text)
    local self = setmetatable({}, TypingTrainer)
    self.text = text or "Default text"
    self.currentIndex = 1
    self.startTime = love.timer.getTime()
    self.finished = false
    self.correctCount = 0
    self.mistakes = 0
    self.userInput = ""
    return self
end

-- Call this method for each new character typed
function TypingTrainer:update(char)
    if self.finished then return end

    local expectedChar = self.text:sub(self.currentIndex, self.currentIndex)
    if char == expectedChar then
         self.correctCount = self.correctCount + 1
    else
         self.mistakes = self.mistakes + 1
    end

    self.userInput = self.userInput .. char
    self.currentIndex = self.currentIndex + 1

    if self.currentIndex > #self.text then
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
    local total = self.correctCount + self.mistakes
    if total == 0 then return 0 end
    return (self.correctCount / total) * 100
end

function TypingTrainer:draw(x, y)
   x = x or 20
   y = y or 20

   love.graphics.print("Type the text below:", x, y)
   y = y + 20

   local correctText = self.text:sub(1, self.currentIndex - 1)
   local remainingText = self.text:sub(self.currentIndex)

   -- Draw the correctly typed portion in green
   love.graphics.setColor(0, 1, 0)
   love.graphics.print(correctText, x, y)
   
   -- Draw the remaining text in white
   love.graphics.setColor(1, 1, 1)
   local correctWidth = love.graphics.getFont():getWidth(correctText)
   love.graphics.print(remainingText, x + correctWidth, y)
   love.graphics.setColor(1, 1, 1)

   y = y + 30
   love.graphics.print(string.format("Time: %.2fs", self:getTimeTaken()), x, y)
   y = y + 20
   love.graphics.print(string.format("Accuracy: %.2f%%", self:getAccuracy()), x, y)
end

return TypingTrainer
