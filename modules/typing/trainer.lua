-- modules/typing/trainer.lua
-- The typing line: input handling, scoring, and the juice pass (shake, floating
-- score numbers, streak meter/particles). This is the moment-to-moment feel of
-- the whole game, so every visual choice here routes through Theme and every
-- score path goes through the shared keyboardModel:computeKeyScore contract
-- (with a legacy fallback for worktrees that predate it).

local Theme = require("modules/ui/theme")
local Audio = require("modules/audio/audio")
local Steam = require("modules/steam/steam")

local TypingTrainer = {}
TypingTrainer.__index = TypingTrainer

local VOWELS = { a = true, e = true, i = true, o = true, u = true }

local FLASH_PEAK = 0.5
local FLASH_DECAY = 2.2         -- alpha/sec
local CARET_EASE_SPEED = 18     -- higher = snappier caret
local POPUP_LIFE = 0.7
local POPUP_RISE = 34
local STREAK_MILESTONE = 10
local TIMED_BURST_DEFAULT = 20  -- used only if a burst round has no configured limit
local DECAY_BASE = 1.0          -- seconds of idle before the caret's own char starts fading
local DECAY_STEP = 0.3          -- extra idle seconds required per character further ahead
local DECAY_FADE = 1.0          -- fade duration once decay starts

