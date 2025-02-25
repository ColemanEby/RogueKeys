-- modules/typing/textGenerator.lua
-- Enhanced text generator with multiple modes and difficulty levels

local ConfigManager = require("engine/configManager")

local TextGenerator = {
    words = {},
    quotes = {},
    paragraphs = {},
    loaded = false
}

-- Default settings if not specified in config
local DEFAULT_SETTINGS = {
    sentenceLength = 12,
    maxWordSize = 10,
    minWordSize = 2,
    capitalizeSentences = true,
    endWithPunctuation = true
}

-- Load word lists and other text resources
function TextGenerator:loadResources()
    if self.loaded then
        return true
    end

    -- Load word list
    local success = self:loadWordList()
    if not success then
        print("TextGenerator: Failed to load word list")
        return false
    end

    -- Load quotes (if available)
    self:loadQuotes()

    -- Load paragraphs (if available)
    self:loadParagraphs()

    self.loaded = true
    return true
end

-- Load the word list from a file
function TextGenerator:loadWordList()
    local wordPath = "data/words.txt"

    -- Check if file exists
    if not love.filesystem.getInfo(wordPath) then
        print("TextGenerator: Word file not found at " .. wordPath)

        -- Create a minimal fallback word list
        local fallbackWords = {"the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
                               "hello", "world", "typing", "practice", "keyboard", "skills"}
        self.words = fallbackWords
        return true
    end

    -- Read word file
    local content, size = love.filesystem.read(wordPath)
    if not content then
        print("TextGenerator: Failed to read word file")
        return false
    end

    -- Parse words
    for word in content:gmatch("[%a']+") do
        if #word >= DEFAULT_SETTINGS.minWordSize and #word <= DEFAULT_SETTINGS.maxWordSize then
            table.insert(self.words, word:lower())
        end
    end

    print("TextGenerator: Loaded " .. #self.words .. " words")
    return true
end

-- Load quotes from a file
function TextGenerator:loadQuotes()
    local quotesPath = "data/quotes.txt"

    -- Check if file exists
    if not love.filesystem.getInfo(quotesPath) then
        return false
    end

    -- Read quotes file
    local content, size = love.filesystem.read(quotesPath)
    if not content then
        return false
    end

    -- Parse quotes (one per line)
    for line in content:gmatch("[^\r\n]+") do
        if #line > 0 then
            table.insert(self.quotes, line)
        end
    end

    print("TextGenerator: Loaded " .. #self.quotes .. " quotes")
    return true
end

-- Load paragraphs from a file
function TextGenerator:loadParagraphs()
    local paragraphsPath = "data/paragraphs.txt"

    -- Check if file exists
    if not love.filesystem.getInfo(paragraphsPath) then
        return false
    end

    -- Read paragraphs file
    local content, size = love.filesystem.read(paragraphsPath)
    if not content then
        return false
    end

    -- Parse paragraphs (separated by double newlines)
    for paragraph in content:gmatch("([^\n\r]+)\r?\n\r?\n") do
        if #paragraph > 0 then
            table.insert(self.paragraphs, paragraph)
        end
    end

    print("TextGenerator: Loaded " .. #self.paragraphs .. " paragraphs")
    return true
end

-- Generate a random sentence
function TextGenerator:generateSentence(options)
    if not self.loaded then
        self:loadResources()
    end

    options = options or {}
    local sentenceLength = options.sentenceLength or DEFAULT_SETTINGS.sentenceLength
    local capitalize = options.capitalizeSentences ~= false  -- Default to true
    local endWithPunctuation = options.endWithPunctuation ~= false  -- Default to true

    local sentence = ""

    -- Ensure we have words to use
    if #self.words == 0 then
        return "No words available for text generation."
    end

    -- Generate the sentence word by word
    for i = 1, sentenceLength do
        local word = self.words[love.math.random(#self.words)]

        -- Capitalize first word
        if i == 1 and capitalize then
            word = word:sub(1, 1):upper() .. word:sub(2)
        end

        -- Add space before words (except first)
        if i > 1 then
            sentence = sentence .. " "
        end

        sentence = sentence .. word
    end

    -- Add punctuation at the end
    if endWithPunctuation then
        -- Randomly select a punctuation mark
        local punctuation = "."
        local rand = love.math.random(10)
        if rand == 9 then
            punctuation = "?"
        elseif rand == 10 then
            punctuation = "!"
        end

        sentence = sentence .. punctuation
    end

    return sentence
end

-- Generate a random paragraph of sentences
function TextGenerator:generateParagraph(options)
    options = options or {}
    local sentenceCount = options.sentenceCount or 3
    local sentenceOptions = {
        sentenceLength = options.sentenceLength or DEFAULT_SETTINGS.sentenceLength,
        capitalizeSentences = options.capitalizeSentences,
        endWithPunctuation = true  -- Always true for paragraph sentences
    }

    local paragraph = ""

    for i = 1, sentenceCount do
        paragraph = paragraph .. self:generateSentence(sentenceOptions)
        if i < sentenceCount then
            paragraph = paragraph .. " "
        end
    end

    return paragraph
end

-- Get a random text based on difficulty
function TextGenerator:getRandomText(difficulty)
    if not self.loaded then
        self:loadResources()
    end

    -- Get difficulty settings from config
    local diffSettings
    if difficulty then
        diffSettings = ConfigManager:getDifficulty(difficulty)
    end

    if not diffSettings then
        -- Use medium difficulty as default
        diffSettings = ConfigManager:getDifficulty("medium")
    end

    -- Create options based on difficulty
    local options = {
        sentenceLength = diffSettings.sentenceLength or DEFAULT_SETTINGS.sentenceLength,
        maxWordSize = diffSettings.maxWordSize or DEFAULT_SETTINGS.maxWordSize,
        capitalizeSentences = true,
        endWithPunctuation = true
    }

    -- For harder difficulties, try to use quotes or paragraphs if available
    if difficulty == "hard" and #self.quotes > 0 then
        return self.quotes[love.math.random(#self.quotes)]
    elseif difficulty == "hard" and #self.paragraphs > 0 then
        return self.paragraphs[love.math.random(#self.paragraphs)]
    else
        -- Default to sentence generation
        return self:generateSentence(options)
    end
end

-- Get a multi-sentence text for longer challenges
function TextGenerator:getLongText(difficulty, sentenceCount)
    if not self.loaded then
        self:loadResources()
    end

    -- Determine sentence count based on difficulty if not specified
    if not sentenceCount then
        if difficulty == "easy" then
            sentenceCount = 2
        elseif difficulty == "medium" then
            sentenceCount = 3
        else -- hard
            sentenceCount = 5
        end
    end

    -- Get difficulty settings
    local diffSettings = ConfigManager:getDifficulty(difficulty) or
            ConfigManager:getDifficulty("medium")

    -- For hard difficulty, try to use a paragraph first
    if difficulty == "hard" and #self.paragraphs > 0 then
        return self.paragraphs[love.math.random(#self.paragraphs)]
    end

    -- Create options for paragraph generation
    local options = {
        sentenceCount = sentenceCount,
        sentenceLength = diffSettings.sentenceLength,
        maxWordSize = diffSettings.maxWordSize,
        capitalizeSentences = true
    }

    return self:generateParagraph(options)
end

-- Preload resources to avoid delays during gameplay
function TextGenerator:preload()
    return self:loadResources()
end

return TextGenerator