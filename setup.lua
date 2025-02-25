#!/usr/bin/env lua
-- setup.lua
-- Project initialization script for the Typing Trainer Roguelike
-- Run this script once to set up the proper directory structure

local directories = {
    -- Engine
    "engine",

    -- Modules
    "modules",
    "modules/keyboard",
    "modules/player",
    "modules/typing",
    "modules/ui",

    -- States
    "states",

    -- Resources
    "resources",
    "resources/sprites",
    "resources/fonts",
    "resources/sounds",

    -- Data
    "data",

    -- Save
    "save",

    -- Config
    "config"
}

-- Create directories
print("Creating directory structure...")
for _, dir in ipairs(directories) do
    os.execute("mkdir -p " .. dir)
    print("  Created: " .. dir)
end

-- Create a sample word list if it doesn't exist
if not io.open("data/words.txt", "r") then
    print("Creating sample word list...")
    local wordFile = io.open("data/words.txt", "w")
    if wordFile then
        -- Add some common words
        local sampleWords = {
            "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
            "hello", "world", "typing", "practice", "keyboard", "skills",
            "code", "program", "computer", "software", "development", "game",
            "love", "lua", "script", "function", "variable", "module", "state",
            "manager", "resource", "keyboard", "sprite", "animation", "player",
            "score", "level", "round", "menu", "shop", "upgrade", "money"
        }

        wordFile:write(table.concat(sampleWords, "\n"))
        wordFile:close()
        print("  Created sample word list with " .. #sampleWords .. " words")
    else
        print("  Error: Could not create word list file")
    end
end

-- Check for keyboard sprite sheet
local function checkFileExists(filename)
    local file = io.open(filename, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local keyboardSpriteLocations = {
    "resources/sprites/keyboard_letters_and_symbols.png",
    "assets/keyboard_letters_and_symbols.png",
    "keyboard_letters_and_symbols.png"
}

local spriteSheetFound = false
for _, loc in ipairs(keyboardSpriteLocations) do
    if checkFileExists(loc) then
        spriteSheetFound = true
        print("Found keyboard sprite sheet at: " .. loc)

        -- If it's not in the proper resources directory, suggest moving it
        if loc ~= "resources/sprites/keyboard_letters_and_symbols.png" then
            print("  Tip: You should move this file to resources/sprites/keyboard_letters_and_symbols.png")
        end

        break
    end
end

if not spriteSheetFound then
    print("WARNING: Keyboard sprite sheet not found. The game will fall back to shape-based rendering.")
    print("  For sprite-based keys, place the sprite sheet at: resources/sprites/keyboard_letters_and_symbols.png")
    print("  The expected sprite sheet is 128x224 pixels with 16x16 pixel keys arranged in a grid.")
end

print("\nSetup complete!")
print("Run your game with the LÖVE framework using: love .")