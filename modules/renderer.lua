-- modules/renderer.lua
local Renderer = {}
Renderer.__index = Renderer
Renderer.scale = "dynamic"
Renderer.theme = "dark"

local mainCanvasPadding = 20

function Renderer:getMainMenuCanvas()
    -- Get the screen dimensions and subtract padding to define the canvas size.
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local canvasWidth = screenWidth - (2 * mainCanvasPadding)
    local canvasHeight = screenHeight - (2 * mainCanvasPadding)

    -- Create a new canvas with the calculated dimensions.
    local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")

    -- Draw the main rectangle covering the entire canvas.
    love.graphics.setColor(1, 0, 0, 0.5)  -- semi-transparent red
    love.graphics.rectangle("fill", 0, 0, canvasWidth, canvasHeight)

    -- Define a gap for spacing between the inner rectangles and edges.
    local gap = 10
    -- Calculate inner rectangle dimensions:
    -- We'll fit two inner rectangles side-by-side and vertically so that each has equal width and height.
    local innerWidth = (canvasWidth - 3 * gap) / 2
    local innerHeight = (canvasHeight - 3 * gap) / 2

    local canvas1 = love.graphics.newCanvas(canvasWidth, canvasHeight)
    -- Draw the first inner rectangle (top-left).
    love.graphics.setColor(0, 1, 0, 0.5)  -- semi-transparent green
    love.graphics.rectangle("fill", gap, gap, innerWidth, innerHeight)

    -- Draw the second inner rectangle (bottom-right).
    love.graphics.setColor(0, 0, 1, 0.5)  -- semi-transparent blue
    love.graphics.rectangle("fill", innerWidth + 2 * gap, innerHeight + 2 * gap, innerWidth, innerHeight)
    love.graphics.setCanvas()

    return canvas
end



function Renderer:getScale()
    
end

function Renderer:getTheme()
    
end

return Renderer