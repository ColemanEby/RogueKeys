-- tests/test_keycaps.lua
-- Headless coverage for unit 14 (layered keycap rendering): KeyboardView's
-- layout math, hit-testing, and that every public function on the
-- new/changed modules is safe to call with no graphics context.

local H = require("tests/helpers")

local KeyboardModel = require("modules/keyboard/keyboardModel")
local KeyboardView = require("modules/keyboard/keyboardView")
local CapRenderer = require("modules/keyboard/capRenderer")

local T = {}

--------------------------------------------------------------------------
-- KeyboardView: layout geometry
--------------------------------------------------------------------------

local function newView()
    return KeyboardView.new(KeyboardModel.new("qwerty"))
end

function T.dimensions_snap_to_integer_cap_scale()
    local view = newView()

    -- scale = 1.0 -> capScale rounds to 2 (32px art at 2x).
    local dims = view:calculateDimensions(10, 20, 1.0)
    H.equal(dims.capScale, 2)
    H.equal(dims.keyUnit, 64)
    H.equal(dims.x, 10)
    H.equal(dims.y, 20)

    -- A fractional caller scale must still round to a whole capScale so the
    -- 32px art is never stretched by a non-integer factor.
    local fractional = view:calculateDimensions(0, 0, 0.9)
    H.isTrue(fractional.capScale == math.floor(fractional.capScale), "capScale must be a whole number")
    H.equal(fractional.keyUnit % 32, 0, "keyUnit must be an integer multiple of the 32px cap art")
end

function T.row_width_matches_key_count_and_spacing()
    local view = newView()
    local dims = view:calculateDimensions(0, 0, 1.0)

    -- QWERTY top row (Q..P) has 10 single-width keys.
    local topRow = view.layout[1]
    H.equal(#topRow, 10)

    local expected = 0
    for _, keyData in ipairs(topRow) do
        expected = expected + dims.keyUnit * (keyData.w or 1) + dims.spacing
    end
    H.equal(dims.rowWidths[1], expected)
end

function T.total_height_matches_row_count()
    local view = newView()
    local dims = view:calculateDimensions(0, 0, 1.0)
    H.equal(dims.height, #view.layout * dims.rowHeight)
end

--------------------------------------------------------------------------
-- KeyboardView: hit testing
--------------------------------------------------------------------------

function T.get_key_at_position_finds_first_key_in_first_row()
    local view = newView()
    local dims = view:calculateDimensions(0, 0, 1.0)
    local rowX = dims.x + math.floor((dims.width - dims.rowWidths[1]) / 2)

    local value, display = view:getKeyAtPosition(rowX + 1, dims.y + 1, 0, 0, 1.0)
    H.equal(value, "q")
    H.equal(display, "Q")
end

function T.get_key_at_position_finds_space()
    local view = newView()
    local dims = view:calculateDimensions(0, 0, 1.0)

    -- Space is on the last row by itself.
    local lastRowIndex = #view.layout
    local rowY = dims.y + dims.rowHeight * (lastRowIndex - 1)
    local rowX = dims.x + math.floor((dims.width - dims.rowWidths[lastRowIndex]) / 2)

    local value = view:getKeyAtPosition(rowX + 1, rowY + 1, 0, 0, 1.0)
    H.equal(value, " ")
end

function T.get_key_at_position_returns_nil_outside_the_board()
    local view = newView()
    local value = view:getKeyAtPosition(-1000, -1000, 0, 0, 1.0)
    H.equal(value, nil)
end

--------------------------------------------------------------------------
-- Legacy-save rarity fallback (no modules/items/ present)
--------------------------------------------------------------------------

function T.resolve_key_spec_defaults_for_a_plain_key()
    local view = newView()
    local info = view:resolveKeySpec("q")
    H.equal(info.rarity, "common")
    H.equal(info.capVariant, "plain")
    H.equal(info.switchType, "linear")
    H.isFalse(info.isUpgraded)
end

function T.resolve_key_spec_infers_rarity_from_legacy_bonus()
    local view = newView()
    view.keyboardModel:upgradeKey("q", 0.30) -- well into legendary territory
    local info = view:resolveKeySpec("q")
    H.isTrue(info.isUpgraded)
    H.equal(info.rarity, "legendary")
end

function T.resolve_key_spec_uses_preview_item_when_set()
    local view = newView()
    view:setPreviewItem({ key = "Q", rarity = "epic", capVariant = "resin", switchType = "clicky" })
    local info = view:resolveKeySpec("q")
    H.isTrue(info.isPreview)
    H.equal(info.rarity, "epic")
    H.equal(info.capVariant, "resin")
    H.equal(info.switchType, "clicky")

    view:setPreviewItem(nil)
    H.equal(view.previewItem, nil)
end

--------------------------------------------------------------------------
-- Headless safety: nothing here should raise with no window/graphics context
--------------------------------------------------------------------------

function T.keyboard_view_public_functions_are_safe_headless()
    local view = newView()

    H.succeeds(function() view:activateKey("Q") end)
    H.succeeds(function() view:deactivateKey("Q") end)
    H.succeeds(function() view:animateKeyPress("q") end)
    H.succeeds(function() view:animateKeyPress("q", "correct") end)
    H.succeeds(function() view:animateKeyPress("q", "error") end)
    H.succeeds(function() view:update(1 / 60) end)
    H.succeeds(function() view:setPreviewItem({ key = "a", rarity = "rare" }) end)
    H.succeeds(function() view:setPreviewItem(nil) end)
    H.succeeds(function() view:draw(0, 0, 1.0) end)
    H.succeeds(function() view:getKeyAtPosition(0, 0, 0, 0, 1.0) end)
end

function T.cap_renderer_public_functions_are_safe_headless()
    H.isFalse(CapRenderer.load(), "load() must no-op (return false) with no graphics context")
    H.succeeds(function()
        CapRenderer.draw(0, 0, 64, 64, {
            char = "a", display = "A", rarity = "legendary", capVariant = "resin",
            switchType = "clicky", pressed = true, active = true, glow = "correct", bonus = 0.2,
        })
    end)
    H.succeeds(function() CapRenderer.draw(0, 0, 64, 64) end)
    H.succeeds(function() CapRenderer.draw(0, 0, 64, 64, { rarity = "not_a_real_rarity" }) end)
end

return T
