-- modules/ui/background.lua
-- Deterministic procedural starfield for the logical canvas. Generation uses
-- a private PRNG, so recreating a seed never reads or changes Lua's global RNG.

local Screen = require("modules/ui/screen")
local Theme = require("modules/ui/theme")

local Background = {}

Background.STAR_COUNT = 72
Background.DEFAULT_SEED = 42731
Background.BACKGROUND_COLOR = "baseAlt"

local STAR_COLORS = { "textDim", "textMuted" }
local PRNG_MODULUS = 2147483647
local PRNG_MULTIPLIER = 48271
local FULL_TURN = math.pi * 2
local MIN_ALPHA = 0.12
local ALPHA_RANGE = 0.20

local function newRandom(seed)
    local state = math.abs(math.floor(tonumber(seed) or Background.DEFAULT_SEED))
    state = state % (PRNG_MODULUS - 1) + 1

    return function()
        state = (state * PRNG_MULTIPLIER) % PRNG_MODULUS
        return state / PRNG_MODULUS
    end
end

function Background.generate(seed)
    local random = newRandom(seed)
    local width, height = Screen.getDimensions()
    local stars = {}

    for i = 1, Background.STAR_COUNT do
        stars[i] = {
            x = math.floor(random() * width),
            y = math.floor(random() * height),
            size = 1 + math.floor(random() * 2),
            phase = random() * FULL_TURN,
            speed = 0.35 + random() * 0.65,
            color = STAR_COLORS[1 + math.floor(random() * #STAR_COLORS)],
        }
    end

    return stars
end

function Background.regenerate(seed)
    Background.stars = Background.generate(seed)
    return Background.stars
end

function Background.getStars()
    return Background.stars
end

-- dt is the caller's elapsed animation time. Passing the same field and time
-- produces the same frame; generation and drawing never touch global RNG state.
function Background.draw(dt)
    if love == nil or love.graphics == nil or _G.HEADLESS then return end

    Theme.setColor(Background.BACKGROUND_COLOR)
    love.graphics.rectangle("fill", 0, 0, Screen.getWidth(), Screen.getHeight())

    local elapsed = tonumber(dt) or 0
    for _, star in ipairs(Background.stars) do
        local wave = (math.sin(star.phase + elapsed * star.speed) + 1) / 2
        Theme.setColor(star.color, MIN_ALPHA + wave * ALPHA_RANGE)
        love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
    end
end

Background.regenerate(Background.DEFAULT_SEED)

return Background
