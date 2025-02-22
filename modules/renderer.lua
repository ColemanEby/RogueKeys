local Renderer = {}
Renderer.__index = Renderer

-- Default settings
Renderer.scale = "dynamic"
Renderer.theme = "dark"

local mainCanvasPadding = 20

-- Create a new Renderer instance.
function Renderer:new()
    local self = setmetatable({}, Renderer)
    self.menus = {}  -- Table to store menus that are added.
    return self
end

-- Add a menu to the renderer's management.
function Renderer:addMenu(menu)
    table.insert(self.menus, menu)
end

-- Draw the main canvas and render all added menus onto it.
function Renderer:drawMainCanvas()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local canvasWidth = screenWidth - (2 * mainCanvasPadding)
    local canvasHeight = screenHeight - (2 * mainCanvasPadding)

    local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")

    -- Draw a main background rectangle (example style).
    love.graphics.setColor(1, 0, 0, 0.5)  -- semi-transparent red
    love.graphics.rectangle("fill", 0, 0, canvasWidth, canvasHeight)

    -- Render each menu in its modular slot.
    for _, menu in ipairs(self.menus) do
        menu:draw()
    end

    love.graphics.setCanvas()
    love.graphics.draw(canvas, mainCanvasPadding, mainCanvasPadding)
end

-- Getter functions (placeholders for further functionality)
function Renderer:getScale()
    return self.scale
end

function Renderer:getTheme()
    return self.theme
end

return Renderer
