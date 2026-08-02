-- tests/test_trainer.lua
-- Headless, pure-logic coverage for modules/typing/trainer.lua. No graphics
-- context is exercised here -- draw() is guarded behind _G.HEADLESS and is
-- proven separately via the --shot recipe.

local H = require("tests/helpers")
local TypingTrainer = require("modules/typing/trainer")

local T = {}

-- Clock start -------------------------------------------------------------

function T.clock_does_not_start_until_first_keystroke()
    local trainer = TypingTrainer.new({ text = "abc" })
    H.equal(trainer.startTime, nil, "startTime must not be set at construction")
    H.equal(trainer:getTimeTaken(), 0)

    trainer:handleInput("a")
    H.isTrue(trainer.startTime ~= nil, "startTime should be set after the first keystroke")
end

-- Accuracy / WPM / APM -----------------------------------------------------

function T.zero_keystrokes_yield_zero_stats()
    local trainer = TypingTrainer.new({ text = "abcdef" })
    H.equal(trainer:getAccuracy(), 0)
    H.equal(trainer:getWPM(), 0)
    H.equal(trainer:getAPM(), 0)
    H.equal(trainer:getTimeTaken(), 0)
end

function T.near_zero_time_yields_zero_rate_stats()
    local trainer = TypingTrainer.new({ text = "abcdef" })
    trainer:handleInput("a")
    -- Effectively no wall-clock time has passed since startTime was just set;
    -- the division guard must protect WPM/APM from blowing up.
    H.equal(trainer:getWPM(), 0)
    H.equal(trainer:getAPM(), 0)
end

