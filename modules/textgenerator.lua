-- modules/textgenerator.lua
local TextGenerator = {}
TextGenerator.texts = {}
TextGenerator.loaded = false

local SENTENCE_LENGTH = 12
local MAX_WORD_SIZE = 10

function TextGenerator:getRandomText()

   if not self.loaded then
      self:loadWords()
   end

   local sentence = ""

   for word = 1, SENTENCE_LENGTH do
      local next = self.texts[love.math.random(#self.texts)]

      -- Capitalize the first letter in the first word.
      if word == 1 then
         next = string.upper(string.sub(next, 1, 1)) .. string.sub(next, 2)
      end

      sentence = sentence .. next .. " "
   end

   sentence = sentence .. "."

   return sentence
end

function TextGenerator:loadWords()
   local file, err = io.open("./data/words.txt", "r")

   if not file then
      print("Failed to open word file! (" .. tostring(err) .. ")")
      return
   end

   for line in file:lines() do
      if #line <= MAX_WORD_SIZE then
         table.insert(self.texts, line)
      end
   end

   self.loaded = true
   file:close()
end

return TextGenerator