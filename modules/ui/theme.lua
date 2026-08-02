-- modules/ui/theme.lua
-- The single source of truth for palette, fonts and spacing.
--
-- Every color literal in the codebase should migrate here. Fonts are created
-- lazily (never at require time, so headless test runs stay graphics-free) and
-- cached, so no state should ever call love.graphics.newFont itself.
--
-- Asset drop-in: place monogram.ttf and m6x11.ttf in resources/fonts/ and they
-- are picked up automatically. Until then the LOVE default font is used at the
-- same sizes, so layout math is unaffected.

local Theme = {}

-- Convert #rrggbb / #rrggbbaa to LOVE's 0..1 float components.
local function hex(s, alpha)
    s = s:gsub("#", "")
    local r = tonumber(s:sub(1, 2), 16) / 255
    local g = tonumber(s:sub(3, 4), 16) / 255
    local b = tonumber(s:sub(5, 6), 16) / 255
    local a = alpha
    if not a and #s >= 8 then a = tonumber(s:sub(7, 8), 16) / 255 end
    return { r, g, b, a or 1 }
end

Theme.hex = hex

Theme.palette = {
    base       = hex("#14141f"), -- deepest background
    baseAlt    = hex("#0e0e17"), -- letterbox / recessed areas
    panel      = hex("#1e1e2a"), -- card and panel fill
    panelLight = hex("#2a2a3a"), -- raised panel / hover fill
    border     = hex("#3a3a4e"),
    borderLight= hex("#55556e"),

    text       = hex("#e8e8f0"),
    textMuted  = hex("#8a8aa0"),
    textDim    = hex("#5a5a72"),

    accent     = hex("#ffc94a"), -- gold: selection, money, titles
    accentDark = hex("#c9922a"),
    success    = hex("#5ad46e"),
    error      = hex("#e05a5a"),
    warning    = hex("#e0a04a"),
    info       = hex("#5aa8e0"),

    -- Typing line states
    typed      = hex("#5ad46e"),
    pending    = hex("#8a8aa0"),
    wrong      = hex("#e05a5a"),
    caret      = hex("#ffc94a"),
    ghost      = hex("#3a3a4e"),
}

-- Rarity is a first-class visual language: cap color, price tier and glow all
-- key off these. Order matters (ascending rarity).
Theme.rarityOrder = { "common", "uncommon", "rare", "epic", "legendary" }

Theme.rarity = {
    common    = hex("#9aa0ad"),
    uncommon  = hex("#5ad46e"),
    rare      = hex("#5aa8e0"),
    epic      = hex("#b06ae0"),
    legendary = hex("#ffc94a"),
}

-- Mechanical switch colors, used for the stem peeking under a keycap.
Theme.switches = {
    linear  = hex("#e05a5a"), -- red
    tactile = hex("#a0704a"), -- brown
    clicky  = hex("#5a8ae0"), -- blue
}

-- Spacing scale, in logical (640x360) pixels.
Theme.spacing = {
    xs = 2,
    sm = 4,
    md = 8,
    lg = 16,
    xl = 24,
    xxl = 32,
}

Theme.radius = 0 -- pixel art: square corners by default

-- Font roles. Sizes are logical pixels; keep them integers so bitmap-style
-- fonts stay crisp.
Theme.fontSizes = {
    display = 24, -- titles, big scores
    heading = 16, -- section headers
    body    = 12, -- general UI text
    mono    = 12, -- the typing line and stat tables
    small   = 10, -- captions, help text
}

-- Preferred font files per role, tried in order. Missing files fall through to
-- the LOVE default font at the same size.
local FONT_FILES = {
    display = { "resources/fonts/m6x11.ttf", "resources/fonts/monogram.ttf" },
    heading = { "resources/fonts/m6x11.ttf", "resources/fonts/monogram.ttf" },
    body    = { "resources/fonts/m6x11.ttf", "resources/fonts/monogram.ttf" },
    mono    = { "resources/fonts/monogram.ttf" },
    small   = { "resources/fonts/monogram.ttf", "resources/fonts/m6x11.ttf" },
}

local fontCache = {}

-- Get a font for a role, optionally at a non-default size.
function Theme.font(role, size)
    role = role or "body"
    size = size or Theme.fontSizes[role] or Theme.fontSizes.body

    local key = role .. "_" .. size
    if fontCache[key] then return fontCache[key] end

    if not love.graphics or _G.HEADLESS then return nil end

    local font
    for _, path in ipairs(FONT_FILES[role] or {}) do
        if love.filesystem.getInfo(path) then
            local ok, result = pcall(love.graphics.newFont, path, size)
            if ok then
                font = result
                break
            end
        end
    end

    if not font then
        font = love.graphics.newFont(size)
    end

    font:setFilter("nearest", "nearest")
    fontCache[key] = font
    return font
end

-- Look up a palette color by name. Accepts "rarity.epic" and "switch.clicky".
function Theme.color(name, alpha)
    local c

    local group, key = name:match("^(%w+)%.(%w+)$")
    if group == "rarity" then
        c = Theme.rarity[key]
    elseif group == "switch" then
        c = Theme.switches[key]
    else
        c = Theme.palette[name]
    end

    if not c then
        -- Loud magenta so a typo is visible rather than silent.
        return { 1, 0, 1, 1 }
    end

    if alpha then
        return { c[1], c[2], c[3], alpha }
    end
    return c
end

-- Convenience: apply a palette color directly.
function Theme.setColor(name, alpha)
    local c = Theme.color(name, alpha)
    love.graphics.setColor(c[1], c[2], c[3], c[4])
end

-- Clear the font cache (used when the window/graphics context is recreated).
function Theme.reset()
    fontCache = {}
end

return Theme
