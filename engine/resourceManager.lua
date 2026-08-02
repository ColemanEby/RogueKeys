-- engine/resourceManager.lua
-- Centralized asset management system for sprites, fonts, sounds, etc.
--
-- This module is required by tests/run.lua's suite discovery indirectly (states
-- and modules that use it get required in headless test runs too), so every
-- graphics/audio-touching function must guard itself and return nil instead of
-- throwing when there is no usable love.graphics/love.audio context. Only pure
-- lookups (cache keys, path bookkeeping) are expected to actually be exercised
-- by tests.

local ResourceManager = {
    sprites = {},
    fonts = {},
    fontPaths = {}, -- name -> on-disk path, so a font can be re-rendered at a new size
    sounds = {},
    quads = {},
    data = {}
}

local IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp"}
local FONT_EXTENSIONS = {".ttf", ".otf"}
local SOUND_EXTENSIONS = {".wav", ".mp3", ".ogg"}

local DEFAULT_FONT_SIZE = 14
local DEFAULT_NINEPATCH_INSET = 4
local PLACEHOLDER_SIZE = 16
local PLACEHOLDER_CHECKER = 4

local function graphicsReady()
    return not _G.HEADLESS and love.graphics ~= nil and type(love.graphics.newImage) == "function"
end

local function audioReady()
    return not _G.HEADLESS and love.audio ~= nil and type(love.audio.newSource) == "function"
end

-- love.image works headless (it does no GPU work), which is what lets the
-- missing-asset placeholder exist even under `--test`.
local function imageReady()
    return love.image ~= nil and type(love.image.newImageData) == "function"
end

local function debugPrint(msg)
    if _G.DEBUG_MODE then print(msg) end
end

-- Non-integer font sizes (e.g. `18 * scale`) would otherwise fragment the
-- cache into keys like "default_16.2" that never get reused.
local function roundSize(size)
    size = size or DEFAULT_FONT_SIZE
    return math.floor(size + 0.5)
end

-- Pure font cache key: rounds size to an integer so e.g. `18 * scale` calls
-- don't fragment the cache into "default_16.2", "default_16.3", ... This is
-- deliberately a plain method (no graphics touched) so it stays testable
-- headless.
function ResourceManager:fontCacheKey(name, size)
    return (name or "default") .. "_" .. roundSize(size)
end

-- Check if a file has a specific extension
local function hasExtension(filename, extensions)
    local ext = string.lower(string.match(filename, "%.%w+$") or "")
    for _, v in ipairs(extensions) do
        if ext == v then return true end
    end
    return false
end

-- Load a single image
function ResourceManager:loadSprite(name, path)
    if self.sprites[name] then return self.sprites[name] end
    if not graphicsReady() then return nil end

    local success, sprite = pcall(love.graphics.newImage, path)
    if success then
        sprite:setFilter("nearest", "nearest")
        self.sprites[name] = sprite
        debugPrint("ResourceManager: Loaded sprite '" .. name .. "' from " .. path)
    else
        debugPrint("ResourceManager: Failed to load sprite '" .. name .. "': " .. tostring(sprite))
    end
    return self.sprites[name]
end

-- Load a spritesheet and cut it into individual quads, keyed "name_row_col".
function ResourceManager:loadSpritesheet(name, path, quadWidth, quadHeight)
    if not graphicsReady() then return nil end

    local sprite = self:loadSprite(name .. "_sheet", path)
    if not sprite then return nil end

    local quads = {}
    local spriteWidth, spriteHeight = sprite:getDimensions()
    local rows = math.floor(spriteHeight / quadHeight)
    local cols = math.floor(spriteWidth / quadWidth)

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local quadName = name .. "_" .. row .. "_" .. col
            local quad = love.graphics.newQuad(
                    col * quadWidth, row * quadHeight,
                    quadWidth, quadHeight,
                    spriteWidth, spriteHeight
            )
            quads[quadName] = quad
            self.quads[quadName] = quad
            self.sprites[quadName] = {
                texture = sprite,
                quad = quad,
                width = quadWidth,
                height = quadHeight
            }
        end
    end

    return quads
