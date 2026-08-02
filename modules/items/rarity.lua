-- modules/items/rarity.lua
-- Rarity tiers for keycap items: draw weights, and the cost/power multipliers
-- that scale a template (see itemDefs.lua) into a concrete offer.
--
-- Colors are NOT defined here -- they live in modules/ui/theme.lua
-- (Theme.color("rarity.epic")). This module only owns the numbers that decide
-- how often a tier is drawn and how strong/expensive it is.

local Theme = require("modules/ui/theme")

local Rarity = {}

-- Ascending order, shared with the theme so nothing can drift out of sync.
Rarity.order = Theme.rarityOrder

-- Draw weights at round 1. Commons dominate; legendaries are a lottery.
local BASE_WEIGHTS = {
    common    = 100,
    uncommon  = 42,
    rare      = 16,
    epic      = 5,
    legendary = 1,
}

-- How much a tier multiplies a template's base cost.
Rarity.costMultiplier = {
    common    = 1.0,
    uncommon  = 1.4,
    rare      = 2.0,
    epic      = 3.0,
    legendary = 4.5,
}

-- How much a tier multiplies a template's base effect value.
Rarity.powerMultiplier = {
    common    = 1.0,
    uncommon  = 1.35,
    rare      = 1.8,
    epic      = 2.4,
    legendary = 3.2,
}

-- 1-based position in Rarity.order, or nil for an unknown tier.
function Rarity.index(tier)
    for i, name in ipairs(Rarity.order) do
        if name == tier then return i end
    end
    return nil
end

-- Weights for a given round/luck. Higher rounds gradually erode the common
-- share and lift everything else; luck (e.g. a future run modifier) is an
-- additive nudge to every non-common tier. Diminishing returns after round 20
-- so the table doesn't degenerate at very long runs.
function Rarity.weights(round, luck)
    round = round or 1
    luck = luck or 0
    local ramp = math.min(math.max(round - 1, 0), 20)

    return {
        common    = math.max(BASE_WEIGHTS.common - ramp * 3, 20),
        uncommon  = BASE_WEIGHTS.uncommon + ramp * 1.5 + luck,
        rare      = BASE_WEIGHTS.rare + ramp * 1.2 + luck,
        epic      = BASE_WEIGHTS.epic + ramp * 0.6 + luck * 0.5,
        legendary = BASE_WEIGHTS.legendary + ramp * 0.15 + luck * 0.25,
    }
end

-- Roll a tier for the given round (and optional luck bonus). Always returns a
-- valid entry of Rarity.order, even under float rounding at the boundary.
function Rarity.roll(round, luck)
    local weights = Rarity.weights(round, luck)

    local total = 0
    for _, name in ipairs(Rarity.order) do
        total = total + weights[name]
    end

    local roll = love.math.random() * total
    local acc = 0
    for _, name in ipairs(Rarity.order) do
        acc = acc + weights[name]
        if roll <= acc then return name end
    end

    return Rarity.order[#Rarity.order]
end

return Rarity
