-- engine/resourceManager.lua
-- Centralized asset management system for sprites, fonts, sounds, etc.

local ResourceManager = {
    sprites = {},
    fonts = {},
    sounds = {},
    data = {}
}

local IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp"}
local FONT_EXTENSIONS = {".ttf", ".otf"}
local SOUND_EXTENSIONS = {".wav", ".mp3", ".ogg"}

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
    if not self.sprites[name] then
        local success, sprite = pcall(love.graphics.newImage, path)
        if success then
            self.sprites[name] = sprite
            print("ResourceManager: Loaded sprite '" .. name .. "' from " .. path)
        else
            print("ResourceManager: Failed to load sprite '" .. name .. "': " .. tostring(sprite))
        end
    end
    return self.sprites[name]
end

-- Load a spritesheet and cut it into individual quads
function ResourceManager:loadSpritesheet(name, path, quadWidth, quadHeight)
    local sprite = self:loadSprite(name .. "_sheet", path)
    if not sprite then return nil end

    local quads = {}
    local spriteWidth, spriteHeight = sprite:getDimensions()
    local rows = math.floor(spriteHeight / quadHeight)
    local cols = math.floor(spriteWidth / quadWidth)

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local quadName = name .. "_" .. row .. "_" .. col
            quads[quadName] = love.graphics.newQuad(
                    col * quadWidth, row * quadHeight,
                    quadWidth, quadHeight,
                    spriteWidth, spriteHeight
            )
            self.sprites[quadName] = {
                texture = sprite,
                quad = quads[quadName],
                width = quadWidth,
                height = quadHeight
            }
        end
    end

    return quads
end

-- Load a font with optional fallback
function ResourceManager:loadFont(name, path, size)
    local fontKey = name .. "_" .. tostring(size)
    if not self.fonts[fontKey] then
        local success, font = pcall(love.graphics.newFont, path, size)
        if success then
            self.fonts[fontKey] = font
            print("ResourceManager: Loaded font '" .. name .. "' size " .. size .. " from " .. path)
        else
            print("ResourceManager: Failed to load font '" .. name .. "': " .. tostring(font))
            -- Fallback to default font
            self.fonts[fontKey] = love.graphics.newFont(size)
        end
    end
    return self.fonts[fontKey]
end

-- Load a sound effect
function ResourceManager:loadSound(name, path)
    if not self.sounds[name] then
        local success, sound = pcall(love.audio.newSource, path, "static")
        if success then
            self.sounds[name] = sound
            print("ResourceManager: Loaded sound '" .. name .. "' from " .. path)
        else
            print("ResourceManager: Failed to load sound '" .. name .. "': " .. tostring(sound))
        end
    end
    return self.sounds[name]
end

-- Load all assets from a directory with subdirectories
function ResourceManager:loadDirectory(baseDir)
    local function scanDirectory(dir)
        local items = love.filesystem.getDirectoryItems(dir)
        for _, item in ipairs(items) do
            local path = dir .. "/" .. item
            local info = love.filesystem.getInfo(path)

            if info.type == "file" then
                -- Load based on file extension
                if hasExtension(item, IMAGE_EXTENSIONS) then
                    local name = string.gsub(item, "%.%w+$", "")
                    self:loadSprite(name, path)
                elseif hasExtension(item, SOUND_EXTENSIONS) then
                    local name = string.gsub(item, "%.%w+$", "")
                    self:loadSound(name, path)
                elseif hasExtension(item, FONT_EXTENSIONS) then
                    -- Only preload default size, others loaded on demand
                    local name = string.gsub(item, "%.%w+$", "")
                    self:loadFont(name, path, 14)
                end
            elseif info.type == "directory" then
                scanDirectory(path)
            end
        end
    end

    if love.filesystem.getInfo(baseDir) then
        scanDirectory(baseDir)
    else
        print("ResourceManager: Directory not found: " .. baseDir)
    end
end

-- Get a sprite by name
function ResourceManager:getSprite(name)
    return self.sprites[name]
end

-- Get a font by name and size
function ResourceManager:getFont(name, size)
    size = size or 14
    local fontKey = name .. "_" .. tostring(size)

    -- Load the font if it doesn't exist at this size
    if not self.fonts[fontKey] and self.fonts[name .. "_14"] then
        local fontPath = self.fonts[name .. "_14"].__fontPath
        if fontPath then
            return self:loadFont(name, fontPath, size)
        end
    end

    return self.fonts[fontKey] or love.graphics.getFont()
end

-- Get a sound by name
function ResourceManager:getSound(name)
    return self.sounds[name]
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
    -- Create resources directories if they don't exist
    local directories = {"resources", "resources/sprites", "resources/fonts", "resources/sounds"}
    for _, dir in ipairs(directories) do
        if not love.filesystem.getInfo(dir) then
            love.filesystem.createDirectory(dir)
        end
    end

    -- Load all assets from the resources directory
    self:loadDirectory("resources")

    -- Store default font
    self.fonts["default_14"] = love.graphics.getFont()

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
                print("ResourceManager: Loaded keyboard sprites from alternate path: " .. path)
                break
            end
        end
    end
end

return ResourceManager