end

-- Get a standalone quad registered via loadSpritesheet.
function ResourceManager:getQuad(name)
    return self.quads[name]
end

-- Load a font with optional fallback. `path` is remembered per `name` so a
-- later request for the same name at a different size can re-render from the
-- real file instead of silently reusing whatever size happened to load first.
function ResourceManager:loadFont(name, path, size)
    size = roundSize(size)
    local fontKey = self:fontCacheKey(name, size)

    if path then self.fontPaths[name] = path end
    if self.fonts[fontKey] then return self.fonts[fontKey] end
    if not graphicsReady() then return nil end

    local font
    if path then
        local success, result = pcall(love.graphics.newFont, path, size)
        if success then
            font = result
            debugPrint("ResourceManager: Loaded font '" .. name .. "' size " .. size .. " from " .. path)
        else
            debugPrint("ResourceManager: Failed to load font '" .. name .. "': " .. tostring(result))
        end
    end

    if not font then
        font = love.graphics.newFont(size)
    end

    font:setFilter("nearest", "nearest")
    self.fonts[fontKey] = font
    return font
end

-- Load a sound effect or music track. kind is "sfx" (static, default) or
-- "music" (streamed, since tracks are long and shouldn't fully decode).
function ResourceManager:loadSound(name, path, kind)
    kind = (kind == "music") and "music" or "sfx"

    local existing = self.sounds[name]
    if existing then return existing.source end
    if not audioReady() then return nil end

    local sourceType = (kind == "music") and "stream" or "static"
    local success, source = pcall(love.audio.newSource, path, sourceType)
    if success then
        self.sounds[name] = { source = source, kind = kind, path = path }
        debugPrint("ResourceManager: Loaded " .. kind .. " '" .. name .. "' from " .. path)
        return source
    else
        debugPrint("ResourceManager: Failed to load sound '" .. name .. "': " .. tostring(source))
        return nil
    end
end

-- Get a sound Source by name.
function ResourceManager:getSound(name)
    local entry = self.sounds[name]
    return entry and entry.source or nil
end

-- Get the category ("sfx"/"music") a loaded sound was registered under.
function ResourceManager:getSoundKind(name)
    local entry = self.sounds[name]
    return entry and entry.kind or nil
end

-- Load all assets from a directory with subdirectories.
--
-- The recursion is bounded three ways. A fused build merges the source and
-- save directories into one virtual filesystem, where an unguarded walk can
-- recurse forever -- that showed up as "ERROR initializing ResourceManager:
-- stack overflow" in the packaged .exe while running fine from source.
local MAX_SCAN_DEPTH = 8

function ResourceManager:loadDirectory(baseDir)
    local visited = {}

    local function scanDirectory(dir, depth)
        if depth > MAX_SCAN_DEPTH then
            debugPrint("ResourceManager: max scan depth reached at " .. dir)
            return
        end
        if visited[dir] then return end
        visited[dir] = true

        local items = love.filesystem.getDirectoryItems(dir)
        for _, item in ipairs(items) do
            -- "." and ".." resolve back into the tree being walked.
            if item ~= "." and item ~= ".." then
                local path = dir .. "/" .. item
                local info = love.filesystem.getInfo(path)

                if info and info.type == "file" then
                    -- Load based on file extension
                    if hasExtension(item, IMAGE_EXTENSIONS) then
                        local name = string.gsub(item, "%.%w+$", "")
                        self:loadSprite(name, path)
                    elseif hasExtension(item, SOUND_EXTENSIONS) then
                        local name = string.gsub(item, "%.%w+$", "")
                        self:loadSound(name, path, "sfx")
                    elseif hasExtension(item, FONT_EXTENSIONS) then
                        -- Only preload default size, others loaded on demand
                        local name = string.gsub(item, "%.%w+$", "")
                        self:loadFont(name, path, DEFAULT_FONT_SIZE)
                    end
                elseif info and info.type == "directory" then
                    scanDirectory(path, depth + 1)
                end
            end
        end
    end

    if love.filesystem.getInfo(baseDir) then
        scanDirectory(baseDir, 1)
    else
        debugPrint("ResourceManager: Directory not found: " .. baseDir)
    end
end

-- Build (and cache) the magenta/black checkerboard used to flag a missing
-- asset. Uses love.image, not love.graphics, so it exists even headless.
function ResourceManager:getPlaceholderImageData()
    if self.placeholderImageData then return self.placeholderImageData end
    if not imageReady() then return nil end

    local success, imageData = pcall(love.image.newImageData, PLACEHOLDER_SIZE, PLACEHOLDER_SIZE)
    if not success then return nil end

    for y = 0, PLACEHOLDER_SIZE - 1 do
        for x = 0, PLACEHOLDER_SIZE - 1 do
            local checker = (math.floor(x / PLACEHOLDER_CHECKER) + math.floor(y / PLACEHOLDER_CHECKER)) % 2 == 0
            if checker then
                imageData:setPixel(x, y, 1, 0, 1, 1) -- magenta
            else
                imageData:setPixel(x, y, 0, 0, 0, 1) -- black
            end
        end
    end

    self.placeholderImageData = imageData
    return imageData
end

-- Drawable placeholder when a graphics context exists; otherwise the raw
-- ImageData, which is still enough for headless code to see "not nil" and
-- inspect dimensions without a GPU.
function ResourceManager:getPlaceholderSprite()
    if self.placeholderImage then return self.placeholderImage end

    local imageData = self:getPlaceholderImageData()
    if not imageData then return nil end

    if graphicsReady() then
        local success, image = pcall(love.graphics.newImage, imageData)
        if success then
            image:setFilter("nearest", "nearest")
            self.placeholderImage = image
            return image
        end
    end

    return imageData
end

-- Get a sprite by name. Unknown names return the loud placeholder rather than
-- nil -- a missing asset should be obvious on screen, not a silent no-draw
-- that every call site has to remember to guard against.
function ResourceManager:getSprite(name)
    local sprite = self.sprites[name]
    if sprite then return sprite end
    return self:getPlaceholderSprite()
end

-- Get a sprite by name without the placeholder fallback, for callers that
-- need to tell "not loaded" apart from "loaded".
function ResourceManager:getSpriteOrNil(name)
    return self.sprites[name]
end

-- Get a font by name and size, rounding size to an integer cache key.
function ResourceManager:getFont(name, size)
    name = name or "default"
    size = roundSize(size)
    local fontKey = self:fontCacheKey(name, size)

    if self.fonts[fontKey] then return self.fonts[fontKey] end
    if not graphicsReady() then return nil end

    local path = self.fontPaths[name]
    if path then
        return self:loadFont(name, path, size)
    end

    -- No on-disk font is known for this name (e.g. "default", which is only
    -- ever registered against love.graphics.getFont()). Synthesize a font at
    -- the requested size instead of silently handing back whatever size
    -- happened to be cached first.
    local success, font = pcall(love.graphics.newFont, size)
    if not success then return love.graphics.getFont() end

    font:setFilter("nearest", "nearest")
    self.fonts[fontKey] = font
    return font
end

-- Build a nine-patch drawable from a border inset. Returns nil (rather than
-- throwing) when the atlas doesn't exist, so callers can fall back to
-- procedural panel drawing.
function ResourceManager:getNinePatch(name, inset)
    if not graphicsReady() then return nil end
    inset = inset or DEFAULT_NINEPATCH_INSET

    local image = self.sprites[name]
    if not image or type(image.getDimensions) ~= "function" then
        local path = "resources/sprites/" .. name .. ".png"
        if not love.filesystem.getInfo(path) then return nil end
        image = self:loadSprite(name, path)
    end
    if not image then return nil end

    local w, h = image:getDimensions()
    if w <= inset * 2 or h <= inset * 2 then return nil end

    local midW, midH = w - inset * 2, h - inset * 2
    local function q(x, y, qw, qh)
        return love.graphics.newQuad(x, y, qw, qh, w, h)
    end

    local patch = {
        image = image,
        inset = inset,
        srcWidth = w,
        srcHeight = h,
        quads = {
            topLeft     = q(0, 0, inset, inset),
            top         = q(inset, 0, midW, inset),
            topRight    = q(w - inset, 0, inset, inset),
            left        = q(0, inset, inset, midH),
            center      = q(inset, inset, midW, midH),
            right       = q(w - inset, inset, inset, midH),
            bottomLeft  = q(0, h - inset, inset, inset),
            bottom      = q(inset, h - inset, midW, inset),
            bottomRight = q(w - inset, h - inset, inset, inset),
        },
    }

    -- Draw the patch stretched to (w, h) at (x, y). Corners stay 1:1; edges
    -- and the center stretch to fill.
    function patch:draw(x, y, w2, h2)
        local i = self.inset
        w2 = math.max(w2, i * 2)
        h2 = math.max(h2, i * 2)

        local sx = (w2 - i * 2) / (self.srcWidth - i * 2)
        local sy = (h2 - i * 2) / (self.srcHeight - i * 2)

        love.graphics.draw(self.image, self.quads.topLeft, x, y)
        love.graphics.draw(self.image, self.quads.top, x + i, y, 0, sx, 1)
        love.graphics.draw(self.image, self.quads.topRight, x + w2 - i, y)

        love.graphics.draw(self.image, self.quads.left, x, y + i, 0, 1, sy)
        love.graphics.draw(self.image, self.quads.center, x + i, y + i, 0, sx, sy)
        love.graphics.draw(self.image, self.quads.right, x + w2 - i, y + i, 0, 1, sy)

        love.graphics.draw(self.image, self.quads.bottomLeft, x, y + h2 - i)
        love.graphics.draw(self.image, self.quads.bottom, x + i, y + h2 - i, 0, sx, 1)
        love.graphics.draw(self.image, self.quads.bottomRight, x + w2 - i, y + h2 - i)
    end

    return patch
end

-- Store arbitrary data
function ResourceManager:storeData(name, data)
    self.data[name] = data
end

-- Get stored data
function ResourceManager:getData(name)
    return self.data[name]
end

-- Initialize with default assets
function ResourceManager:init()
    if not graphicsReady() then return end

    -- Create resources directories if they don't exist
    local directories = {"resources", "resources/sprites", "resources/fonts", "resources/sounds"}
    for _, dir in ipairs(directories) do
        if not love.filesystem.getInfo(dir) then
            love.filesystem.createDirectory(dir)
        end
    end

    -- Load all assets from the resources directory
    self:loadDirectory("resources")

    -- LOVE's built-in default font has no on-disk path, so fontPaths
    -- intentionally has no "default" entry -- getFont() falls through to a
    -- freshly rendered font at whatever size is asked for.
    local builtinFont = love.graphics.getFont()
    builtinFont:setFilter("nearest", "nearest")
    self.fonts["default_" .. DEFAULT_FONT_SIZE] = builtinFont

    -- Preload every size the UI actually uses so no frame pays for font
    -- rasterization mid-draw. Sizes come from Theme, never duplicated here.
    local success, Theme = pcall(require, "modules/ui/theme")
    if success and Theme.fontSizes then
        for _, size in pairs(Theme.fontSizes) do
            self:getFont("default", size)
        end
    end

    -- Explicitly load keyboard sprites (even if they're not in the standard resources folder)
    local keyboardSpritePath = "resources/sprites/keyboard_letters_and_symbols.png"
    if love.filesystem.getInfo(keyboardSpritePath) then
        self:loadSprite("keyboard_sprites", keyboardSpritePath)
    else
        -- Try alternate locations
        local alternatePaths = {
            "assets/keyboard_letters_and_symbols.png",
            "data/keyboard_letters_and_symbols.png",
            "keyboard_letters_and_symbols.png"
        }

        for _, path in ipairs(alternatePaths) do
            if love.filesystem.getInfo(path) then
                self:loadSprite("keyboard_sprites", path)
                debugPrint("ResourceManager: Loaded keyboard sprites from alternate path: " .. path)
                break
            end
        end
    end
end

return ResourceManager
