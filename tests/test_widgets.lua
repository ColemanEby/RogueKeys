-- tests/test_widgets.lua
-- Headless coverage for the themed UI kit (modules/ui/widgets.lua,
-- modules/ui/menuBuilder.lua). No graphics context is available here, so this
-- only exercises pure logic: hit-testing, slider math, height accounting and
-- selection/mouse bookkeeping. Every drawing call must be a safe no-op.

local H = require("tests/helpers")
local Theme = require("modules/ui/theme")
local Widgets = require("modules/ui/widgets")
local MenuBuilder = require("modules/ui/menuBuilder")

local T = {}

-- ---------------------------------------------------------------------------
-- Widgets.hit

function T.hit_top_left_corner_is_inclusive()
    H.isTrue(Widgets.hit(10, 10, 10, 10, 20, 20))
end

function T.hit_bottom_right_edge_is_exclusive()
    H.isFalse(Widgets.hit(30, 15, 10, 10, 20, 20), "x + w must not count as inside")
    H.isFalse(Widgets.hit(15, 30, 10, 10, 20, 20), "y + h must not count as inside")
end

function T.hit_just_inside_bottom_right_is_inside()
    H.isTrue(Widgets.hit(29, 29, 10, 10, 20, 20))
end

function T.hit_outside_left_or_above_is_false()
    H.isFalse(Widgets.hit(9, 15, 10, 10, 20, 20))
    H.isFalse(Widgets.hit(15, 9, 10, 10, 20, 20))
end

-- ---------------------------------------------------------------------------
-- Text metrics (headless fallback path)

function T.textWidth_and_textHeight_have_headless_fallbacks()
    local w = Widgets.textWidth("hello", "body")
    local h = Widgets.textHeight("body")
    H.isTrue(type(w) == "number" and w > 0, "textWidth must return a positive number headless")
    H.isTrue(type(h) == "number" and h > 0, "textHeight must return a positive number headless")
end

-- ---------------------------------------------------------------------------
-- Slider value math

function T.slider_value_clamps_to_min_and_max()
    H.equal(Widgets.clampSliderValue(-5, 0, 10), 0)
    H.equal(Widgets.clampSliderValue(15, 0, 10), 10)
    H.equal(Widgets.clampSliderValue(5, 0, 10), 5)
end

function T.slider_value_snaps_to_step()
    H.equal(Widgets.clampSliderValue(4.6, 0, 10, 1), 5)
    H.equal(Widgets.clampSliderValue(4.4, 0, 10, 1), 4)
    H.near(Widgets.clampSliderValue(0.24, 0, 1, 0.1), 0.2, 1e-9)
end

function T.slider_value_from_x_maps_track_position_and_clamps()
    H.equal(Widgets.sliderValueFromX(0, 0, 100, 0, 10, 1), 0)
    H.equal(Widgets.sliderValueFromX(100, 0, 100, 0, 10, 1), 10)
    H.equal(Widgets.sliderValueFromX(50, 0, 100, 0, 10, 1), 5)
    H.equal(Widgets.sliderValueFromX(-20, 0, 100, 0, 10, 1), 0, "pixels left of the track clamp to min")
    H.equal(Widgets.sliderValueFromX(500, 0, 100, 0, 10, 1), 10, "pixels right of the track clamp to max")
end

-- ---------------------------------------------------------------------------
-- Drawing must never throw headless -- guard-and-no-op, not error.

function T.widgets_drawing_is_safe_headless()
    H.succeeds(function() Widgets.panel(0, 0, 100, 40, { variant = "raised" }) end)
    H.succeeds(function() Widgets.panel(0, 0, 100, 40, { variant = "sunken" }) end)
    H.succeeds(function() Widgets.button(0, 0, 100, 20, "OK", { state = "disabled" }) end)
    H.succeeds(function() Widgets.label(0, 0, 100, "hi", { align = "center" }) end)
    H.succeeds(function() Widgets.bar(0, 0, 100, 10, 0.5, { glow = true }) end)
    H.succeeds(function() Widgets.slider(0, 0, 100, 5, 0, 10) end)
    H.succeeds(function() Widgets.tabs(0, 0, 100, { "A", "B" }, 1) end)
    H.succeeds(function() Widgets.card(0, 0, 60, 80, { rarity = "epic" }) end)
