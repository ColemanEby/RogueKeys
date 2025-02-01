-- modules/textgenerator.lua
local TextGenerator = {}

function TextGenerator.getRandomText()
   local texts = {
      "The quick brown fox jumps over the lazy dog.",
      "Practice makes perfect.",
      "Hello world, welcome to the typing trainer.",
      "Typing speed and accuracy are key."
   }
   return texts[love.math.random(#texts)]
end

return TextGenerator
