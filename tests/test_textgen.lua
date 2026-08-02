-- tests/test_textgen.lua
-- Regression coverage for the text generator: difficulty word-size bounds,
-- seeded determinism, round scaling and mutator handling.

local H = require("tests/helpers")
local TextGenerator = require("modules/typing/textGenerator")

local T = {}

local function wordLength(text, boundary)
    return boundary.endIndex - boundary.startIndex + 1
end

function T.difficulty_word_sizes_are_respected()
    local bounds = {
        easy = { min = 2, max = 6 },
        medium = { min = 3, max = 8 },
        hard = { min = 4, max = 12 },
    }

    for difficulty, bound in pairs(bounds) do
        for seed = 1, 5 do
            local text, meta = TextGenerator:getRandomText(difficulty, { seed = seed })
            H.isTrue(#meta.wordBoundaries > 0, "no words generated for " .. difficulty)
            for _, boundary in ipairs(meta.wordBoundaries) do
                local len = wordLength(text, boundary)
                H.isTrue(len >= bound.min and len <= bound.max,
                    difficulty .. " word out of bounds: " ..
                    text:sub(boundary.startIndex, boundary.endIndex) .. " (len " .. len .. ")")
            end
        end
    end
end

function T.sentence_length_matches_difficulty()
    local _, easyMeta = TextGenerator:getRandomText("easy", { seed = 1 })
    H.equal(#easyMeta.wordBoundaries, 8)

    local _, mediumMeta = TextGenerator:getRandomText("medium", { seed = 1 })
    H.equal(#mediumMeta.wordBoundaries, 12)

    local _, hardMeta = TextGenerator:getRandomText("hard", { seed = 1 })
    H.equal(#hardMeta.wordBoundaries, 16)
end

function T.same_seed_is_deterministic()
    local textA = TextGenerator:getRandomText("medium", { seed = 12345 })
    local textB = TextGenerator:getRandomText("medium", { seed = 12345 })
    H.equal(textA, textB)
end

function T.different_seeds_generally_differ()
    local textA = TextGenerator:getRandomText("medium", { seed = 1 })
    local textB = TextGenerator:getRandomText("medium", { seed = 2 })
    H.notEqual(textA, textB)
end

function T.seeded_generation_does_not_perturb_global_rng()
    love.math.setRandomSeed(999)
    local before = love.math.random(1, 1000000)

    love.math.setRandomSeed(999)
    TextGenerator:getRandomText("medium", { seed = 42 })
    local after = love.math.random(1, 1000000)

    H.equal(before, after, "seeded call must not touch the global RNG stream")
end

function T.higher_rounds_produce_longer_text()
    local _, round1 = TextGenerator:getRandomText("medium", { seed = 1, round = 1 })
    local _, round10 = TextGenerator:getRandomText("medium", { seed = 1, round = 10 })

    H.isTrue(#round10.wordBoundaries > #round1.wordBoundaries,
        "round 10 should generate more words than round 1")
end

function T.timed_burst_is_shorter_than_default()
    local _, normal = TextGenerator:getRandomText("medium", { seed = 1, round = 5 })
    local _, burst = TextGenerator:getRandomText("medium", { seed = 1, round = 5, mutators = { "timed_burst" } })

    H.isTrue(#burst.wordBoundaries < #normal.wordBoundaries,
        "timed_burst should generate fewer words")
end

function T.decaying_text_boundaries_land_on_words()
    local text, meta = TextGenerator:getRandomText("medium", { seed = 7, mutators = { "decaying_text" } })

    H.isTrue(meta.mutators.decaying_text, "mutator should be recorded in meta")
    H.isTrue(#meta.wordBoundaries > 0)

    for _, boundary in ipairs(meta.wordBoundaries) do
        local word = text:sub(boundary.startIndex, boundary.endIndex)
        H.isTrue(word:match("^[%a']+$") ~= nil, "boundary did not land on a clean word: " .. H.format(word))
    end

    -- No awkward trailing punctuation for the fade effect to trip over.
    local lastChar = text:sub(-1, -1)
    H.isTrue(lastChar:match("[%a']") ~= nil, "decaying_text should not end with punctuation")
end

function T.no_backspace_is_ignored_gracefully()
    H.succeeds(function()
        return TextGenerator:getRandomText("medium", { seed = 1, mutators = { "no_backspace" } })
    end)
end

function T.unknown_mutator_is_ignored_not_raised()
    local text, meta
    H.succeeds(function()
        text, meta = TextGenerator:getRandomText("medium", { seed = 1, mutators = { "totally_made_up_mutator" } })
    end)
    H.isTrue(type(text) == "string" and #text > 0)
    H.isTrue(meta.mutators.totally_made_up_mutator, "unrecognized id should still be recorded, just inert")
end

function T.generation_works_when_word_list_fails_to_load()
    local originalGetInfo = love.filesystem.getInfo
    love.filesystem.getInfo = function(path, ...)
        if path == "data/words.txt" then return nil end
        return originalGetInfo(path, ...)
    end

    TextGenerator:reset()
    local ok = H.succeeds(function() return TextGenerator:loadResources() end)
    H.isTrue(ok, "loadResources should succeed via the fallback word list")

    local text = TextGenerator:getRandomText("medium")
    H.isTrue(type(text) == "string" and #text > 0)

    -- Restore real filesystem access and reload the real corpus so later
    -- tests (in this file or others) don't inherit the tiny fallback list.
    love.filesystem.getInfo = originalGetInfo
    TextGenerator:reset()
    TextGenerator:loadResources()
end

function T.no_double_spaces_or_stray_whitespace()
    for _, difficulty in ipairs({ "easy", "medium", "hard" }) do
        for seed = 1, 5 do
            local text = TextGenerator:getRandomText(difficulty, { seed = seed })
            H.isFalse(text:find("  ", 1, true), "double space in: " .. H.format(text))
            H.equal(text, text:match("^%s*(.-)%s*$"), "leading/trailing whitespace in: " .. H.format(text))
        end
    end
end

return T
