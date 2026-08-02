-- modules/keyboard/capRenderer.lua
-- Layered keycap rendering. A key is a stack, not one sprite:
--
--   switch/housing base -> keycap body (recolored by rarity/material)
--     -> legend (glyph) -> effect overlay (glow / selection ring / bonus pip)
--
-- This is what makes an upgrade *visible*: a new switch changes the base
-- layer's color, a new cap changes the body layer's color and shape details.
--
-- The licensed Caz keycap pack could not be downloaded for this build, so the
-- body layer is generated procedurally at load time with
-- love.image.newImageData and recolored per rarity/capVariant. Real art drops
-- in automatically -- see REAL_SHEET_PATH below.
--
-- CapRenderer.draw(x, y, w, h, spec) expects x/y/w/h already snapped to whole
-- pixels in whatever coordinate space the caller is using, and w/h that are
-- an exact integer multiple of CAP_SIZE (KeyboardView.calculateDimensions
-- guarantees this) -- pixel art must never be scaled by a fractional factor.
--
-- spec = { char, display, rarity, capVariant, switchType, pressed, active,
--          glow, bonus }
--   char       lowercase key value, used only as a fallback legend
--   display    text to draw as the legend (empty/nil draws no legend)
--   rarity     common|uncommon|rare|epic|legendary (default: common)
--   capVariant plain|dyesub|doubleshot|artisan|resin (default: plain)
--   switchType linear|tactile|clicky, colors the housing stem (default: linear)
--   pressed    true draws the depressed cap art, shifted down 2px
--   active     true draws a thin selection ring (shop hover / preview)
--   glow       "correct" | "error" | true -- a soft outer glow ring; true
--              uses the rarity color (ambient "this key is special" glow)
--   bonus      0..1 score bonus fraction; drawn as a small "+NN%" pip

local Theme = require("modules/ui/theme")

local CapRenderer = {}

local CAP_SIZE = 32
local PRESS_OFFSET = 2

-- Real asset drop-in: place a 320x160 sheet here and it replaces the
-- generated art automatically, with the same layered treatment (housing,
-- legend and overlay are still drawn by this module on top of it).
--
-- Expected layout, all cells 32x32:
--   columns (10): capVariant in {plain, dyesub, doubleshot, artisan, resin}
--                 order, two columns each -- "up" state then "pressed" state.
--   rows (5):     rarity in {common, uncommon, rare, epic, legendary} order.
--   Cell(col, row) top-left pixel = ((col-1)*32, (row-1)*32).
local REAL_SHEET_PATH = "resources/sprites/keycaps_32.png"

local VARIANT_ORDER = { "plain", "dyesub", "doubleshot", "artisan", "resin" }
local RARITY_ORDER = Theme.rarityOrder

-- Roles baked into the procedural template's red channel (as role/5) so one
-- shape can be recolored for any rarity/capVariant without new art.
local ROLE_OUTLINE, ROLE_SKIRT, ROLE_BODY, ROLE_HIGHLIGHT, ROLE_SHINE = 0, 1, 2, 3, 4

local cache = {
    loaded = false,
    sheetImage = nil,  -- real drop-in art, if present
    quads = {},        -- "col_row" -> love.Quad, for the real sheet
    templates = {},     -- [pressed:boolean] -> role ImageData
    tinted = {},        -- "rarity|variant|pressed" -> love.Image
}

local function clamp01(v)
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

local function lighten(c, amt)
    return { clamp01(c[1] + amt), clamp01(c[2] + amt), clamp01(c[3] + amt), c[4] or 1 }
end

local function darken(c, amt)
    return lighten(c, -amt)
end

-- Build the grayscale-ish "shape" of a keycap: outline, bevelled skirt, top
-- face, a highlight band and a thin diagonal shine. Pressed caps get a
-- shorter skirt and thinner highlight so they read as flatter/sunk in;
-- combined with the 2px downward draw offset in CapRenderer.draw, this sells
-- the depress without ever scaling the art.
local SHINE_LENGTH = 6

