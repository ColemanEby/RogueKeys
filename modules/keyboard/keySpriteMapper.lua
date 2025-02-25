-- modules/keyboard/keySpriteMapper.lua
-- Key sprite mapping and handling for keyboard visualization

local ResourceManager = require("engine/resourceManager")

local KeySpriteMapper = {}
KeySpriteMapper.__index = KeySpriteMapper

-- Sprite sheet constants
local SPRITE_WIDTH = 16
local SPRITE_HEIGHT = 16
local SHEET_COLUMNS = 8
local SHEET_ROWS = 14

-- Create a new key sprite mapper instance
function KeySpriteMapper.new()
    local self = setmetatable({}, KeySpriteMapper)
    self.mapping = {}
    self.sheet = nil
    self.loaded = false
    return self
end

-- Load the sprite sheet and create mappings
function KeySpriteMapper:load()
    if self.loaded then return true end

    -- Get sprite sheet from resource manager (should be loaded during initialization)
    self.sheet = ResourceManager:getSprite("keyboard_sprites")

    if not self.sheet then
        print("KeySpriteMapper: Failed to load keyboard sprite sheet")
        return false
    end

    local sheetWidth, sheetHeight = self.sheet:getDimensions()

    -- Helper function to create a quad for a given column and row (1-indexed)
    local function createQuad(col, row)
        return love.graphics.newQuad(
                (col - 1) * SPRITE_WIDTH,
                (row - 1) * SPRITE_HEIGHT,
                SPRITE_WIDTH,
                SPRITE_HEIGHT,
                sheetWidth,
                sheetHeight
        )
    end

    -- Build the key mapping table based on the provided structure
    self.mapping = {
        -- Light keys (normal)
        upArrowKey = createQuad(1, 1),
        downArrowKey = createQuad(2, 1),
        rightArrowKey = createQuad(3, 1),
        leftArrowKey = createQuad(4, 1),
        F1Key = createQuad(5, 1),
        F2Key = createQuad(6, 1),
        F3Key = createQuad(7, 1),
        F4Key = createQuad(8, 1),
        F5Key = createQuad(1, 2),
        F6Key = createQuad(2, 2),
        F7Key = createQuad(3, 2),
        F8Key = createQuad(4, 2),
        F9Key = createQuad(5, 2),
        F10Key = createQuad(6, 2),
        F11Key = createQuad(7, 2),
        F12Key = createQuad(8, 2),
        A_Key = createQuad(1, 3),
        B_Key = createQuad(2, 3),
        C_Key = createQuad(3, 3),
        D_Key = createQuad(4, 3),
        E_Key = createQuad(5, 3),
        F_Key = createQuad(6, 3),
        G_Key = createQuad(7, 3),
        H_Key = createQuad(8, 3),
        I_Key = createQuad(1, 4),
        J_Key = createQuad(2, 4),
        K_Key = createQuad(3, 4),
        L_Key = createQuad(4, 4),
        M_Key = createQuad(5, 4),
        N_Key = createQuad(6, 4),
        O_Key = createQuad(7, 4),
        P_Key = createQuad(8, 4),
        Q_Key = createQuad(1, 5),
        R_Key = createQuad(2, 5),
        S_Key = createQuad(3, 5),
        T_Key = createQuad(4, 5),
        U_Key = createQuad(5, 5),
        V_Key = createQuad(6, 5),
        W_Key = createQuad(7, 5),
        X_Key = createQuad(8, 5),
        Y_Key = createQuad(1, 6),
        Z_Key = createQuad(2, 6),
        PERIOD_Key = createQuad(3, 6),
        COMMA_Key = createQuad(4, 6),
        QUESTION_MARK_Key = createQuad(5, 6),
        FORWARD_SLASH_Key = createQuad(6, 6),
        BACK_SLASH_Key = createQuad(7, 6),
        SEMI_COLON_Key = createQuad(8, 6),
        APOSTROPHE_Key = createQuad(1, 7),
        RIGHT_BRACKET_Key = createQuad(2, 7),
        LEFT_BRACKET_Key = createQuad(3, 7),
        EQUALS_PLUS_Key = createQuad(4, 7),
        MINUS_Key = createQuad(5, 7),
        TILDA_Key = createQuad(6, 7),

        -- Dark keys (highlighted/upgraded)
        upArrowKey_DARK = createQuad(1, 8),
        downArrowKey_DARK = createQuad(2, 8),
        rightArrowKey_DARK = createQuad(3, 8),
        leftArrowKey_DARK = createQuad(4, 8),
        F1Key_DARK = createQuad(5, 8),
        F2Key_DARK = createQuad(6, 8),
        F3Key_DARK = createQuad(7, 8),
        F4Key_DARK = createQuad(8, 8),
        F5Key_DARK = createQuad(1, 9),
        F6Key_DARK = createQuad(2, 9),
        F7Key_DARK = createQuad(3, 9),
        F8Key_DARK = createQuad(4, 9),
        F9Key_DARK = createQuad(5, 9),
        F10Key_DARK = createQuad(6, 9),
        F11Key_DARK = createQuad(7, 9),
        F12Key_DARK = createQuad(8, 9),
        A_Key_DARK = createQuad(1, 10),
        B_Key_DARK = createQuad(2, 10),
        C_Key_DARK = createQuad(3, 10),
        D_Key_DARK = createQuad(4, 10),
        E_Key_DARK = createQuad(5, 10),
        F_Key_DARK = createQuad(6, 10),
        G_Key_DARK = createQuad(7, 10),
        H_Key_DARK = createQuad(8, 10),
        I_Key_DARK = createQuad(1, 11),
        J_Key_DARK = createQuad(2, 11),
        K_Key_DARK = createQuad(3, 11),
        L_Key_DARK = createQuad(4, 11),
        M_Key_DARK = createQuad(5, 11),
        N_Key_DARK = createQuad(6, 11),
        O_Key_DARK = createQuad(7, 11),
        P_Key_DARK = createQuad(8, 11),
        Q_Key_DARK = createQuad(1, 12),
        R_Key_DARK = createQuad(2, 12),
        S_Key_DARK = createQuad(3, 12),
        T_Key_DARK = createQuad(4, 12),
        U_Key_DARK = createQuad(5, 12),
        V_Key_DARK = createQuad(6, 12),
        W_Key_DARK = createQuad(7, 12),
        X_Key_DARK = createQuad(8, 12),
        Y_Key_DARK = createQuad(1, 13),
        Z_Key_DARK = createQuad(2, 13),
        PERIOD_Key_DARK = createQuad(3, 13),
        COMMA_Key_DARK = createQuad(4, 13),
        QUESTION_MARK_Key_DARK = createQuad(5, 13),
        FORWARD_SLASH_Key_DARK = createQuad(6, 13),
        BACK_SLASH_Key_DARK = createQuad(7, 13),
        SEMI_COLON_Key_DARK = createQuad(8, 13),
        APOSTROPHE_Key_DARK = createQuad(1, 14),
        RIGHT_BRACKET_Key_DARK = createQuad(2, 14),
        LEFT_BRACKET_Key_DARK = createQuad(3, 14),
        EQUALS_PLUS_Key_DARK = createQuad(4, 14),
        MINUS_Key_DARK = createQuad(5, 14),
        TILDA_Key_DARK = createQuad(6, 14),

        -- For space bar and other special keys, we can add them here or use default rendering
        SPACE_Key = createQuad(7, 7),
        SPACE_Key_DARK = createQuad(7, 14)
    }

    -- Create translation table from character to sprite key
    self.charToSpriteKey = {
        -- Letters
        ["a"] = "A_Key",
        ["b"] = "B_Key",
        ["c"] = "C_Key",
        ["d"] = "D_Key",
        ["e"] = "E_Key",
        ["f"] = "F_Key",
        ["g"] = "G_Key",
        ["h"] = "H_Key",
        ["i"] = "I_Key",
        ["j"] = "J_Key",
        ["k"] = "K_Key",
        ["l"] = "L_Key",
        ["m"] = "M_Key",
        ["n"] = "N_Key",
        ["o"] = "O_Key",
        ["p"] = "P_Key",
        ["q"] = "Q_Key",
        ["r"] = "R_Key",
        ["s"] = "S_Key",
        ["t"] = "T_Key",
        ["u"] = "U_Key",
        ["v"] = "V_Key",
        ["w"] = "W_Key",
        ["x"] = "X_Key",
        ["y"] = "Y_Key",
        ["z"] = "Z_Key",

        -- Special characters
        ["."] = "PERIOD_Key",
        [","] = "COMMA_Key",
        ["?"] = "QUESTION_MARK_Key",
        ["/"] = "FORWARD_SLASH_Key",
        ["\\"] = "BACK_SLASH_Key",
        [";"] = "SEMI_COLON_Key",
        ["'"] = "APOSTROPHE_Key",
        ["]"] = "RIGHT_BRACKET_Key",
        ["["] = "LEFT_BRACKET_Key",
        ["="] = "EQUALS_PLUS_Key",
        ["+"] = "EQUALS_PLUS_Key",
        ["-"] = "MINUS_Key",
        ["~"] = "TILDA_Key",
        [" "] = "SPACE_Key"
    }

    self.loaded = true
    print("KeySpriteMapper: Loaded keyboard sprite mappings")
    return true
end

-- Get a sprite quad for a character
function KeySpriteMapper:getQuadForChar(char, isDark)
    -- Convert to lowercase for consistency
    char = string.lower(char)

    -- Get the sprite key for this character
    local spriteKey = self.charToSpriteKey[char]
    if not spriteKey then
        -- Fallback for unsupported characters
        return nil
    end

    -- Get the appropriate quad (normal or dark)
    if isDark then
        return self.mapping[spriteKey .. "_DARK"] or self.mapping[spriteKey]
    else
        return self.mapping[spriteKey]
    end
end

-- Draw a key sprite
function KeySpriteMapper:drawKey(char, x, y, width, height, isDark)
    if not self.loaded then
        self:load()
    end

    if not self.sheet then
        return false
    end

    local quad = self:getQuadForChar(char, isDark)
    if not quad then
        return false
    end

    -- Draw the sprite with scaling to fit the desired width/height
    love.graphics.draw(
            self.sheet,
            quad,
            x,
            y,
            0, -- rotation
            width / SPRITE_WIDTH,
            height / SPRITE_HEIGHT
    )

    return true
end

return KeySpriteMapper