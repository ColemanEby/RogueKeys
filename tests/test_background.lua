-- tests/test_background.lua
-- Deterministic and headless coverage for the procedural menu starfield.

local H = require("tests/helpers")
local Background = require("modules/ui/background")
local Screen = require("modules/ui/screen")
local Theme = require("modules/ui/theme")

local T = {}

function T.same_seed_reproduces_identical_star_coordinates()
    local first = Background.generate(8675309)
    local second = Background.generate(8675309)

    H.equal(first[1].x, second[1].x)
    H.equal(first[1].y, second[1].y)
    H.deepEqual(first, second, "all generated star properties must be reproducible")
end

function T.different_seeds_produce_different_star_fields()
    local first = Background.generate(101)
    local second = Background.generate(202)

    local coordinatesDiffer = first[1].x ~= second[1].x or first[1].y ~= second[1].y
    H.isTrue(coordinatesDiffer, "different seeds must change actual star coordinates")
end

function T.claimed_count_and_canvas_bounds_match_generated_field()
    local stars = Background.generate(42)

    H.equal(#stars, Background.STAR_COUNT)
    for i, star in ipairs(stars) do
        H.isTrue(star.x >= 0 and star.x < Screen.WIDTH,
            "star " .. i .. " x coordinate must be inside the logical canvas")
        H.isTrue(star.y >= 0 and star.y < Screen.HEIGHT,
            "star " .. i .. " y coordinate must be inside the logical canvas")
    end
end

function T.every_draw_color_is_a_named_theme_palette_color()
    H.isTrue(Theme.palette[Background.BACKGROUND_COLOR] ~= nil,
        "background fill must name a Theme palette color")

    local stars = Background.generate(73)
    for i, star in ipairs(stars) do
        H.isTrue(Theme.palette[star.color] ~= nil,
            "star " .. i .. " must name a Theme palette color")
    end
end

function T.drawing_is_safe_headless()
    Background.regenerate(99)
    H.succeeds(function() Background.draw(1 / 60) end)
end

return T