local function buildTemplateData(pressed)
    local size = CAP_SIZE
    local data = love.image.newImageData(size, size)

    local skirt = pressed and 2 or 3
    local highlightBand = pressed and 2 or 5

    for y = 0, size - 1 do
        for x = 0, size - 1 do
            -- Corners are opaque outline rather than transparent. A wide key
            -- (the spacebar is 5 units) stretches the template horizontally,
            -- which turns a single transparent corner pixel into a block wide
            -- enough to expose the switch stem behind it as a stray red dot.
            local role
            if x == 0 or x == size - 1 or y == 0 or y == size - 1 then
                role = ROLE_OUTLINE
            elseif x <= skirt or x >= size - 1 - skirt or y <= skirt or y >= size - 1 - skirt then
                role = ROLE_SKIRT
            elseif y <= skirt + highlightBand then
                role = ROLE_HIGHLIGHT
            elseif (x - y) >= 3 and (x - y) <= 4
                and y > skirt + highlightBand
                and y <= skirt + highlightBand + SHINE_LENGTH then
                -- A short glint below the highlight band. Left unbounded it
                -- runs the full diagonal and reads as a scratch, not a shine.
                role = ROLE_SHINE
            else
                role = ROLE_BODY
            end
            data:setPixel(x, y, role / 5, 0, 0, 1)
        end
    end

    return data
end

-- Map a template role to a concrete color for a given rarity/material. Kept
-- as a pure function of Theme colors so any rarity string works without new
-- art -- an unrecognised rarity just falls through to Theme.color's loud
-- magenta, which is a visible bug marker rather than a crash.
local function roleColor(role, rarity, variant)
    local rc = Theme.color("rarity." .. rarity)

    if role == ROLE_OUTLINE then
        return darken(rc, 0.55)
    elseif role == ROLE_SKIRT then
        local amt = (variant == "dyesub") and 0.34 or 0.22
        return darken(rc, amt)
    elseif role == ROLE_HIGHLIGHT then
        return lighten(rc, 0.28)
    elseif role == ROLE_SHINE then
        if variant == "artisan" or variant == "resin" then
            return lighten(rc, 0.55)
        end
        return lighten(rc, 0.16)
    else -- ROLE_BODY
        if variant == "doubleshot" then
            return lighten(rc, 0.05)
        end
        return rc
    end
end

local function buildTintedImage(rarity, variant, pressed)
    local template = cache.templates[pressed]
    if not template then return nil end

    local w, h = template:getDimensions()
    local img = love.image.newImageData(w, h)
    img:paste(template, 0, 0, 0, 0, w, h)

    img:mapPixel(function(x, y, r, g, b, a)
        if a <= 0 then return 0, 0, 0, 0 end
        local role = math.floor(r * 5 + 0.5)
        local c = roleColor(role, rarity, variant)
        local outA = a
        -- Resin caps read as translucent.
        if variant == "resin" and role ~= ROLE_OUTLINE then
            outA = a * 0.78
        end
        return c[1], c[2], c[3], outA
    end)

    local image = love.graphics.newImage(img)
    image:setFilter("nearest", "nearest")
    return image
end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return 1
end

local function realArtQuad(rarity, variant, pressed)
    if not cache.sheetImage then return nil end

    local col = (indexOf(VARIANT_ORDER, variant) - 1) * 2 + (pressed and 2 or 1)
    local row = indexOf(RARITY_ORDER, rarity)
    local key = col .. "_" .. row

    if cache.quads[key] then return cache.quads[key] end

    local sw, sh = cache.sheetImage:getDimensions()
    local quad = love.graphics.newQuad((col - 1) * CAP_SIZE, (row - 1) * CAP_SIZE, CAP_SIZE, CAP_SIZE, sw, sh)
    cache.quads[key] = quad
    return quad
end

local function getCapImage(rarity, variant, pressed)
    local key = rarity .. "|" .. variant .. "|" .. tostring(pressed)
    if cache.tinted[key] ~= nil then return cache.tinted[key] end

    local ok, img = pcall(buildTintedImage, rarity, variant, pressed)
    cache.tinted[key] = (ok and img) or false
    return cache.tinted[key] or nil
end

-- Pick a readable ink color for the legend against a given rarity's body
-- brightness.
local function legendColor(rarity)
    local c = Theme.color("rarity." .. rarity)
    local luminance = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
    return luminance > 0.6 and Theme.color("base") or Theme.color("text")
end

-- Loads (or generates) the art this renderer needs. Safe to call repeatedly;
-- safe to call headless (no-ops). draw() calls this lazily so callers never
-- need to remember to.
function CapRenderer.load()
    if cache.loaded then return true end
    if _G.HEADLESS or not love.graphics or not love.image then return false end

    if love.filesystem.getInfo(REAL_SHEET_PATH) then
        local ok, img = pcall(love.graphics.newImage, REAL_SHEET_PATH)
        if ok and img then
            img:setFilter("nearest", "nearest")
            cache.sheetImage = img
        end
    end

    if not cache.sheetImage then
        local okUp, up = pcall(buildTemplateData, false)
        local okDown, down = pcall(buildTemplateData, true)
        if okUp then cache.templates[false] = up end
        if okDown then cache.templates[true] = down end
    end

    cache.loaded = true
    return true