function T.accuracy_wpm_apm_formulas_for_known_inputs()
    local trainer = TypingTrainer.new({ text = "abcdefghijklmnopqrst" })
    for _, c in ipairs({ "a", "b", "c", "d", "e", "f", "g", "h", "x", "y" }) do
        trainer:handleInput(c)
    end
    -- 8 correct (a-h), 2 wrong (x,y in place of i,j) = 10 keystrokes.
    H.equal(trainer.correctCount, 8)
    H.equal(#trainer.typed, 10)

    -- Pin the clock to a known elapsed duration instead of racing real time.
    trainer.startTime = love.timer.getTime() - 60

    H.near(trainer:getAccuracy(), 80, 0.01)
    H.near(trainer:getWPM(), (8 / 5) / (60 / 60), 0.05)
    H.near(trainer:getAPM(), (10 / 60) * 60, 0.05)
end

-- Backspace / streak bookkeeping -------------------------------------------

function T.backspace_restores_streak_without_inflating_longest()
    local trainer = TypingTrainer.new({ text = "abcdef" })
    trainer:handleInput("a") -- correct, streak 1
    trainer:handleInput("b") -- correct, streak 2 (new longest)
    trainer:handleInput("x") -- wrong (expected c), streak resets

    H.equal(trainer.currentStreak, 0)
    H.equal(trainer.longestStreak, 2)

    trainer:backspace() -- undo the mistake
    H.equal(trainer.currentStreak, 2, "backspacing a mistake should restore the prior streak")
    H.equal(trainer.longestStreak, 2)

    trainer:backspace() -- undo the second correct keystroke
    H.equal(trainer.currentStreak, 1)
    H.equal(trainer.longestStreak, 1, "longestStreak must shrink back down, not stay inflated")
end

function T.no_backspace_mutator_disables_backspace()
    local trainer = TypingTrainer.new({ text = "abc", mutators = { "no_backspace" } })
    trainer:handleInput("a")
    trainer:handleInput("x") -- wrong

    local before = #trainer.typed
    local streakBefore, mistakesBefore = trainer.currentStreak, trainer.mistakes
    trainer:backspace()

    H.equal(#trainer.typed, before, "backspace must be a total no-op under no_backspace")
    H.equal(trainer.currentStreak, streakBefore)
    H.equal(trainer.mistakes, mistakesBefore)
end

-- Scoring: fallback vs. computeKeyScore contract ----------------------------

function T.scoring_uses_legacy_fallback_without_computeKeyScore()
    local stubModel = {
        getTotalMultiplier = function(self) return 2.0 end,
        getKeyBonus = function(self, key) return 0.5 end,
    }
    local trainer = TypingTrainer.new({ text = "a", keyboardModel = stubModel, baseScorePerChar = 1 })
    trainer:handleInput("a")

    -- (baseScorePerChar * multiplier) + bonus = (1 * 2.0) + 0.5
    H.near(trainer.score, 2.5)
end

function T.scoring_uses_computeKeyScore_when_present()
    local seenChar, seenCtx
    local stubModel = {
        computeKeyScore = function(self, char, ctx)
            seenChar, seenCtx = char, ctx
            return 42, { crit = true, coins = 3 }
        end,
    }
    local trainer = TypingTrainer.new({ text = "a", keyboardModel = stubModel })
    trainer:handleInput("a")

    H.equal(trainer.score, 42, "score must come from computeKeyScore, not the legacy path")
    H.equal(seenChar, "a")
    H.equal(seenCtx.streak, 1)
    H.isTrue(seenCtx.isVowel, "'a' should be flagged as a vowel")
end

function T.compute_key_score_receives_full_context()
    local seenCtx
    local stubModel = {
        computeKeyScore = function(self, char, ctx) seenCtx = ctx; return 1, {} end,
    }
    local trainer = TypingTrainer.new({ text = "ab", keyboardModel = stubModel, round = 3 })

    trainer:handleInput("a")
    H.equal(seenCtx.round, 3)
    H.equal(seenCtx.prevChar, nil, "no keystroke precedes the first character")

    trainer:handleInput("b")
    H.equal(seenCtx.prevChar, "a")
    H.equal(seenCtx.streak, 2)
end

-- Completion ----------------------------------------------------------------

function T.finishes_exactly_at_text_length_and_cannot_be_overtyped()
    local trainer = TypingTrainer.new({ text = "ab" })

    trainer:handleInput("a")
    H.isFalse(trainer.finished)

    trainer:handleInput("b")
    H.isTrue(trainer.finished)
    H.equal(#trainer.typed, 2)

    trainer:handleInput("c") -- must be ignored once finished
    H.equal(#trainer.typed, 2, "typed entries must not grow past the text length")
end

-- Events ----------------------------------------------------------------

function T.events_fire_with_correct_arguments()
    local pressedLog = {}
    local missedArgs, critArgs

    local critModel = {
        computeKeyScore = function(self, char, ctx)
            if char == "a" then return 10, { crit = true } end
            return 1, {}
        end,
    }

    local trainer = TypingTrainer.new({
        text = "ab",
        keyboardModel = critModel,
        onKeyPressed = function(char, correct) table.insert(pressedLog, { char = char, correct = correct }) end,
        onKeyMissed = function(char, expected) missedArgs = { char = char, expected = expected } end,
        onCrit = function(char, points) critArgs = { char = char, points = points } end,
    })

    trainer:handleInput("a") -- correct, and crits
    H.equal(#pressedLog, 1)
    H.equal(pressedLog[1].char, "a")
    H.isTrue(pressedLog[1].correct)
    H.isTrue(critArgs ~= nil, "onCrit should have fired")
    H.equal(critArgs.char, "a")
    H.equal(critArgs.points, 10)
    H.isTrue(missedArgs == nil, "onKeyMissed must not fire on a correct keystroke")

    trainer:handleInput("x") -- wrong (expected 'b')
    H.equal(#pressedLog, 2)
    H.equal(pressedLog[2].char, "x")
    H.isFalse(pressedLog[2].correct)
    H.isTrue(missedArgs ~= nil, "onKeyMissed should have fired")
    H.equal(missedArgs.char, "x")
    H.equal(missedArgs.expected, "b")
end

-- Streak milestones -----------------------------------------------------

function T.streak_milestone_retriggers_after_a_reset()
    local trainer = TypingTrainer.new({ text = string.rep("a", 30) })
    for i = 1, 10 do trainer:handleInput("a") end
    H.equal(trainer.lastMilestoneStreak, 10)

    trainer:handleInput("z") -- wrong, breaks the streak
    H.equal(trainer.lastMilestoneStreak, 0, "a broken streak should reset the milestone watermark")

    for i = 1, 10 do trainer:handleInput("a") end
    H.equal(trainer.currentStreak, 10)
    H.equal(trainer.lastMilestoneStreak, 10, "climbing back to the same milestone should re-trigger it")
end

-- decaying_text mutator ------------------------------------------------------

function T.decaying_text_only_fades_when_mutator_is_active()
    local plain = TypingTrainer.new({ text = "abc" })
    plain.idleTime = 10
    H.equal(plain:getDecayAlpha(0), 1, "without the mutator, characters never fade")
end

function T.decaying_text_fades_pending_characters_the_longer_the_player_hesitates()
    local trainer = TypingTrainer.new({ text = "abc", mutators = { "decaying_text" } })
    H.equal(trainer:getDecayAlpha(0), 1, "freshly started: no decay yet")

    trainer.idleTime = 5
    local nearAlpha = trainer:getDecayAlpha(0)
    local farAlpha = trainer:getDecayAlpha(5)
    H.isTrue(nearAlpha < 1, "idle time should fade the immediate next character")
    H.isTrue(farAlpha <= nearAlpha, "characters further ahead of the caret fade at least as much")
end

-- Word-boundary line wrapping -------------------------------------------------

function T.wrapWords_breaks_on_word_boundaries_not_mid_word()
    local text = "abc def ghi"
    local lines = TypingTrainer.wrapWords(text, 7)

    H.equal(#lines, 2)
    H.equal(text:sub(lines[1].startIndex, lines[1].endIndex), "abc def")
    -- The second line must not have split "ghi".
    H.isTrue(text:sub(lines[2].startIndex, lines[2].endIndex):find("ghi") ~= nil)
end

function T.wrapWords_hard_breaks_a_word_longer_than_the_line()
    local text = "supercalifragilistic"
    local lines = TypingTrainer.wrapWords(text, 6)

    for _, ln in ipairs(lines) do
        H.isTrue(ln.endIndex - ln.startIndex + 1 <= 6, "no line should exceed charsPerLine")
    end

    local rebuilt = {}
    for _, ln in ipairs(lines) do
        table.insert(rebuilt, text:sub(ln.startIndex, ln.endIndex))
    end
    H.equal(table.concat(rebuilt), text, "no characters may be lost or duplicated by wrapping")
end

function T.wrapWords_handles_empty_text()
    local lines = TypingTrainer.wrapWords("", 10)
    H.equal(#lines, 1)
    H.equal(lines[1].startIndex, 1)
    H.equal(lines[1].endIndex, 0)
end

return T
