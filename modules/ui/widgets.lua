-- modules/ui/widgets.lua
-- Stateless drawing primitives shared by every themed screen. Everything here
-- works in logical 640x360 coordinates (see modules/ui/screen.lua) and pulls
-- every color/font from modules/ui/theme.lua -- no raw RGBA literals, no
-- love.graphics.newFont calls.
--
-- Widgets never hit-test for you (see Widgets.hit) and never hold state; a
-- caller (MenuBuilder, shopState's card grid, etc.) owns hover/press/selection
-- and passes it in via opts.state / opts.rarity / etc. That is what lets five
-- different states share one drawing vocabulary without fighting each other.

local Theme = require("modules/ui/theme")
local ResourceManager = require("engine/resourceManager")

local Widgets = {}

-- True only when there is a real graphics context to draw into. Headless test
-- runs (love . --test) have no window, so every drawing function below must
-- no-op rather than throw.
local function available()
    return love ~= nil and love.graphics ~= nil and not _G.HEADLESS
end

-- ---------------------------------------------------------------------------
-- Nine-patch panel, with a procedural pixel-bevel fallback.
--
-- Unit 3 (ResourceManager) is adding getNinePatch in parallel; this worktree
-- may or may not have it yet, so every call into it is pcall-guarded. The
-- fallback draws a deliberate 1px-bevel panel so the game never looks
-- unstyled while the real atlas (resources/sprites/ui_panel.png) is missing.
local function tryNinePatch(name, x, y, w, h, variant)
    local ok, patch = pcall(function() return ResourceManager:getNinePatch(name) end)
    if not ok or not patch then return false end

    local drew = pcall(function()
        if type(patch.draw) == "function" then
            patch:draw(x, y, w, h, variant)
        elseif type(patch) == "function" then
            patch(x, y, w, h, variant)
        else
            error("unrecognized nine-patch shape")
        end
    end)
    return drew
end

-- variant -> { fill, border, light } palette names.
local PANEL_VARIANTS = {
    panel  = { fill = "panel",      border = "border", light = "borderLight" },
    raised = { fill = "panelLight", border = "border", light = "borderLight" },
    sunken = { fill = "baseAlt",    border = "border", light = "borderLight" },
    accent = { fill = "panel",      border = "accent", light = "accent" },
}

local function drawBeveledPanel(x, y, w, h, variantName, alpha)
    local colors = PANEL_VARIANTS[variantName] or PANEL_VARIANTS.panel
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    if w <= 0 or h <= 0 then return end

    -- Outer 1px border, doubling as the shadow side of the bevel.
    Theme.setColor(colors.border, alpha)
    love.graphics.rectangle("fill", x, y, w, h)

    if w > 2 and h > 2 then
        Theme.setColor(colors.fill, alpha)
        love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    end

    if w > 2 and h > 2 then
        Theme.setColor(colors.light, alpha)
        if variantName == "sunken" then
            -- Recessed: the lit edge reads on the bottom/right instead.
            love.graphics.line(x + 1, y + h - 2, x + w - 2, y + h - 2)
            love.graphics.line(x + w - 2, y + 1, x + w - 2, y + h - 2)
        else
            love.graphics.line(x + 1, y + 1, x + w - 2, y + 1)
            love.graphics.line(x + 1, y + 1, x + 1, y + h - 2)
        end
    end
end

-- Widgets.panel(x, y, w, h, opts)
-- opts.variant: "panel" | "raised" | "sunken" | "accent"
-- opts.alpha:   optional alpha override (nil = fully opaque)
function Widgets.panel(x, y, w, h, opts)
    if not available() then return end
    opts = opts or {}
    local variant = opts.variant or "panel"

    if tryNinePatch("ui_panel", x, y, w, h, variant) then return end
    drawBeveledPanel(x, y, w, h, variant, opts.alpha)
end

-- ---------------------------------------------------------------------------
-- Text helpers. Callers should never touch a love.Font directly.

-- Widgets.textWidth(text, role)
function Widgets.textWidth(text, role)
    role = role or "body"
    text = text or ""
    if available() then
        local font = Theme.font(role)
        if font then return font:getWidth(text) end
    end
    local size = Theme.fontSizes[role] or Theme.fontSizes.body
    return #text * size * 0.6
end

-- Widgets.textHeight(role)
function Widgets.textHeight(role)
    role = role or "body"
    if available() then
        local font = Theme.font(role)
        if font then return font:getHeight() end
    end
    return Theme.fontSizes[role] or Theme.fontSizes.body
end

-- Widgets.label(x, y, w, text, opts)
-- opts.align: "left" | "center" | "right" | "justify" (default "left")
-- opts.role:  font role (default "body")
-- opts.color: theme color name (default "text")
-- opts.alpha: optional alpha override
function Widgets.label(x, y, w, text, opts)
    if not available() then return end
    opts = opts or {}

    local font = Theme.font(opts.role or "body")
    if font then love.graphics.setFont(font) end

    Theme.setColor(opts.color or "text", opts.alpha)
    love.graphics.printf(text or "", x, y, w, opts.align or "left")
end

-- ---------------------------------------------------------------------------
-- Buttons.

local BUTTON_VARIANT_BY_STATE = {
    normal   = "panel",
    hover    = "raised",
    pressed  = "sunken",
    disabled = "panel",
    selected = "accent",
}

local BUTTON_TEXT_COLOR_BY_STATE = {
    normal   = "text",
    hover    = "text",
    pressed  = "text",
    disabled = "textDim",
    selected = "base", -- dark text reads on the gold accent fill
}

-- Widgets.button(x, y, w, h, label, opts)
-- opts.state: "normal" | "hover" | "pressed" | "disabled" | "selected"
-- opts.role:  font role for the label (default "body")
-- Hit-testing is the caller's job (Widgets.hit) -- this only draws.
function Widgets.button(x, y, w, h, label, opts)
    if not available() then return end
    opts = opts or {}
    local state = opts.state or "normal"
    local variant = BUTTON_VARIANT_BY_STATE[state] or "panel"

    Widgets.panel(x, y, w, h, { variant = variant, alpha = (state == "disabled") and 0.6 or nil })

    local role = opts.role or "body"
    local th = Widgets.textHeight(role)
    Widgets.label(x, y + (h - th) / 2, w, label or "", {
        align = "center",
        role = role,
        color = opts.color or BUTTON_TEXT_COLOR_BY_STATE[state] or "text",
    })
end

-- ---------------------------------------------------------------------------
-- Bars (progress / streak meters).

-- Widgets.bar(x, y, w, h, fraction, opts)
-- opts.color: fill color name (default "accent")
-- opts.glow:  boolean, draws a soft overshoot glow on the fill edge
function Widgets.bar(x, y, w, h, fraction, opts)
    if not available() then return end
    opts = opts or {}
    fraction = math.max(0, math.min(1, fraction or 0))

    Widgets.panel(x, y, w, h, { variant = "sunken" })

    local innerX, innerY = x + 1, y + 1
    local innerW, innerH = w - 2, h - 2
    if innerW <= 0 or innerH <= 0 then return end

    local fillW = math.floor(innerW * fraction + 0.5)
    if fillW <= 0 then return end

    local color = opts.color or "accent"
    Theme.setColor(color)
    love.graphics.rectangle("fill", innerX, innerY, fillW, innerH)

    if opts.glow then
        Theme.setColor(color, 0.35)
        love.graphics.rectangle("fill", innerX, innerY - 1, fillW, innerH + 2)
    end
end

-- ---------------------------------------------------------------------------
-- Sliders. Value math is split into pure helpers so MenuBuilder (and tests)
-- can reuse it without a graphics context.

-- Widgets.sliderFraction(value, min, max) -> 0..1
function Widgets.sliderFraction(value, min, max)
    if not max or not min or max <= min then return 0 end
    local f = (value - min) / (max - min)
    if f < 0 then return 0 end
    if f > 1 then return 1 end
    return f
end

-- Widgets.clampSliderValue(value, min, max, step) -> value snapped to the
-- step grid (if step > 0) and clamped to [min, max].
function Widgets.clampSliderValue(value, min, max, step)
    if min > max then min, max = max, min end
    if step and step > 0 then
        value = min + math.floor((value - min) / step + 0.5) * step
    end
    if value < min then value = min end
    if value > max then value = max end
    return value
end

-- Widgets.sliderValueFromX(px, x, w, min, max, step) -> value at a pixel
-- position along a track of width w starting at x. Used for click-to-set and
-- drag handling.
function Widgets.sliderValueFromX(px, x, w, min, max, step)
    local f = 0
    if w and w > 0 then f = (px - x) / w end
    if f < 0 then f = 0 end
    if f > 1 then f = 1 end
    local value = min + f * (max - min)
    return Widgets.clampSliderValue(value, min, max, step)
end

-- Widgets.slider(x, y, w, value, min, max, opts)
-- opts.h:       track thickness (default 6)
-- opts.state:   "normal" | "hover" | "pressed" -- tints the handle
-- opts.color:   fill color name (default "accent")
-- opts.handleW: handle width in pixels (default 4)
function Widgets.slider(x, y, w, value, min, max, opts)
    if not available() then return end
    opts = opts or {}
    local h = opts.h or 6

    Widgets.panel(x, y, w, h, { variant = "sunken" })

    local fraction = Widgets.sliderFraction(value, min, max)
    local fillW = math.floor(math.max(w - 2, 0) * fraction + 0.5)
    if fillW > 0 then
        Theme.setColor(opts.color or "accent")
        love.graphics.rectangle("fill", x + 1, y + 1, fillW, h - 2)
    end

    local handleW = opts.handleW or 4
    local handleX = x + math.floor(fraction * math.max(w - handleW, 0))
    local handleColor = "borderLight"
    if opts.state == "hover" or opts.state == "pressed" then handleColor = "accent" end
    Theme.setColor(handleColor)
    love.graphics.rectangle("fill", handleX, y - 2, handleW, h + 4)
end

-- ---------------------------------------------------------------------------
-- Tabs.

-- Widgets.tabRect(x, y, w, h, count, index) -> x, y, w, h of one tab.
-- Shared by draw and hit-testing so they can never disagree.
function Widgets.tabRect(x, y, w, h, count, index)
    if not count or count <= 0 then return x, y, 0, h end
    local tabW = w / count
    return x + (index - 1) * tabW, y, tabW, h
end

-- Widgets.tabs(x, y, w, items, activeIndex, opts)
-- items: array of label strings.
function Widgets.tabs(x, y, w, items, activeIndex, opts)
    if not available() then return end
    opts = opts or {}
    items = items or {}
    local count = #items
    if count == 0 then return end

    local h = opts.h or 20
    local role = opts.role or "body"

    for i, label in ipairs(items) do
        local tx, ty, tw, th = Widgets.tabRect(x, y, w, h, count, i)
        local isActive = (i == activeIndex)

        Widgets.panel(tx, ty, tw, th, { variant = isActive and "accent" or "panel" })
        Widgets.label(tx, ty + (th - Widgets.textHeight(role)) / 2, tw, label, {
            align = "center",
            role = role,
            color = isActive and "base" or "textMuted",
        })
    end
end

-- ---------------------------------------------------------------------------
-- Cards (shop item frame). Rarity tints the border; everything else matches
-- the standard panel bevel.

-- Widgets.card(x, y, w, h, opts)
-- opts.rarity: "common" | "uncommon" | "rare" | "epic" | "legendary"
function Widgets.card(x, y, w, h, opts)
    if not available() then return end
    opts = opts or {}
    local borderColor = opts.rarity and ("rarity." .. opts.rarity) or "border"

    if tryNinePatch("ui_card", x, y, w, h, opts.rarity) then
        Theme.setColor(borderColor)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
        return
    end

    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    if w <= 2 or h <= 2 then return end

    Theme.setColor(borderColor)
    love.graphics.rectangle("fill", x, y, w, h)

    Theme.setColor("panel")
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)

    Theme.setColor("borderLight")
    love.graphics.line(x + 1, y + 1, x + w - 2, y + 1)
    love.graphics.line(x + 1, y + 1, x + 1, y + h - 2)
end

-- ---------------------------------------------------------------------------
-- Hit-testing. Inclusive on the top/left edge, exclusive on bottom/right --
-- so adjacent widgets sharing an edge never both claim the same pixel.

-- Widgets.hit(px, py, x, y, w, h) -> bool
function Widgets.hit(px, py, x, y, w, h)
    return px >= x and px < x + w and py >= y and py < y + h
end

return Widgets
