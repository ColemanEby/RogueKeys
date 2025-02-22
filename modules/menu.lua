local Menu = {}
Menu.__index = Menu

-- Constructor: x, y for positioning, width/height for canvas size,
-- and an optional options table for things like background color.
function Menu:new(x, y, width, height, options)
    local self = setmetatable({}, Menu)
    self.x = x or 0
    self.y = y or 0
    self.width = width or 600
    self.height = height or 600
    self.options = options or {}
    self.data = {}  -- dynamic game data (like score, time, etc.)
    self.canvas = love.graphics.newCanvas(self.width, self.height)
    return self
end

-- Update dynamic data that will be used when rendering the menu.
function Menu:update(data)
    self.data = data or self.data
end

-- Draw the menu onto its own canvas, then render that canvas at (x,y).
function Menu:draw()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 0)

    -- Set a background color if provided, else use a default.
    local bg = self.options.backgroundColor or {0.2, 0.2, 0.2, 1}
    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)

    -- Example: Draw dynamic game data (like a score) on the menu.
    love.graphics.setColor(1, 1, 1, 1)
    local score = self.data.score or 0
    love.graphics.print("Score: " .. tostring(score), 10, 10)

    -- Reset canvas so future drawing goes to the main screen.
    love.graphics.setCanvas()

    -- Finally, draw the menu canvas at its defined position.
    love.graphics.draw(self.canvas, self.x, self.y)
end

return Menu