-- Greedy word-wrap by character count (monospace assumption: caret and error
-- math both reduce to `x = n * advance`). Only breaks mid-word when a single
-- word is wider than the whole line. Pure function of text + width in chars,
-- so it is unit-testable without a graphics context.
local function wrapWords(text, charsPerLine)
    charsPerLine = math.max(1, math.floor(charsPerLine or 1))
    local n = #text
    if n == 0 then
        return { { startIndex = 1, endIndex = 0 } }
    end

    local lines = {}
    local lineStart = 1
    local col = 0
    local i = 1

    while i <= n do
        local wordStart, wordEnd = text:find("%S+", i)
        if not wordStart then break end -- only trailing spaces remain

        -- Walk the gap (spaces) up to the next word, wrapping mid-gap if needed.
        while i < wordStart do
            if col >= charsPerLine then
                lines[#lines + 1] = { startIndex = lineStart, endIndex = i - 1 }
                lineStart = i
                col = 0
            end
            col = col + 1
            i = i + 1
        end

        local wordLen = wordEnd - wordStart + 1

        if wordLen > charsPerLine then
            -- Word alone doesn't fit a full line: hard-break through it.
            if col > 0 then
                lines[#lines + 1] = { startIndex = lineStart, endIndex = i - 1 }
                lineStart = i
                col = 0
            end
            local remaining = wordLen
            while remaining > 0 do
                local take = math.min(charsPerLine, remaining)
                lines[#lines + 1] = { startIndex = i, endIndex = i + take - 1 }
                i = i + take
                remaining = remaining - take
            end
            lineStart = i
            col = 0
        else
            if col > 0 and col + wordLen > charsPerLine then
                lines[#lines + 1] = { startIndex = lineStart, endIndex = i - 1 }
                lineStart = i
                col = 0
            end
            col = col + wordLen
            i = wordEnd + 1
        end
    end

    lines[#lines + 1] = { startIndex = lineStart, endIndex = n }
    return lines
end

-- Read the difficulty config (owned by the run/config unit). Defensive
-- because a worktree may not have it, or ConfigManager may not be init'd yet
-- (e.g. in headless tests).
local function getDifficultyConfig(difficulty)
    local ok, ConfigManager = pcall(require, "engine/configManager")
    if not ok or not ConfigManager then return nil end
    local success, diff = pcall(function() return ConfigManager:getDifficulty(difficulty) end)
    if success then return diff end
    return nil
end

-- The switch type drives the key-thock sample. keyboardModel may not expose
-- this yet, so fall back to a plain linear switch.
local function resolveSwitchType(keyboardModel, char)
    if keyboardModel and keyboardModel.getKeySwitchType then
        local ok, result = pcall(function() return keyboardModel:getKeySwitchType(char) end)
        if ok and result then return result end
    end
    return "linear"
end

-- Create a new typing trainer instance.
function TypingTrainer.new(options)
    local self = setmetatable({}, TypingTrainer)
    options = options or {}

    self.text = options.text or "Default text"
    self.displayName = options.displayName or "Standard Typing Challenge"
    self.difficulty = options.difficulty or "medium"
    self.keyboardModel = options.keyboardModel
    self.keyboardView = options.keyboardView
    self.round = options.round or 1

    self.mutators = {}
    for _, id in ipairs(options.mutators or {}) do
        self.mutators[id] = true
    end

    local diffConfig = getDifficultyConfig(self.difficulty)
    self.baseScorePerChar = options.baseScorePerChar or (diffConfig and diffConfig.baseScorePerChar) or 1
    self.timeLimit = options.timeLimit or (diffConfig and diffConfig.timeLimit) or 0
    if self.mutators.timed_burst and self.timeLimit <= 0 then
        self.timeLimit = TIMED_BURST_DEFAULT
    end

    -- Typing progress state
    self.typed = {}            -- { char, correct, points, procs } per keystroke
    self.startTime = nil       -- set on first keystroke, not construction -- see below
    self.finished = false
    self.correctCount = 0
    self.mistakes = 0
    self.currentStreak = 0
    self.longestStreak = 0
    self.lastMilestoneStreak = 0
    self.lastChar = nil
    self.idleTime = 0
    self.score = 0
    self.highscore = options.highscore or 0

    -- Event callbacks -- other systems (audio, meta-progression, achievements)
    -- hook these instead of reaching into trainer internals.
    self.onKeyPressed = options.onKeyPressed
    self.onKeyMissed = options.onKeyMissed
    self.onCrit = options.onCrit
    self.onComplete = options.onComplete

    -- Juice state
    self.cursorBlinkTimer = 0
    self.cursorVisible = true
    self.shake = { timer = 0, duration = 0.3, intensity = 5 }
    self.flashAlpha = 0
    self.popups = {}
    self.pendingBurst = false
    self.particleSystem = nil
    self.caretDrawX, self.caretDrawY = nil, nil

    return self
end

-- Compute the score for a correct keystroke, using the shared item-scoring
-- contract when available and falling back to the legacy per-key-bonus path
-- otherwise (some worktrees won't have computeKeyScore yet).
function TypingTrainer:scoreKeystroke(char)
    local ctx = {
        streak = self.currentStreak,
        prevChar = self.lastChar,
        round = self.round,
        isVowel = VOWELS[char:lower()] or false,
    }

    if self.keyboardModel and self.keyboardModel.computeKeyScore then
        local ok, points, procs = pcall(function()
            return self.keyboardModel:computeKeyScore(char, ctx)
        end)
        if ok and points then
            return points, procs or {}
        end
    end

    local points = self.baseScorePerChar
    if self.keyboardModel then
        local multiplier = 1.0
        if self.keyboardModel.getTotalMultiplier then
            multiplier = self.keyboardModel:getTotalMultiplier() or 1.0
        end
        local bonus = 0
        if self.keyboardModel.getKeyBonus then
            bonus = self.keyboardModel:getKeyBonus(char:lower()) or 0
        end
        points = (self.baseScorePerChar * multiplier) + bonus
    end
    return points, {}
end

-- Handle a single character of input.
function TypingTrainer:handleInput(char)
    if self.finished then return end

    -- The clock starts on the first keystroke, not construction, so reading
    -- the prompt doesn't eat into WPM/APM.
    if not self.startTime then
        self.startTime = love.timer.getTime()
    end
    self.idleTime = 0

    local index = #self.typed + 1
    local expectedChar = self.text:sub(index, index)
    local isCorrect = (char == expectedChar)
    local points, procs = 0, {}

    if isCorrect then
        if self.correctCount == 0 then
            Steam.unlockAchievement("FIRST_KEYSTROKE")
        end

        self.currentStreak = self.currentStreak + 1
        if self.currentStreak > self.longestStreak then
            self.longestStreak = self.currentStreak
            if self.longestStreak == 50 then
                Steam.unlockAchievement("STREAK_50")
            elseif self.longestStreak == 200 then
                Steam.unlockAchievement("STREAK_200")
            end
        end

        points, procs = self:scoreKeystroke(char)
        self.correctCount = self.correctCount + 1
        self.score = self.score + points

        self:spawnPopup(points, procs)
        self:checkStreakMilestone()

        if procs.crit then
            Audio.playSfx("crit")
            if self.onCrit then self.onCrit(char, points) end
        end
        if procs.coins and procs.coins > 0 then
            Audio.playSfx("coin")
        end
    else
        -- The grace and protect effects only ever fire on a miss, so they have
        -- no path through computeKeyScore (which is correct-keystroke-only by
        -- contract). Without this call both effect kinds are inert.
        local miss = { forgiven = false, protected = false }
        if self.keyboardModel and self.keyboardModel.computeKeyError then
            local ok, result = pcall(function()
                return self.keyboardModel:computeKeyError(expectedChar, {
                    streak = self.currentStreak,
                    prevChar = self.lastChar,
                    round = self.round or 1,
                    isVowel = VOWELS[expectedChar:lower()] or false,
                })
            end)
            if ok and type(result) == "table" then miss = result end
        end

        if miss.forgiven then
            -- Forgiven: the keystroke costs neither an error nor the streak.
            isCorrect = true
        else
            self.mistakes = self.mistakes + 1
            if not miss.protected then
                self.currentStreak = 0
                -- Rebuilding the streak should re-trigger milestones.
                self.lastMilestoneStreak = 0
            end
            self:startShake(0.3, 5)
        end

        if self.onKeyMissed then
            self.onKeyMissed(char, expectedChar, miss)
        end
    end

    table.insert(self.typed, { char = char, correct = isCorrect, points = points, procs = procs })
    self.lastChar = char

    Audio.playKey(resolveSwitchType(self.keyboardModel, char), isCorrect)

    if self.keyboardView and self.keyboardView.activateKey then
        pcall(function() self.keyboardView:activateKey(char) end)
    end

    if self.onKeyPressed then
        self.onKeyPressed(char, isCorrect)
    end

    -- Never overtype: finishing exactly at text length is the only way out.
    if #self.typed >= #self.text then
        self:finish()
    end
end

-- Handle backspace. No-ops entirely under the no_backspace mutator.
function TypingTrainer:backspace()
    if self.finished then return end
    if self.mutators.no_backspace then return end
    if #self.typed == 0 then return end

    local removed = table.remove(self.typed)

    if removed.correct then
        self.correctCount = self.correctCount - 1
        self.score = self.score - (removed.points or 0)
    else
        self.mistakes = self.mistakes - 1
    end

    self.lastChar = self.typed[#self.typed] and self.typed[#self.typed].char or nil

    -- Recompute both streaks from the remaining history rather than trying to
    -- patch them incrementally -- that incremental approach is exactly what
    -- left longestStreak inflated after a mistake was backed out.
    self:recalculateStreaks()
end

function TypingTrainer:recalculateStreaks()
    local current, longest = 0, 0
    for i = 1, #self.typed do
        if self.typed[i].correct then
            current = current + 1
            if current > longest then longest = current end
        else
            current = 0
        end
    end
    self.currentStreak = current
    self.longestStreak = longest

    -- Cap the milestone watermark to what's actually reachable at the new
    -- streak so climbing back up to a previously-hit milestone re-triggers.
    local reachable = math.floor(current / STREAK_MILESTONE) * STREAK_MILESTONE
    if reachable < self.lastMilestoneStreak then
        self.lastMilestoneStreak = reachable
    end
end

-- Finish the typing session.
function TypingTrainer:finish()
    if self.finished then return end
    self.finished = true
    self.endTime = love.timer.getTime()
    if not self.startTime then
        -- Finished with zero keystrokes (e.g. Escape while reading the prompt).
        self.startTime = self.endTime
    end

    if self.score > self.highscore then
        self.highscore = self.score
    end

    if self.onComplete then
        self.onComplete(self:getStats())
    end
end

function TypingTrainer:getTimeTaken()
    if not self.startTime then return 0 end
    if self.finished then return self.endTime - self.startTime end
    return love.timer.getTime() - self.startTime
end

function TypingTrainer:getAccuracy()
    local total = #self.typed
    if total == 0 then return 0 end
    return (self.correctCount / total) * 100
end

function TypingTrainer:getAPM()
    local timeTaken = self:getTimeTaken()
    if timeTaken < 0.01 then return 0 end
    return (#self.typed / timeTaken) * 60
end

function TypingTrainer:getWPM()
    local timeTaken = self:getTimeTaken()
    if timeTaken < 0.01 then return 0 end
    return (self.correctCount / 5) / (timeTaken / 60)
end

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
        completed = self.finished,
    }
end

-- Juice: shake -----------------------------------------------------------

function TypingTrainer:startShake(duration, intensity)
    self.shake.duration = duration or 0.3
    self.shake.timer = self.shake.duration
    self.shake.intensity = intensity or 5
    self.flashAlpha = FLASH_PEAK
end

-- Juice: floating score popups --------------------------------------------

function TypingTrainer:spawnPopup(points, procs)
    table.insert(self.popups, {
        text = string.format("+%.0f", points),
        crit = procs and procs.crit or false,
        coin = procs and procs.coins and procs.coins > 0 or false,
        age = 0,
        life = POPUP_LIFE,
        dx = love.math and love.math.random and love.math.random(-6, 6) or 0,
        originX = self.caretDrawX,
        originY = self.caretDrawY,
    })
end

-- Juice: streak meter / particle burst ------------------------------------

function TypingTrainer:checkStreakMilestone()
    if self.currentStreak > 0
        and self.currentStreak % STREAK_MILESTONE == 0
        and self.currentStreak ~= self.lastMilestoneStreak
    then
        self.lastMilestoneStreak = self.currentStreak
        self.pendingBurst = true
        Audio.playSfx("streak")
    end
end

-- decaying_text mutator: characters ahead of the caret fade the longer the
-- player hesitates. Pure function of idle time + distance so it's testable
-- without a graphics context.
function TypingTrainer:getDecayAlpha(distanceAhead)
    if not self.mutators.decaying_text then return 1 end
    if distanceAhead < 0 then return 1 end
    local threshold = DECAY_BASE + distanceAhead * DECAY_STEP
    local t = self.idleTime - threshold
    if t <= 0 then return 1 end
    return math.max(0, 1 - t / DECAY_FADE)
end

-- Procedurally generate a small radial-falloff dot used as the particle
-- texture (the Kenney particle pack isn't available). Cached at module scope
-- since it's identical for every trainer instance.
local dotImageCache
local function getDotImage()
    if dotImageCache then return dotImageCache end
    local size = 8
    local imageData = love.image.newImageData(size, size)
    imageData:mapPixel(function(x, y)
        local dx, dy = (x + 0.5) - size / 2, (y + 0.5) - size / 2
        local dist = math.sqrt(dx * dx + dy * dy)
        local a = math.max(0, 1 - dist / (size / 2))
        return 1, 1, 1, a
    end)
    dotImageCache = love.graphics.newImage(imageData)
    return dotImageCache
end

function TypingTrainer:ensureParticleSystem()
    if self.particleSystem or _G.HEADLESS or not love.graphics then return end
    local ok, ps = pcall(function()
        local system = love.graphics.newParticleSystem(getDotImage(), 64)
        system:setParticleLifetime(0.25, 0.6)
        system:setSpeed(30, 110)
        system:setSpread(math.pi * 2)
        system:setSizes(1.6, 0.2)
        system:setLinearDamping(1.2)
        system:setColors(1, 0.79, 0.29, 1, 1, 0.35, 0.29, 0)
        return system
    end)
    if ok then self.particleSystem = ps end
end

-- Update animations and timers. Kept graphics-free where possible so this is
-- callable (and useful) from headless tests.
function TypingTrainer:update(dt)
    dt = dt or 0
    self.idleTime = self.idleTime + dt

    self.cursorBlinkTimer = self.cursorBlinkTimer + dt
    if self.cursorBlinkTimer >= 0.5 then
        self.cursorBlinkTimer = self.cursorBlinkTimer - 0.5
        self.cursorVisible = not self.cursorVisible
    end

    if self.shake.timer > 0 then
        self.shake.timer = math.max(0, self.shake.timer - dt)
    end
    if self.flashAlpha > 0 then
        self.flashAlpha = math.max(0, self.flashAlpha - dt * FLASH_DECAY)
    end

    for i = #self.popups, 1, -1 do
        local p = self.popups[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(self.popups, i)
        end
    end

    if self.particleSystem then
        self.particleSystem:update(dt)
    end

    if self.keyboardView and self.keyboardView.update then
        pcall(function() self.keyboardView:update(dt) end)
    end

    if not self.finished and self.timeLimit and self.timeLimit > 0 then
        if self:getTimeTaken() >= self.timeLimit then
            self:finish()
        end
    end
end

-- Draw the typing interface inside the given logical rect.
function TypingTrainer:draw(x, y, width, height)
    if _G.HEADLESS or not love.graphics then return end

    self:ensureParticleSystem()

    love.graphics.push("all")

    local headingFont = Theme.font("heading")
    local font = Theme.font("mono")
    local smallFont = Theme.font("small")

    love.graphics.setFont(headingFont)
    Theme.setColor("text")
    love.graphics.printf(self.displayName, x, y, width, "center")
    local rowY = y + headingFont:getHeight() + Theme.spacing.sm

    -- Text area box
    local boxX, boxY, boxW = x, rowY, width
    local lineHeight = font:getHeight() + Theme.spacing.xs
    local visibleLines = 3
    local boxH = lineHeight * visibleLines + Theme.spacing.md * 2

    Theme.setColor("panel")
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, Theme.radius, Theme.radius)
    if self.flashAlpha > 0 then
        Theme.setColor("wrong", self.flashAlpha)
    else
        Theme.setColor("border")
    end
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, Theme.radius, Theme.radius)

    -- Clip so the shake oscillation never visibly leaves the box.
    love.graphics.setScissor(boxX, boxY, boxW, boxH)

    local advance = font:getWidth("0")
    if advance <= 0 then advance = 8 end
    local innerW = boxW - Theme.spacing.md * 2
    local charsPerLine = math.max(4, math.floor(innerW / advance))
    local lines = wrapWords(self.text, charsPerLine)

    local caretIndex = #self.typed + 1
    local caretLine, caretCol = 1, 0
    for li, ln in ipairs(lines) do
        if caretIndex >= ln.startIndex and caretIndex <= ln.endIndex + 1 then
            caretLine, caretCol = li, caretIndex - ln.startIndex
            break
        end
    end

    local shakeX, shakeY = 0, 0
    if self.shake.timer > 0 then
        local decay = self.shake.timer / self.shake.duration
        shakeX = math.sin(self.shake.timer * 40) * self.shake.intensity * decay
        shakeY = math.cos(self.shake.timer * 33) * self.shake.intensity * 0.5 * decay
    end

    local textOriginX = boxX + Theme.spacing.md + shakeX
    local textOriginY = boxY + Theme.spacing.md + shakeY

    love.graphics.setFont(font)
    for li, ln in ipairs(lines) do
        local ly = textOriginY + (li - 1) * lineHeight
        for i = ln.startIndex, ln.endIndex do
            local col = i - ln.startIndex
            local cx = textOriginX + col * advance
            local ch = self.text:sub(i, i)
            local typedEntry = self.typed[i]
            local color

            if typedEntry then
                color = Theme.color(typedEntry.correct and "typed" or "wrong")
            elseif i == caretIndex then
                color = Theme.color("ghost")
            elseif self.mutators.decaying_text then
                local alpha = self:getDecayAlpha(i - caretIndex)
                if alpha <= 0.02 then ch = "" end
                color = Theme.color("pending", alpha)
            else
                color = Theme.color("pending")
            end

            if ch ~= "" then
                love.graphics.setColor(color)
                love.graphics.print(ch, cx, ly)
            end
        end
    end

    love.graphics.setScissor()

    -- Caret eases toward its target instead of snapping.
    local targetCaretX = textOriginX + caretCol * advance - shakeX
    local targetCaretY = textOriginY + (caretLine - 1) * lineHeight - shakeY
    if not self.caretDrawX then
        self.caretDrawX, self.caretDrawY = targetCaretX, targetCaretY
    end
    local frameDt = love.timer.getDelta()
    local ease = 1 - math.exp(-frameDt * CARET_EASE_SPEED)
    self.caretDrawX = self.caretDrawX + (targetCaretX - self.caretDrawX) * ease
    self.caretDrawY = self.caretDrawY + (targetCaretY - self.caretDrawY) * ease

    if not self.finished then
        Theme.setColor("caret")
        love.graphics.rectangle("fill", self.caretDrawX, self.caretDrawY, 2, lineHeight - Theme.spacing.xs)
    end

    -- Floating score popups
    love.graphics.setFont(smallFont)
    for _, p in ipairs(self.popups) do
        local t = p.age / p.life
        local alpha = 1 - t
        local px = (p.originX or self.caretDrawX) + (p.dx or 0)
        local py = (p.originY or self.caretDrawY) - t * POPUP_RISE
        local scale = p.crit and 1.5 or 1
        if p.crit then
            love.graphics.setColor(Theme.color("accent", alpha))
        elseif p.coin then
            love.graphics.setColor(Theme.color("warning", alpha))
        else
            love.graphics.setColor(Theme.color("success", alpha))
        end
        love.graphics.print(p.text, px, py, 0, scale, scale)
    end

    rowY = boxY + boxH + Theme.spacing.md

    -- Streak meter: fills each 10-streak tier, glows brighter the longer the
    -- run, and pops a particle burst at each milestone.
    local meterH = 6
    local streakFrac = (self.currentStreak % STREAK_MILESTONE) / STREAK_MILESTONE
    if self.currentStreak > 0 and streakFrac == 0 then streakFrac = 1 end

    Theme.setColor("panel")
    love.graphics.rectangle("fill", x, rowY, width, meterH)
    local glow = math.min(1, self.currentStreak / (STREAK_MILESTONE * 3))
    Theme.setColor("accent", 0.55 + glow * 0.45)
    love.graphics.rectangle("fill", x, rowY, width * streakFrac, meterH)

    if self.pendingBurst and self.particleSystem then
        self.particleSystem:setPosition(x + width * streakFrac, rowY)
        self.particleSystem:emit(24)
        self.pendingBurst = false
    end
    if self.particleSystem then
        love.graphics.draw(self.particleSystem)
    end

    rowY = rowY + meterH + Theme.spacing.sm

    -- Stat line
    Theme.setColor("textMuted")
    local statsLine = string.format(
        "Time %.1fs   Acc %.0f%%   WPM %.0f   APM %.0f   Streak %d   Score %.0f",
        self:getTimeTaken(), self:getAccuracy(), self:getWPM(), self:getAPM(),
        self.currentStreak, self.score
    )
    love.graphics.printf(statsLine, x, rowY, width, "center")
    rowY = rowY + smallFont:getHeight() + Theme.spacing.sm

    if self.mutators.timed_burst and self.timeLimit > 0 then
        local remaining = math.max(0, self.timeLimit - self:getTimeTaken())
        Theme.setColor(remaining <= 5 and "wrong" or "warning")
        love.graphics.printf(string.format("%.1fs", remaining), x, rowY, width, "center")
    end

    if self.finished then
        Theme.setColor("accent")
        love.graphics.printf("Press Enter to continue", x, y + height - headingFont:getHeight(), width, "center")
    end

    love.graphics.pop()
end

-- Exposed for testing: pure text-flow logic, no font/graphics dependency.
TypingTrainer.wrapWords = wrapWords

return TypingTrainer
