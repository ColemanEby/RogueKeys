-- modules/typing/textGenerator.lua
-- Enhanced text generator with multiple modes and difficulty levels

local ConfigManager = require("engine/configManager")

local TextGenerator = {
    wordsByLength = {},   -- [length] = { word, word, ... }, bucketed once at load
    wordCount = 0,
    minWordLen = nil,     -- shortest word length actually present in the corpus
    maxWordLen = nil,     -- longest word length actually present in the corpus
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

-- ConfigManager's difficulty table only defines maxWordSize; the minimum bound
-- per difficulty lives here so "easy" can't roll monster words just because a
-- ceiling was set. Keyed by the difficulty's lowercase name so it still lines
-- up if getDifficulty() falls back to medium for an unknown level.
local DIFFICULTY_MIN_WORD_SIZE = {
    easy = 2,
    medium = 3,
    hard = 4
}

-- Longer rounds get longer text; capped so late-game rounds stay typeable.
local ROUND_LENGTH_STEP = 1
local ROUND_LENGTH_CAP = 20

-- "timed_burst" mutator: there's a hard clock, so trim the ask.
local TIMED_BURST_FACTOR = 0.6
local TIMED_BURST_MIN_WORDS = 3

-- A handful of public-domain lines so "hard" text has real flavor even
-- without data/quotes.txt shipped. Deliberately small -- this is a fallback,
-- not a content pack.
local FALLBACK_QUOTES = {
    "Two roads diverged in a wood, and I took the one less traveled by.",
    "It was the best of times, it was the worst of times.",
    "All that glitters is not gold.",
    "The only thing we have to fear is fear itself.",
    "In the beginning God created the heaven and the earth.",
    "Call me Ishmael.",
    "It is a truth universally acknowledged, that a single man in possession of a good fortune must be in want of a wife.",
    "Whether I shall turn out to be the hero of my own life, or whether that station will be held by anybody else, these pages must show."
}

-- Pull a random index/value either from the shared global RNG or a caller
-- supplied RandomGenerator, so seeded generation never perturbs global state.
local function rrandom(rng, ...)
    if rng then
        return rng:random(...)
    end
    return love.math.random(...)
end

-- Mutator ids may arrive as an array ({"decaying_text", "timed_burst"}) or a
-- set ({decaying_text = true}); normalize to a set so lookups are cheap and
-- unrecognized ids are simply inert rather than erroring.
local function normalizeMutators(mutators)
    local set = {}
    if type(mutators) ~= "table" then
        return set
    end
    for k, v in pairs(mutators) do
        if type(k) == "number" and type(v) == "string" then
            set[v] = true
        elseif type(k) == "string" and v then
            set[k] = true
        end
    end
    return set
end

-- Load word lists and other text resources
function TextGenerator:loadResources()
    if self.loaded then
        return true
    end

    local success = self:loadWordList()
    if not success then
        if _G.DEBUG_MODE then print("TextGenerator: failed to load word list") end
        return false
    end

    self:loadQuotes()
    self:loadParagraphs()

    self.loaded = true
    return true
end

-- Drop everything back to an unloaded state. Mainly for tests that need to
-- force a fresh load (e.g. simulating a missing word file).
function TextGenerator:reset()
    self.wordsByLength = {}
    self.wordCount = 0
    self.minWordLen = nil
    self.maxWordLen = nil
    self.quotes = {}
    self.paragraphs = {}
    self.loaded = false
end

-- Add a word to the length bucket, tracking the loaded min/max so range
-- lookups outside the corpus can fall back to something sane.
function TextGenerator:_bucketWord(word)
    local len = #word
    local bucket = self.wordsByLength[len]
    if not bucket then
        bucket = {}
        self.wordsByLength[len] = bucket
    end
    bucket[#bucket + 1] = word
    self.wordCount = self.wordCount + 1
    if not self.minWordLen or len < self.minWordLen then self.minWordLen = len end
    if not self.maxWordLen or len > self.maxWordLen then self.maxWordLen = len end
end

-- Load the word list from a file, bucketing by length so difficulty-based
-- selection is an O(range) lookup instead of a rejection loop over the whole
-- corpus (369k+ words).
function TextGenerator:loadWordList()
    local wordPath = "data/words.txt"

    if not love.filesystem.getInfo(wordPath) then
        if _G.DEBUG_MODE then print("TextGenerator: word file not found at " .. wordPath) end

        local fallbackWords = { "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
                                 "hello", "world", "typing", "practice", "keyboard", "skills" }
        for _, word in ipairs(fallbackWords) do
            self:_bucketWord(word)
        end
        return true
    end

    local content = love.filesystem.read(wordPath)
    if not content then
        if _G.DEBUG_MODE then print("TextGenerator: failed to read word file") end
        return false
    end

    -- Sane bounds discard pathological outliers (stray hyphenated compounds,
    -- OCR noise, etc.) without needing a difficulty-specific cutoff here.
    for word in content:gmatch("[%a']+") do
        local len = #word
        if len >= 1 and len <= 30 then
            self:_bucketWord(word:lower())
        end
    end
    content = nil -- let the 4.2MB source string go once it's tokenized

    if _G.DEBUG_MODE then print("TextGenerator: loaded " .. self.wordCount .. " words") end
    return self.wordCount > 0
end

-- Load quotes from a file, falling back to a small embedded set so hard
-- difficulty's quote path is real rather than permanently unreachable.
function TextGenerator:loadQuotes()
    local quotesPath = "data/quotes.txt"

    if not love.filesystem.getInfo(quotesPath) then
        for _, quote in ipairs(FALLBACK_QUOTES) do
            table.insert(self.quotes, quote)
        end
        return true
    end

    local content = love.filesystem.read(quotesPath)
    if not content then
        return false
    end

    for line in content:gmatch("[^\r\n]+") do
        if #line > 0 then
            table.insert(self.quotes, line)
        end
    end

    if _G.DEBUG_MODE then print("TextGenerator: loaded " .. #self.quotes .. " quotes") end
    return true
end

-- Load paragraphs from a file. There is no embedded fallback here (that would
-- mean shipping a real content block in source) -- if the asset is absent,
-- callers cleanly fall through to generated paragraphs instead.
function TextGenerator:loadParagraphs()
    local paragraphsPath = "data/paragraphs.txt"

    if not love.filesystem.getInfo(paragraphsPath) then
        return false
    end

    local content = love.filesystem.read(paragraphsPath)
    if not content then
        return false
    end

    for paragraph in content:gmatch("([^\n\r]+)\r?\n\r?\n") do
        if #paragraph > 0 then
            table.insert(self.paragraphs, paragraph)
        end
    end

    if _G.DEBUG_MODE then print("TextGenerator: loaded " .. #self.paragraphs .. " paragraphs") end
    return true
end

-- Sum word counts across the length buckets in [minSize, maxSize] and pick
-- one, weighted by bucket size. Returns nil if nothing in the corpus falls in
-- that range at all.
function TextGenerator:_pickWordInRange(minSize, maxSize, rng)
    if not minSize or not maxSize then return nil end

    local total = 0
    local lens = {}
    for len = minSize, maxSize do
        local bucket = self.wordsByLength[len]
        local n = bucket and #bucket or 0
        if n > 0 then
            total = total + n
            lens[#lens + 1] = { len = len, cum = total }
        end
    end

    if total == 0 then return nil end

    local r = rrandom(rng, total)
    for _, entry in ipairs(lens) do
        if r <= entry.cum then
            local bucket = self.wordsByLength[entry.len]
            return bucket[rrandom(rng, #bucket)]
        end
    end
end

-- Pick a word honoring [minSize, maxSize]; if the requested range misses the
-- loaded corpus entirely, widen to whatever length range is actually loaded
-- rather than failing.
function TextGenerator:pickWord(minSize, maxSize, rng)
    local word = self:_pickWordInRange(minSize, maxSize, rng)
    if word then return word end
    return self:_pickWordInRange(self.minWordLen, self.maxWordLen, rng) or "word"
end

-- Extra words for later rounds, capped so it doesn't run away.
function TextGenerator:_scaleLengthForRound(baseLength, round)
    if type(round) ~= "number" or round <= 1 then
        return baseLength
    end
    local extra = math.min(ROUND_LENGTH_CAP, math.floor(round - 1) * ROUND_LENGTH_STEP)
    return baseLength + extra
end

-- Generate a random sentence.
-- options: sentenceLength, minWordSize, maxWordSize, capitalizeSentences,
--          endWithPunctuation, rng (a love.math RandomGenerator, or nil for
--          the shared global RNG)
-- Returns the sentence, plus an array of { startIndex, endIndex } word
-- boundaries (1-based, inclusive) into that string.
function TextGenerator:generateSentence(options)
    if not self.loaded then
        self:loadResources()
    end

    options = options or {}
    local sentenceLength = options.sentenceLength or DEFAULT_SETTINGS.sentenceLength
    local minWordSize = options.minWordSize or DEFAULT_SETTINGS.minWordSize
    local maxWordSize = options.maxWordSize or DEFAULT_SETTINGS.maxWordSize
    if minWordSize > maxWordSize then minWordSize, maxWordSize = maxWordSize, minWordSize end
    local capitalize = options.capitalizeSentences ~= false
    local endWithPunctuation = options.endWithPunctuation ~= false
    local rng = options.rng

    if self.wordCount == 0 then
        return "No words available for text generation.", {}
    end

    local words = {}
    for i = 1, sentenceLength do
        local word = self:pickWord(minWordSize, maxWordSize, rng)
        if i == 1 and capitalize then
            word = word:sub(1, 1):upper() .. word:sub(2)
        end
        words[i] = word
    end

    local sentence = table.concat(words, " ")

    -- Boundaries are computed before punctuation is appended so they always
    -- land exactly on the generated words, never on trailing punctuation.
    local boundaries = {}
    local pos = 1
    for i, word in ipairs(words) do
        local startIndex = pos
        local endIndex = pos + #word - 1
        boundaries[i] = { startIndex = startIndex, endIndex = endIndex }
        pos = endIndex + 2 -- word + the single separating space
    end

    if endWithPunctuation then
        local punctuation = "."
        local roll = rrandom(rng, 10)
        if roll == 9 then
            punctuation = "?"
        elseif roll == 10 then
            punctuation = "!"
        end
        sentence = sentence .. punctuation
    end

    return sentence, boundaries
end

-- Generate a random paragraph of sentences. Word boundaries are offset to be
-- relative to the full paragraph, same shape as generateSentence's.
function TextGenerator:generateParagraph(options)
    options = options or {}
    local sentenceCount = options.sentenceCount or 3
    local sentenceOptions = {
        sentenceLength = options.sentenceLength or DEFAULT_SETTINGS.sentenceLength,
        minWordSize = options.minWordSize,
        maxWordSize = options.maxWordSize,
        capitalizeSentences = options.capitalizeSentences,
        endWithPunctuation = true, -- always true for paragraph sentences
        rng = options.rng
    }

    local paragraph = ""
    local boundaries = {}

    for i = 1, sentenceCount do
        local sentenceText, sentenceBoundaries = self:generateSentence(sentenceOptions)
        local offset = #paragraph
        for _, b in ipairs(sentenceBoundaries) do
            boundaries[#boundaries + 1] = { startIndex = b.startIndex + offset, endIndex = b.endIndex + offset }
        end
        paragraph = paragraph .. sentenceText
        if i < sentenceCount then
            paragraph = paragraph .. " "
        end
    end

    return paragraph, boundaries
end

-- Resolve a difficulty argument to ConfigManager's settings table plus the
-- lowercase key actually in effect (accounting for getDifficulty's own
-- fallback-to-medium behavior on unknown levels).
local function resolveDifficulty(difficulty)
    local diffKey = type(difficulty) == "string" and difficulty:lower() or "medium"
    local diffSettings = ConfigManager:getDifficulty(diffKey)
    local resolvedKey = (diffSettings.name and diffSettings.name:lower()) or diffKey
    return diffSettings, resolvedKey
end

-- Get a random text based on difficulty.
-- opts (all optional):
--   seed      - deterministic generation; same seed -> same text
--   round     - later rounds produce longer text
--   mutators  - array or set of run mutator ids ("decaying_text",
--               "timed_burst", "no_backspace", ...). Unknown ids are ignored.
-- Returns text, meta -- meta.wordBoundaries is an array of
-- { startIndex, endIndex } word boundaries into text.
function TextGenerator:getRandomText(difficulty, opts)
    if not self.loaded then
        self:loadResources()
    end
    opts = opts or {}

    local diffSettings, resolvedKey = resolveDifficulty(difficulty)

    local minWordSize = diffSettings.minWordSize or DIFFICULTY_MIN_WORD_SIZE[resolvedKey] or DEFAULT_SETTINGS.minWordSize
    local maxWordSize = diffSettings.maxWordSize or DEFAULT_SETTINGS.maxWordSize

    local sentenceLength = self:_scaleLengthForRound(
        diffSettings.sentenceLength or DEFAULT_SETTINGS.sentenceLength, opts.round)

    local mutators = normalizeMutators(opts.mutators)

    -- "timed_burst": hard time limit, so ask for less text.
    if mutators.timed_burst then
        sentenceLength = math.max(TIMED_BURST_MIN_WORDS, math.floor(sentenceLength * TIMED_BURST_FACTOR))
    end

    -- "no_backspace" needs no generation change -- it changes how the trainer
    -- handles input, not what text it shows.

    local rng = opts.seed ~= nil and love.math.newRandomGenerator(opts.seed) or nil

    local text, boundaries = self:generateSentence({
        sentenceLength = sentenceLength,
        minWordSize = minWordSize,
        maxWordSize = maxWordSize,
        capitalizeSentences = true,
        -- "decaying_text" fades characters ahead of the caret; trailing
        -- punctuation with no following word reads as an awkward orphan
        -- glyph mid-fade, so drop it for that mutator.
        endWithPunctuation = not mutators.decaying_text,
        rng = rng
    })

    return text, {
        wordBoundaries = boundaries,
        mutators = mutators,
        difficulty = resolvedKey,
        round = opts.round or 1
    }
end

-- Get a multi-sentence text for longer challenges.
function TextGenerator:getLongText(difficulty, sentenceCount, opts)
    if not self.loaded then
        self:loadResources()
    end
    opts = opts or {}

    local diffSettings, resolvedKey = resolveDifficulty(difficulty)

    if not sentenceCount then
        if resolvedKey == "easy" then
            sentenceCount = 2
        elseif resolvedKey == "hard" then
            sentenceCount = 5
        else
            sentenceCount = 3
        end
    end

    -- Only reachable once data/paragraphs.txt ships; otherwise falls through
    -- to generation below, same real-asset-else-placeholder pattern used
    -- everywhere else in the project.
    if resolvedKey == "hard" and #self.paragraphs > 0 then
        return self.paragraphs[love.math.random(#self.paragraphs)]
    end

    local rng = opts.seed ~= nil and love.math.newRandomGenerator(opts.seed) or nil

    return self:generateParagraph({
        sentenceCount = sentenceCount,
        sentenceLength = self:_scaleLengthForRound(diffSettings.sentenceLength, opts.round),
        minWordSize = diffSettings.minWordSize or DIFFICULTY_MIN_WORD_SIZE[resolvedKey] or DEFAULT_SETTINGS.minWordSize,
        maxWordSize = diffSettings.maxWordSize or DEFAULT_SETTINGS.maxWordSize,
        capitalizeSentences = true,
        rng = rng
    })
end

-- A single quote, from data/quotes.txt if shipped or the embedded fallback
-- set otherwise. Not wired into getRandomText automatically so difficulty's
-- word-size guarantee always holds for the default path.
function TextGenerator:getRandomQuote(opts)
    if not self.loaded then
        self:loadResources()
    end
    opts = opts or {}
    if #self.quotes == 0 then return nil end
    local rng = opts.seed ~= nil and love.math.newRandomGenerator(opts.seed) or nil
    return self.quotes[rrandom(rng, #self.quotes)]
end

-- Preload resources to avoid delays during gameplay
function TextGenerator:preload()
    return self:loadResources()
end

return TextGenerator
