-- modules/items/itemDefs.lua
-- The keycap item catalogue. A "template" here is a design-time row (effect
-- kind, which key(s) it can land on, base value/cost); ItemDefs.generateOffer
-- instantiates one against a concrete key and rarity into the exact shape
-- other units depend on:
--   { id, name, key, rarity, capVariant, switchType, effect = { kind, value }, cost }
--
-- Two families of template:
--   * scalable  -- can be drawn at any rarity up to `maxRarity`; rarity only
--     changes the numbers (see Rarity.costMultiplier/powerMultiplier).
--   * fixed     -- only ever drawn at `fixedRarity`, and usually pinned to a
--     `fixedKey`. This is how legendaries stay set pieces instead of just the
--     biggest number on the scalable table -- they are a different template,
--     not a bigger roll of the same one.

local Rarity = require("modules/items/rarity")

local ItemDefs = {}

local VOWELS = { a = true, e = true, i = true, o = true, u = true }

local DEFAULT_KEY_POOL = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    ",", ".", "?", "!", " ",
}

-- Rarity -> keycap material. One tier maps to exactly one variant, so the
-- cap itself is a legible rarity signal (unit 14 renders these).
local CAP_VARIANT_BY_RARITY = {
    common    = "plain",
    uncommon  = "dyesub",
    rare      = "doubleshot",
    epic      = "artisan",
    legendary = "resin",
}

local PUNCT_NAMES = {
    [","] = "comma", ["."] = "period", ["?"] = "question",
    ["!"] = "bang", [" "] = "space",
}

local function keyLabel(key)
    if key == " " then return "Space" end
    return string.upper(key)
end

local function keySlug(key)
    return PUNCT_NAMES[key] or key
end

-- The home row, used by the "Home Row Harmony" legendary set below. Derived
-- from the QWERTY *letters* the set piece was designed around; the set still
-- works on Dvorak boards because it's keyed by item id, not physical
-- position -- a Dvorak player just buys the same nine letter-pieces on
-- whatever keys those letters land on for them.
local HOME_ROW_LETTERS = { "a", "s", "d", "f", "g", "h", "j", "k", "l" }

-- Scalable templates: two per effect kind that isn't otherwise covered,
-- capped below legendary so that tier stays reserved for set pieces.
local TEMPLATES = {
    { id = "worn_key",       name = "Worn %s Key",         kind = "flat",     baseValue = 0.12, baseCost = 18, keyTag = "any",        maxRarity = "epic" },
    { id = "oiled_switch",   name = "Oiled %s Switch",     kind = "flat",     baseValue = 0.18, baseCost = 24, keyTag = "any",        maxRarity = "epic" },
    { id = "streak_stone",   name = "%s Streak Stone",     kind = "streak",   baseValue = 0.04, baseCost = 26, keyTag = "any",        maxRarity = "epic" },
    { id = "momentum_cap",   name = "Momentum Cap (%s)",   kind = "streak",   baseValue = 0.06, baseCost = 32, keyTag = "any",        maxRarity = "epic" },
    { id = "reach_switch",   name = "Reach Switch (%s)",   kind = "adjacent", baseValue = 0.10, baseCost = 28, keyTag = "any",        maxRarity = "epic" },
    { id = "chain_cap",      name = "Chain Cap (%s)",      kind = "adjacent", baseValue = 0.14, baseCost = 34, keyTag = "any",        maxRarity = "epic" },
    { id = "vowel_choir",    name = "Vowel Choir (%s)",    kind = "echo",     baseValue = 0.12, baseCost = 30, keyTag = "consonant",  maxRarity = "epic" },
    { id = "resonant_reed",  name = "Resonant Reed (%s)",  kind = "echo",     baseValue = 0.18, baseCost = 40, keyTag = "any",        maxRarity = "epic" },
    { id = "copper_key",     name = "Copper %s Key",       kind = "coin",     baseValue = 1,    baseCost = 22, keyTag = "any",        maxRarity = "epic" },
    { id = "minted_switch",  name = "Minted %s Switch",    kind = "coin",     baseValue = 2,    baseCost = 38, keyTag = "any",        maxRarity = "epic" },
    { id = "tactile_guard",  name = "Tactile Guard (%s)",  kind = "grace",    baseValue = 1,    baseCost = 30, keyTag = "any",        maxRarity = "epic", switchType = "tactile" },
    { id = "forgiving_stem", name = "Forgiving Stem (%s)", kind = "grace",    baseValue = 1,    baseCost = 36, keyTag = "any",        maxRarity = "epic", switchType = "tactile" },
    { id = "clicky_spark",   name = "Clicky Spark (%s)",   kind = "crit",     baseValue = 0.08, baseCost = 32, keyTag = "any",        maxRarity = "epic", switchType = "clicky" },
    { id = "lightning_stem", name = "Lightning Stem (%s)", kind = "crit",     baseValue = 0.14, baseCost = 44, keyTag = "any",        maxRarity = "epic", switchType = "clicky" },
    { id = "linear_brace",   name = "Linear Brace (%s)",   kind = "protect",  baseValue = 1,    baseCost = 28, keyTag = "any",        maxRarity = "epic", switchType = "linear" },
    { id = "steadfast_slider",name = "Steadfast Slider (%s)", kind = "protect", baseValue = 1,  baseCost = 34, keyTag = "any",        maxRarity = "epic", switchType = "linear" },
}

-- Home Row Harmony's nine individual pieces: fixed to one specific key each,
-- always uncommon, always flat. Unremarkable alone -- the point is owning
-- all nine.
for _, letter in ipairs(HOME_ROW_LETTERS) do
    TEMPLATES[#TEMPLATES + 1] = {
        id = "homerow_" .. letter,
        name = "Home Row Series (" .. string.upper(letter) .. ")",
        kind = "flat",
        baseValue = 0.10,
        baseCost = 20,
        fixedKey = letter,
        fixedRarity = "uncommon",
    }