end

-- Draw one key: housing, cap, legend and overlay. x/y/w/h are expected to
-- already be whole pixels in the caller's coordinate space, with w/h an
-- integer multiple of CAP_SIZE.
function CapRenderer.draw(x, y, w, h, spec)
    if _G.HEADLESS or not love.graphics then return end
    spec = spec or {}
    if not cache.loaded then CapRenderer.load() end

    local rarity = spec.rarity or "common"
    local variant = spec.capVariant or "plain"
    local switchType = spec.switchType or "linear"
    local pressed = spec.pressed and true or false

    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    w, h = math.floor(w + 0.5), math.floor(h + 0.5)
    if w <= 0 or h <= 0 then return end

    -- Ambient/transient glow, drawn behind everything else.
    if spec.glow then
        local glowColor
        if spec.glow == "error" then
            glowColor = Theme.color("error")
        elseif spec.glow == "correct" then
            glowColor = Theme.color("success")
        else
            glowColor = Theme.color("rarity." .. rarity)
        end
        for i = 3, 1, -1 do
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.10 * i)
            love.graphics.rectangle("fill", x - i, y - i, w + i * 2, h + i * 2)
        end
    end

    -- 1. switch/housing base. Drawn as a stem strip along the bottom edge that
    -- the cap sits on top of, rather than a full rect behind the cap: at full
    -- w/h the cap covers everything except the template's four clipped corner
    -- pixels, which read as stray colored dots on every key instead of as a
    -- switch. The strip is what actually reads as "stem peeking under the cap",
    -- and the press offset widens it, so a press looks like travel.
    local stemH = math.max(2, math.floor(h / 16))
    if pressed then stemH = stemH + PRESS_OFFSET end
    Theme.setColor("switch." .. switchType)
    love.graphics.rectangle("fill", x + stemH, y + h - stemH, w - stemH * 2, stemH)

    local capY = pressed and (y + PRESS_OFFSET) or y

    -- 2. keycap body.
    love.graphics.setColor(1, 1, 1, 1)
    local drewCap = false
    if cache.sheetImage then
        local quad = realArtQuad(rarity, variant, pressed)
        if quad then
            love.graphics.draw(cache.sheetImage, quad, x, capY, 0, w / CAP_SIZE, h / CAP_SIZE)
            drewCap = true
        end
    end
    if not drewCap then
        local image = getCapImage(rarity, variant, pressed)
        if image then
            love.graphics.draw(image, x, capY, 0, w / CAP_SIZE, h / CAP_SIZE)
            drewCap = true
        end
    end
    if not drewCap then
        -- Driver rejected image generation (or we're between load() calls);
        -- a flat rarity-tinted rectangle still conveys tier/upgrade state.
        Theme.setColor("rarity." .. rarity)
        love.graphics.rectangle("fill", x, capY, w, h)
    end

    -- Doubleshot caps mold the legend from a second, contrasting plastic --
    -- approximate that with a translucent plate behind the glyph.
    if variant == "doubleshot" then
        Theme.setColor("text", 0.22)
        love.graphics.rectangle("fill", x + w * 0.22, capY + h * 0.2, w * 0.56, h * 0.5)
    end

    -- 3. legend.
    local label = spec.display or spec.char
    if label and label ~= "" and label ~= "Space" then
        local font = Theme.font("small")
        if font then
            love.graphics.setFont(font)
            local c = legendColor(rarity)
            love.graphics.setColor(c[1], c[2], c[3], c[4])
            local tw, th = font:getWidth(label), font:getHeight()
            love.graphics.print(label, x + (w - tw) / 2, capY + (h - th) / 2)
        end
    end

    -- 4. effect overlay: selection ring and bonus pip.
    if spec.active then
        Theme.setColor("accent")
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    end

    if spec.bonus and spec.bonus > 0 then
        local font = Theme.font("small")
        if font then
            love.graphics.setFont(font)
            Theme.setColor("accent")
            local text = string.format("+%.0f%%", spec.bonus * 100)
            local tw = font:getWidth(text)
            love.graphics.print(text, x + w - tw - 1, y + h - font:getHeight())
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

CapRenderer.CAP_SIZE = CAP_SIZE

return CapRenderer