end

-- ---------------------------------------------------------------------------
-- MenuBuilder: fluent API

function T.menuBuilder_add_methods_return_self_for_chaining()
    local menu = MenuBuilder.new("Test")
    local a = menu:addButton("A", function() end)
    local b = a:addToggle("B", true, function() end)
    local c = b:addSlider("C", 1, 0, 10, 1, function() end)
    local d = c:addLabel("D")
    local e = d:addSeparator()
    local f = e:addSubmenu("F", nil, function() end)

    H.isTrue(a == menu and b == menu and c == menu and d == menu and e == menu and f == menu,
        "every add* call must return the same builder")
    H.equal(#menu.items, 6)
end

-- ---------------------------------------------------------------------------
-- MenuBuilder: calculateHeight must charge separators their real height, not
-- a full item row (this was the shopState "Return to Game off-screen" bug).

function T.menuBuilder_calculateHeight_counts_separators_at_real_height()
    local menu = MenuBuilder.new("", { padding = 0, itemSpacing = 0, separatorHeight = 3, itemHeight = 20 })
    menu:addButton("A", function() end)
    menu:addSeparator()
    menu:addButton("B", function() end)

    H.equal(menu:calculateHeight(), 43, "expected 20 + 3 + 20 with zero padding/spacing")
end

function T.menuBuilder_calculateHeight_includes_padding_spacing_and_title()
    local menu = MenuBuilder.new("Title", { padding = 5, itemSpacing = 2, separatorHeight = 4, itemHeight = 10 })
    menu:addButton("A", function() end)
    menu:addSeparator()
    menu:addButton("B", function() end)

    local titleHeight = Theme.fontSizes.heading + 5
    local content = 10 + 4 + 10 + 2 * 2 -- three items, two gaps
    local expected = 5 * 2 + content + titleHeight
    H.equal(menu:calculateHeight(), expected)
end

function T.menuBuilder_calculateHeight_never_shrinks_content_below_a_single_item()
    -- A viewport too small to fit even one item must still show one item
    -- rather than reporting zero height.
    local menu = MenuBuilder.new("", { viewportHeight = 1, itemHeight = 50, padding = 0, itemSpacing = 0 })
    menu:addButton("Only", function() end)
    H.equal(menu:calculateHeight(), 50)
end

-- ---------------------------------------------------------------------------
-- MenuBuilder: selection skips non-interactive rows and never hangs.

function T.menuBuilder_getNextSelectableIndex_skips_labels_separators_and_disabled()
    local menu = MenuBuilder.new("Nav")
    menu:addLabel("heading")               -- 1: not selectable
    menu:addSeparator()                    -- 2: not selectable
    menu:addButton("Disabled", nil, false) -- 3: not selectable
    menu:addButton("First", nil, true)     -- 4: selectable
    menu:addButton("Second", nil, true)    -- 5: selectable

    H.equal(menu:getNextSelectableIndex(1, 1), 4, "should skip label, separator and disabled button")
    H.equal(menu:getNextSelectableIndex(4, 1), 5)
end

function T.menuBuilder_getNextSelectableIndex_does_not_infinite_loop_when_nothing_selectable()
    local menu = MenuBuilder.new("Nav")
    menu:addLabel("only a label")
    menu:addSeparator()

    local result = H.succeeds(function() return menu:getNextSelectableIndex(1, 1) end,
        "must terminate even with zero selectable items")
    H.equal(result, 1, "index must not move when nothing is selectable")
end

function T.menuBuilder_getNextSelectableIndex_handles_empty_menu()
    local menu = MenuBuilder.new("Empty")
    local result = H.succeeds(function() return menu:getNextSelectableIndex(1, 1) end)
    H.equal(result, 1)
end

-- ---------------------------------------------------------------------------
-- MenuBuilder: draw/update/input must be safe with no graphics context.

function T.menuBuilder_draw_and_keyboard_input_are_safe_headless()
    local menu = MenuBuilder.new("Shop")
    menu:addButton("Buy", function() end)
    menu:addSeparator()
    menu:addToggle("Mute", false, function() end)
    menu:addSlider("Volume", 5, 0, 10, 1, function() end)

    H.succeeds(function() menu:update(1 / 60) end)
    H.succeeds(function() menu:draw() end)
    H.succeeds(function() menu:keypressed("down") end)
    H.succeeds(function() menu:keypressed("left") end)
    H.succeeds(function() menu:keypressed("right") end)
    H.succeeds(function() menu:keypressed("return") end)
    H.succeeds(function() menu:keypressed("escape") end)
    H.succeeds(function() menu:mousemoved(0, 0, 0, 0) end)
    H.succeeds(function() menu:mousepressed(0, 0, 1) end)
    H.succeeds(function() menu:mousereleased(0, 0, 1) end)
end

-- ---------------------------------------------------------------------------
-- MenuBuilder: mouse support (hover/click/drag). computeLayout is pure logic
-- (no love.graphics calls), so this is fully testable headless.

function T.menuBuilder_mouse_drag_updates_slider_value_and_calls_back()
    local captured = nil
    local menu = MenuBuilder.new("Settings", { width = 300 })
    menu:addSlider("Volume", 5, 0, 10, 1, function(v) captured = v end)

    local layout = menu:computeLayout()
    local rect = layout.rects[1]
    local trackX, trackY, trackW = menu:sliderTrackRect(rect)

    menu:mousepressed(trackX, trackY, 1)
    H.equal(menu.items[1].value, 0, "click at track start should jump to min")
    H.equal(captured, 0)
    H.isTrue(menu.items[1].dragActive)

    menu:mousemoved(trackX + trackW, trackY)
    H.equal(menu.items[1].value, 10, "drag to track end should reach max")
    H.equal(captured, 10)

    menu:mousereleased(trackX + trackW, trackY, 1)
    H.isFalse(menu.items[1].dragActive, "release must end the drag")
end

function T.menuBuilder_mouse_click_triggers_button_on_release_over_same_item()
    local clicked = false
    local menu = MenuBuilder.new("Menu", { width = 300 })
    menu:addButton("Go", function() clicked = true end)

    local layout = menu:computeLayout()
    local rect = layout.rects[1]
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2

    menu:mousepressed(cx, cy, 1)
    H.isFalse(clicked, "callback must not fire on press")

    menu:mousereleased(cx, cy, 1)
    H.isTrue(clicked, "callback must fire on release over the same button")
end

function T.menuBuilder_mouse_click_does_not_trigger_when_released_elsewhere()
    local clicked = false
    local menu = MenuBuilder.new("Menu", { width = 300 })
    menu:addButton("Go", function() clicked = true end)

    local layout = menu:computeLayout()
    local rect = layout.rects[1]
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2

    menu:mousepressed(cx, cy, 1)
    menu:mousereleased(-1000, -1000, 1)
    H.isFalse(clicked, "callback must not fire when the release lands off the button")
end

function T.menuBuilder_disabled_button_ignores_mouse_click()
    local clicked = false
    local menu = MenuBuilder.new("Menu", { width = 300 })
    menu:addButton("Go", function() clicked = true end, false)

    local layout = menu:computeLayout()
    -- A disabled item still occupies a rect (it's the only item) but must not
    -- be interactive.
    H.equal(#layout.rects, 1)
    local rect = layout.rects[1]
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2

    menu:mousepressed(cx, cy, 1)
    menu:mousereleased(cx, cy, 1)
    H.isFalse(clicked, "disabled buttons must not respond to mouse clicks")
end

return T
