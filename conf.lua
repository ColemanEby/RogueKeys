-- conf.lua
local conf = {}
conf.__index = conf

function love.conf(t)
    t.window.width = 1500
    t.window.height = 1000
end

