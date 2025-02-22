-- modules/keySpriteMapper.lua
local keySpriteMapper = {}
keySpriteMapper.__index = keySpriteMapper

-- Main key sprite sheet is 8c x 14r
-- 128px width = 16px each
-- 224px height = 16px each

local mainKeySpriteSheetPath = "assets/keyboard_letters_and_symbols.png"
local spriteSheet = love.graphics.newImage(mainKeySpriteSheetPath)
local spriteWidth, spriteHeight = 16, 16
local sheetWidth, sheetHeight = spriteSheet:getDimensions()

-- Helper function to create a quad for a given column and row.
-- Note: Here columns and rows are 1-indexed.
local function createQuad(col, row)
    return love.graphics.newQuad(
            (col - 1) * spriteWidth,
            (row - 1) * spriteHeight,
            spriteWidth,
            spriteHeight,
            sheetWidth,
            sheetHeight
    )
end

-- Define a table mapping keywords to specific quads.
-- Adjust the columns/rows as appropriate for your sprite sheet.
keySpriteMapper.mapping = {
    upArrowKey  = createQuad(1,1),
    downArrowKey = createQuad(2, 1),
    rightArrowKey  = createQuad(3, 1),
    leftArrowKey  = createQuad(4, 1),
    F1Key  = createQuad(5, 1),
    F2Key  = createQuad(6, 1),
    F3Key  = createQuad(7, 1),
    F4Key  = createQuad(8, 1),
    F5Key  = createQuad(1, 2),
    F6Key  = createQuad(2, 2),
    F7Key  = createQuad(3, 2),
    F8Key  = createQuad(4, 2),
    F9Key  = createQuad(5, 2),
    F10Key  = createQuad(6, 2),
    F11Key  = createQuad(7, 2),
    F12Key  = createQuad(8, 2),
    A_Key  = createQuad(1, 3),
    B_Key  = createQuad(2, 3),
    C_Key  = createQuad(3, 3),
    D_Key  = createQuad(4, 3),
    E_Key  = createQuad(5, 3),
    F_Key  = createQuad(6, 3),
    G_Key  = createQuad(7, 3),
    H_Key  = createQuad(8, 3),
    I_Key  = createQuad(1, 4),
    J_Key  = createQuad(2, 4),
    K_Key  = createQuad(3, 4),
    L_Key  = createQuad(4, 4),
    M_Key  = createQuad(5, 4),
    N_Key  = createQuad(6, 4),
    O_Key  = createQuad(7, 4),
    P_Key  = createQuad(8, 4),
    Q_Key  = createQuad(1, 5),
    R_Key  = createQuad(2, 5),
    S_Key  = createQuad(3, 5),
    T_Key  = createQuad(4, 5),
    U_Key  = createQuad(5, 5),
    V_Key  = createQuad(6, 5),
    W_Key  = createQuad(7, 5),
    X_Key  = createQuad(8, 5),
    Y_Key  = createQuad(1, 6),
    Z_Key  = createQuad(2, 6),
    PERIOD_Key  = createQuad(3, 6),
    COMMA_Key  = createQuad(4, 6),
    QUESTION_MARK_Key  = createQuad(5, 6),
    FORWARD_SLASH_Key  = createQuad(6, 6),
    BACK_SLASH_Key  = createQuad(7, 6),
    SEMI_COLON_Key  = createQuad(8, 6),
    APOSTROPHE_Key  = createQuad(1, 7),
    RIGHT_BRACKET_Key  = createQuad(2, 7),
    LEFT_BRACKET_Key  = createQuad(3, 7),
    EQUALS_PLUS_Key  = createQuad(4, 7),
    MINUS_Key  = createQuad(5, 7),
    TILDA_Key  = createQuad(6, 7),
    
    -- DARK SET WITH TEAL FONT
    upArrowKey_DARK  = createQuad(1,8),
    downArrowKey_DARK = createQuad(2, 8),
    rightArrowKey_DARK  = createQuad(3, 8),
    leftArrowKey_DARK  = createQuad(4, 8),
    F1Key_DARK  = createQuad(5, 8),
    F2Key_DARK  = createQuad(6, 8),
    F3Key_DARK  = createQuad(7, 8),
    F4Key_DARK  = createQuad(8, 8),
    F5Key_DARK  = createQuad(1, 9),
    F6Key_DARK  = createQuad(2, 9),
    F7Key_DARK  = createQuad(3, 9),
    F8Key_DARK  = createQuad(4, 9),
    F9Key_DARK  = createQuad(5, 9),
    F10Key_DARK  = createQuad(6, 9),
    F11Key_DARK  = createQuad(7, 9),
    F12Key_DARK  = createQuad(8, 9),
    A_Key_DARK  = createQuad(1, 10),
    B_Key_DARK  = createQuad(2, 10),
    C_Key_DARK  = createQuad(3, 10),
    D_Key_DARK  = createQuad(4, 10),
    E_Key_DARK  = createQuad(5, 10),
    F_Key_DARK  = createQuad(6, 10),
    G_Key_DARK  = createQuad(7, 10),
    H_Key_DARK  = createQuad(8, 10),
    I_Key_DARK  = createQuad(1, 11),
    J_Key_DARK  = createQuad(2, 11),
    K_Key_DARK  = createQuad(3, 11),
    L_Key_DARK  = createQuad(4, 11),
    M_Key_DARK  = createQuad(5, 11),
    N_Key_DARK  = createQuad(6, 11),
    O_Key_DARK  = createQuad(7, 11),
    P_Key_DARK  = createQuad(8, 11),
    Q_Key_DARK  = createQuad(1, 12),
    R_Key_DARK  = createQuad(2, 12),
    S_Key_DARK  = createQuad(3, 12),
    T_Key_DARK  = createQuad(4, 12),
    U_Key_DARK  = createQuad(5, 12),
    V_Key_DARK  = createQuad(6, 12),
    W_Key_DARK  = createQuad(7, 12),
    X_Key_DARK  = createQuad(8, 12),
    Y_Key_DARK  = createQuad(1, 13),
    Z_Key_DARK  = createQuad(2, 13),
    PERIOD_Key_DARK  = createQuad(3, 13),
    COMMA_Key_DARK  = createQuad(4, 13),
    QUESTION_MARK_Key_DARK  = createQuad(5, 13),
    FORWARD_SLASH_Key_DARK  = createQuad(6, 13),
    BACK_SLASH_Key_DARK  = createQuad(7, 13),
    SEMI_COLON_Key_DARK  = createQuad(8, 13),
    APOSTROPHE_Key_DARK  = createQuad(1, 14),
    RIGHT_BRACKET_Key_DARK  = createQuad(2, 14),
    LEFT_BRACKET_Key_DARK  = createQuad(3, 14),
    EQUALS_PLUS_Key_DARK  = createQuad(4, 14),
    MINUS_Key_DARK  = createQuad(5, 14),
    TILDA_Key_DARK  = createQuad(6, 14),
    
    -- add more mappings as needed...
}

