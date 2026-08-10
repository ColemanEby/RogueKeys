-- tests/test_theme.lua
-- Pins the shape of modules/ui/theme.lua: palette, rarity, switches,
-- spacing, font sizes, hex parsing and the lazy font loader.

local H = require("tests/helpers")
local Theme = require("modules/ui/theme")

local T = {}

-- ---------------------------------------------------------------------------
-- Palette shape

function T.palette_contains_all_expected_keys()
    local expected = {
        "base", "baseAlt", "panel", "panelLight", "border", "borderLight",
        "text", "textMuted", "textDim", "accent", "accentDark",
        "success", "error", "warning", "info",
        "typed", "pending", "wrong", "caret", "ghost",
    }
    H.hasKeys(Theme.palette, expected)
end

function T.palette_values_are_four_floats_in_unit_range()
    for name, color in pairs(Theme.palette) do
        H.isType(color, "table", "palette[" .. name .. "] must be a table")
        H.equal(#color, 4, "palette[" .. name .. "] must have four components")
        for i = 1, 4 do
            H.isType(color[i], "number", "palette[" .. name .. "][" .. i .. "]")
            H.between(color[i], 0, 1, "palette[" .. name .. "][" .. i .. "] out of range")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Rarity shape

function T.rarity_keys_match_rarityOrder()
    H.deepEqual(Theme.rarityOrder, { "common", "uncommon", "rare", "epic", "legendary" })
    for _, key in ipairs(Theme.rarityOrder) do
        H.isTrue(Theme.rarity[key] ~= nil, "rarity missing key: " .. key)
    end
    H.equal(H.count(Theme.rarity), #Theme.rarityOrder, "rarity has extra or missing keys")
end

function T.rarity_values_are_four_floats_in_unit_range()
    for name, color in pairs(Theme.rarity) do
        H.isType(color, "table", "rarity[" .. name .. "]")
        H.equal(#color, 4, "rarity[" .. name .. "] component count")
        for i = 1, 4 do
            H.isType(color[i], "number", "rarity[" .. name .. "][" .. i .. "]")
            H.between(color[i], 0, 1, "rarity[" .. name .. "][" .. i .. "] out of range")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Switch colors

function T.switches_contains_linear_tactile_clicky()
    H.hasKeys(Theme.switches, { "linear", "tactile", "clicky" })
    H.equal(H.count(Theme.switches), 3, "switches should have exactly three entries")
end

function T.switches_values_are_four_floats_in_unit_range()
    for name, color in pairs(Theme.switches) do
        H.isType(color, "table", "switches[" .. name .. "]")
        H.equal(#color, 4, "switches[" .. name .. "] component count")
        for i = 1, 4 do
            H.isType(color[i], "number", "switches[" .. name .. "][" .. i .. "]")
            H.between(color[i], 0, 1, "switches[" .. name .. "][" .. i .. "] out of range")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Spacing and font sizes

function T.spacing_has_strictly_increasing_positive_integers()
    local order = { "xs", "sm", "md", "lg", "xl", "xxl" }
    H.hasKeys(Theme.spacing, order)
    H.equal(H.count(Theme.spacing), #order)

    local previous = 0
    for _, key in ipairs(order) do
        local value = Theme.spacing[key]
        H.isType(value, "number", "spacing[" .. key .. "]")
        H.equal(value, math.floor(value), "spacing[" .. key .. "] must be an integer")
        H.isTrue(value > 0, "spacing[" .. key .. "] must be positive")
        H.isTrue(value > previous, "spacing[" .. key .. "] must increase from previous")
        previous = value
    end
end

function T.fontSizes_has_positive_integers()
    local expected = { "display", "heading", "body", "mono", "small" }
    H.hasKeys(Theme.fontSizes, expected)
    H.equal(H.count(Theme.fontSizes), #expected)

    for _, key in ipairs(expected) do
        local value = Theme.fontSizes[key]
        H.isType(value, "number", "fontSizes[" .. key .. "]")
        H.equal(value, math.floor(value), "fontSizes[" .. key .. "] must be an integer")
        H.isTrue(value > 0, "fontSizes[" .. key .. "] must be positive")
    end
end

-- ---------------------------------------------------------------------------
-- Hex parsing

function T.hex_parses_six_digit_red_to_unit_rgb()
    local c = Theme.hex("#ff0000")
    H.equal(#c, 4)
    H.equal(c[1], 1)
    H.equal(c[2], 0)
    H.equal(c[3], 0)
    H.equal(c[4], 1)
end

function T.hex_parses_eight_digit_with_alpha()
    local c = Theme.hex("#00000080")
    H.equal(#c, 4)
    H.equal(c[1], 0)
    H.equal(c[2], 0)
    H.equal(c[3], 0)
    H.near(c[4], 128 / 255, 1e-9)
end

function T.hex_explicit_alpha_overrides_embedded_alpha()
    local c = Theme.hex("#00000080", 1)
    H.equal(c[4], 1)

    local c2 = Theme.hex("#ffffff", 0.5)
    H.near(c2[4], 0.5, 1e-9)
end

-- ---------------------------------------------------------------------------
-- Font loading (headless-safe)

function T.font_does_not_error_headless_and_may_return_nil()
    local result = H.succeeds(function() return Theme.font("body") end)
    H.isTrue(result == nil or type(result) == "userdata", "headless font result should be nil or a Font")
end

return T