end

-- Legendary set pieces: fixed rarity, fixed (or narrowly tagged) key, never
-- reachable by scaling a common template.
TEMPLATES[#TEMPLATES + 1] = {
    id = "homerow_harmony",
    name = "Home Row Harmony",
    kind = "set",
    baseValue = 1.5,
    baseCost = 140,
    fixedKey = "j",
    fixedRarity = "legendary",
    switchType = "tactile",
    setMembers = (function()
        local ids = {}
        for _, letter in ipairs(HOME_ROW_LETTERS) do ids[#ids + 1] = "homerow_" .. letter end
        return ids
    end)(),
}

TEMPLATES[#TEMPLATES + 1] = {
    id = "space_cadet",
    name = "Space Cadet",
    kind = "coin",
    baseValue = 3,
    baseCost = 120,
    fixedKey = " ",
    fixedRarity = "legendary",
    switchType = "clicky",
}

TEMPLATES[#TEMPLATES + 1] = {
    id = "overclocked_core",
    name = "Overclocked Core",
    kind = "crit",
    baseValue = 0.35,
    baseCost = 150,
    fixedKey = "e",
    fixedRarity = "legendary",
    switchType = "clicky",
}

local function isEligible(template, rarity)
    if template.fixedRarity then
        return template.fixedRarity == rarity
    end
    local maxIdx = Rarity.index(template.maxRarity or "legendary")
    local reqIdx = Rarity.index(rarity)
    if not maxIdx or not reqIdx then return false end
    return reqIdx <= maxIdx
end

local function pickKey(template, keyPool)
    if template.fixedKey then return template.fixedKey end

    keyPool = (keyPool and #keyPool > 0) and keyPool or DEFAULT_KEY_POOL
    local tag = template.keyTag or "any"

    local candidates = {}
    for _, k in ipairs(keyPool) do
        if tag == "any"
            or (tag == "vowel" and VOWELS[k])
            or (tag == "consonant" and not VOWELS[k] and k ~= " ")
        then
            candidates[#candidates + 1] = k
        end
    end

    if #candidates == 0 then candidates = keyPool end
    return candidates[love.math.random(#candidates)]
end

local function defaultKeyForTag(tag)
    if tag == "vowel" then return "e" end
    if tag == "consonant" then return "t" end
    return "e"
end

-- Turn a template into a concrete item. `rarity` is ignored for fixed-rarity
-- templates (they always instantiate at their own tier).
function ItemDefs.instantiate(template, rarity, round, key)
    round = round or 1
    local effectiveRarity = template.fixedRarity or rarity or "common"

    local costMult = Rarity.costMultiplier[effectiveRarity] or 1
    local powerMult = Rarity.powerMultiplier[effectiveRarity] or 1
    -- Round inflation is gentle and caps out so late-run offers stay
    -- readable numbers instead of ballooning forever.
    local roundMult = 1 + math.min(math.max(round - 1, 0), 15) * 0.03

    local value = template.baseValue * powerMult * roundMult
    local cost = math.floor(template.baseCost * costMult * roundMult + 0.5)

    local name = template.name
    if name:find("%%s") then
        name = string.format(name, keyLabel(key))
    end

    local effect = { kind = template.kind, value = value }
    if template.kind == "set" then
        effect.setMembers = template.setMembers
    end

    local id = template.fixedKey and template.id or (template.id .. "_" .. keySlug(key))

    return {
        id = id,
        name = name,
        key = key,
        rarity = effectiveRarity,
        capVariant = CAP_VARIANT_BY_RARITY[effectiveRarity] or "plain",
        switchType = template.switchType or "linear",
        effect = effect,
        cost = cost,
        templateId = template.id, -- extra, non-contract field: handy for UI/debug, ignored by consumers that don't know it
    }
end

-- Roll a concrete offer at the given round/rarity, targeting a key drawn from
-- keyPool (defaults to the full alphabet + punctuation + space).
function ItemDefs.generateOffer(round, rarity, keyPool)
    local candidates = {}
    for _, template in ipairs(TEMPLATES) do
        if isEligible(template, rarity) then
            candidates[#candidates + 1] = template
        end
    end

    if #candidates == 0 then
        -- Should not happen (every rarity has at least one eligible
        -- template), but never hand back nil to a caller mid-shop.
        candidates = { TEMPLATES[1] }
    end

    local template = candidates[love.math.random(#candidates)]
    local key = pickKey(template, keyPool)
    return ItemDefs.instantiate(template, rarity, round, key)
end

-- A stable, deterministic catalogue snapshot: one representative instance per
-- template at round 1 (its own fixed rarity/key if it has one, otherwise
-- common on a representative key). Useful for a future codex screen and for
-- ItemDefs.byId.
local catalogueCache = nil

function ItemDefs.all()
    if catalogueCache then return catalogueCache end

    catalogueCache = {}
    for _, template in ipairs(TEMPLATES) do
        local rarity = template.fixedRarity or "common"
        local key = template.fixedKey or defaultKeyForTag(template.keyTag)
        catalogueCache[#catalogueCache + 1] = ItemDefs.instantiate(template, rarity, 1, key)
    end
    return catalogueCache
end

-- Raw template rows (not the contract shape -- these are pre-instantiation
-- design data). Exposed mainly so tests can drive ItemDefs.instantiate
-- directly against a known template, e.g. to check that a higher rarity of
-- the same template costs and scores more.
function ItemDefs.templates()
    return TEMPLATES
end

function ItemDefs.byId(id)
    for _, item in ipairs(ItemDefs.all()) do
        if item.id == id then return item end
    end
    return nil
end

return ItemDefs
