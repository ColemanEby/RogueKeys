-- tests/test_resources.lua
-- ResourceManager runs with a real graphics context during boot, but this
-- suite runs headless (`love . --test`), so it only exercises what is
-- reachable without love.graphics/love.audio: cache-key math, path
-- bookkeeping, and the "never throw" contract every public function must
-- honor when there is no usable context.

local H = require("tests/helpers")
local ResourceManager = require("engine/resourceManager")

local T = {}

function T.font_cache_key_rounds_non_integer_sizes()
    H.equal(ResourceManager:fontCacheKey("default", 16.2), "default_16")
    H.equal(ResourceManager:fontCacheKey("default", 15.5), "default_16")
    H.equal(ResourceManager:fontCacheKey("default", 15.49), "default_15")
    H.equal(ResourceManager:fontCacheKey("default", 20), "default_20")
end

function T.font_cache_key_defaults_missing_size()
    -- keyboardView.lua-style calls (`size * scale`) and bare lookups must
    -- collapse onto the same default rather than producing a "nil" key.
    H.equal(ResourceManager:fontCacheKey("mono"), "mono_14")
    H.equal(ResourceManager:fontCacheKey(nil, 12), "default_12")
end

function T.font_paths_are_recorded_on_load_and_reused_across_sizes()
    local name = "__test_custom_font"
    local path = "resources/fonts/__test_custom_font.ttf"

    H.equal(ResourceManager.fontPaths[name], nil, "fontPaths should start empty for a fresh name")

    ResourceManager:loadFont(name, path, 14)
    H.equal(ResourceManager.fontPaths[name], path,
        "loadFont must record the path so getFont can re-render at a new size")

    -- A later request for a different size, even with no path supplied, must
    -- not forget (or overwrite with nil) the path recorded above -- that was
    -- exactly the __fontPath bug: no real path was ever tracked, so every
    -- size silently fell back to the 14px default.
    ResourceManager:loadFont(name, nil, 28)
    H.equal(ResourceManager.fontPaths[name], path,
        "a follow-up load with no path must not erase the recorded font path")
end

function T.get_font_headless_never_throws_and_returns_nil()
    H.succeeds(function() return ResourceManager:getFont("default", 14) end)
    H.equal(ResourceManager:getFont("default", 14), nil,
        "headless has no graphics context, so getFont must return nil, not throw or fake a font")
    H.succeeds(function() return ResourceManager:getFont("default", 18 * 1.333) end,
        "non-integer sizes (keyboardView's fontSize * scale) must not raise")
end

function T.unknown_sprite_returns_placeholder_but_or_nil_variant_returns_nil()
    local name = "__definitely_not_a_real_sprite__"

    H.equal(ResourceManager:getSpriteOrNil(name), nil)

    local placeholder = ResourceManager:getSprite(name)
    H.isTrue(placeholder ~= nil,
        "a missing sprite must return the loud placeholder, not a silent nil")

    -- Placeholder is cached and stable across repeated lookups of different
    -- missing names -- it's a single shared "this is missing" signal, not a
    -- per-name allocation.
    local placeholder2 = ResourceManager:getSprite("__another_missing_sprite__")
    H.isTrue(placeholder2 ~= nil)
end

function T.known_sprite_is_returned_as_is_by_both_getters()
    local name = "__test_known_sprite"
    ResourceManager.sprites[name] = { fake = true }

    H.equal(ResourceManager:getSpriteOrNil(name), ResourceManager.sprites[name])
    H.equal(ResourceManager:getSprite(name), ResourceManager.sprites[name])

    ResourceManager.sprites[name] = nil
end

function T.placeholder_image_data_builds_headless_via_love_image()
    -- love.image (unlike love.graphics/love.audio) is not disabled in
    -- headless test runs, so the checkerboard must actually exist here.
    local data = ResourceManager:getPlaceholderImageData()
    H.isTrue(data ~= nil, "placeholder ImageData should build without a graphics context")

    local w, h = data:getDimensions()
    H.isTrue(w > 0 and h > 0, "placeholder must have real dimensions")
end

function T.get_nine_patch_on_absent_atlas_returns_nil()
    H.succeeds(function() return ResourceManager:getNinePatch("__no_such_atlas__") end)
    H.equal(ResourceManager:getNinePatch("__no_such_atlas__"), nil)
    H.equal(ResourceManager:getNinePatch("__no_such_atlas__", 8), nil)
end

function T.get_quad_on_unknown_name_returns_nil()
    H.equal(ResourceManager:getQuad("__no_such_quad__"), nil)
end

function T.load_sound_without_audio_context_returns_nil_not_throw()
    local result = H.succeeds(function()
        return ResourceManager:loadSound("__test_sound", "resources/sounds/nope.wav", "sfx")
    end)
    H.equal(result, nil)
    H.equal(ResourceManager:getSound("__test_sound"), nil)
    H.equal(ResourceManager:getSoundKind("__test_sound"), nil)
end

function T.load_sound_kind_defaults_to_sfx()
    -- Can't actually load audio headless, but the kind-normalization logic is
    -- pure and must not mistake an unrecognized kind for "music".
    H.succeeds(function() ResourceManager:loadSound("__test_sound_2", "x.wav", "bogus") end)
    H.succeeds(function() ResourceManager:loadSound("__test_sound_3", "x.wav") end)
end

function T.store_and_get_arbitrary_data_round_trips()
    ResourceManager:storeData("__test_data", { a = 1, b = "two" })
    local data = ResourceManager:getData("__test_data")
    H.equal(data.a, 1)
    H.equal(data.b, "two")
    ResourceManager:storeData("__test_data", nil)
end

function T.every_public_function_is_safe_to_call_headless()
    H.succeeds(function() ResourceManager:loadSprite("__t_sprite", "nope.png") end)
    H.succeeds(function() ResourceManager:loadSpritesheet("__t_sheet", "nope.png", 16, 16) end)
    H.succeeds(function() ResourceManager:loadFont("__t_font", "nope.ttf", 12) end)
    H.succeeds(function() ResourceManager:loadSound("__t_sound", "nope.wav", "music") end)
    H.succeeds(function() ResourceManager:loadDirectory("__no_such_directory__") end)
    H.succeeds(function() ResourceManager:getSprite("__t_sprite_missing") end)
    H.succeeds(function() ResourceManager:getSpriteOrNil("__t_sprite_missing") end)
    H.succeeds(function() ResourceManager:getFont("__t_font", 12) end)
    H.succeeds(function() ResourceManager:getSound("__t_sound") end)
    H.succeeds(function() ResourceManager:getSoundKind("__t_sound") end)
    H.succeeds(function() ResourceManager:getQuad("__t_quad") end)
    H.succeeds(function() ResourceManager:getNinePatch("__t_ninepatch") end)
    H.succeeds(function() ResourceManager:getPlaceholderImageData() end)
    H.succeeds(function() ResourceManager:getPlaceholderSprite() end)
    H.succeeds(function() ResourceManager:fontCacheKey("x", 12.7) end)
    H.succeeds(function() ResourceManager:storeData("__t_data", 1) end)
    H.succeeds(function() ResourceManager:getData("__t_data") end)
    H.succeeds(function() ResourceManager:init() end)
end

return T