keySpriteMapper.sheet = spriteSheet


function keySpriteMapper:mapSpritesFromFile()
    local spriteSheet = love.graphics.newImage("path/to/spritesheet.png")
    local quads = {}

    local sheetWidth = spriteSheet:getWidth()   -- 128
    local sheetHeight = spriteSheet:getHeight() -- 224

    local columns = sheetWidth / spriteWidth  -- 8
    local rows = sheetHeight / spriteHeight   -- 14

    for row = 0, rows - 1 do
        for col = 0, columns - 1 do
            local quad = love.graphics.newQuad(
                    col * spriteWidth,    -- x position on sheet
                    row * spriteHeight,   -- y position on sheet
                    spriteWidth, spriteHeight,
                    sheetWidth, sheetHeight
            )
            table.insert(quads, quad)
        end
    end
    -- Create the canvas (size can be adjusted as needed)
    local canvas = love.graphics.newCanvas(128, 224)

    function love.draw()
        -- Draw to the canvas
        love.graphics.setCanvas(canvas)
        love.graphics.clear()
        -- Draw a specific sprite on the canvas at (0, 0)
        local spriteIndex = 1
        love.graphics.draw(spriteSheet, quads[spriteIndex], 0, 0)
        love.graphics.setCanvas()  -- Reset to the default screen canvas

        -- Now draw the canvas on the screen
        love.graphics.draw(canvas, 50, 50)
    end
end

return keySpriteMapper