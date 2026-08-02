-- modules/ui/screen.lua
-- Virtual pixel canvas: the game is drawn at a fixed logical 640x360 and blitted
-- to the window at an integer scale with letterboxing, so pixel art stays crisp
-- at every resolution.
--
-- Migration note: this is OPT-IN per state. A state that has been converted to
-- logical coordinates sets `logical = true` on its module table; main.lua then
-- wraps its draw in Screen.push()/Screen.pop() and translates mouse coordinates.
-- States that have not been converted keep drawing at window resolution.

local Screen = {}

Screen.WIDTH = 640
Screen.HEIGHT = 360

local canvas = nil
local scale = 1
local offsetX, offsetY = 0, 0

-- True when running headless (no window, no graphics context).
local function graphicsAvailable()
    return love.graphics ~= nil and not _G.HEADLESS
end

function Screen.init()
    if not graphicsAvailable() then return false end

    love.graphics.setDefaultFilter("nearest", "nearest", 0)

    local ok, result = pcall(love.graphics.newCanvas, Screen.WIDTH, Screen.HEIGHT)
    if not ok then
        print("Screen: failed to create canvas: " .. tostring(result))
        return false
    end

    canvas = result
    canvas:setFilter("nearest", "nearest")
    Screen.resize(love.graphics.getWidth(), love.graphics.getHeight())
    return true
end

-- Recompute integer scale and letterbox offsets for a window size.
function Screen.resize(windowWidth, windowHeight)
    if not graphicsAvailable() then return end

    windowWidth = windowWidth or love.graphics.getWidth()
    windowHeight = windowHeight or love.graphics.getHeight()

    local fit = math.min(windowWidth / Screen.WIDTH, windowHeight / Screen.HEIGHT)
    scale = math.max(1, math.floor(fit))

    offsetX = math.floor((windowWidth - Screen.WIDTH * scale) / 2)
    offsetY = math.floor((windowHeight - Screen.HEIGHT * scale) / 2)
end

-- Begin drawing in logical space. Always pair with Screen.pop().
function Screen.push(clearColor)
    if not canvas then return false end

    love.graphics.setCanvas(canvas)
    if clearColor then
        love.graphics.clear(clearColor[1], clearColor[2], clearColor[3], clearColor[4] or 1)
    else
        love.graphics.clear(0, 0, 0, 1)
    end
    return true
end

-- Blit the logical canvas to the window, letterboxed.
function Screen.pop()
    if not canvas then return end

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
end

-- Window coordinates -> logical coordinates.
function Screen.toGame(x, y)
    if scale == 0 then return x, y end
    return (x - offsetX) / scale, (y - offsetY) / scale
end

-- Logical coordinates -> window coordinates.
function Screen.toWindow(x, y)
    return x * scale + offsetX, y * scale + offsetY
end

function Screen.getWidth() return Screen.WIDTH end
function Screen.getHeight() return Screen.HEIGHT end
function Screen.getDimensions() return Screen.WIDTH, Screen.HEIGHT end
function Screen.getScale() return scale end
function Screen.getOffset() return offsetX, offsetY end
function Screen.isReady() return canvas ~= nil end

return Screen
