-- conf.lua
-- LOVE configuration. Runs before love.load; owns window + identity so that
-- nothing is written to the wrong save directory during boot.

-- Detect the headless test flag before the window is created.
local function hasFlag(flag)
    if type(arg) ~= "table" then return false end
    for _, a in ipairs(arg) do
        if a == flag then return true end
    end
    return false
end

_G.HEADLESS = hasFlag("--test") or hasFlag("--headless")

function love.conf(t)
    t.identity = "RogueKeys"
    t.version = "11.5"
    t.console = false

    t.window.title = "RogueKeys"
    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.resizable = true
    t.window.vsync = 1
    t.window.fullscreen = false

    -- Headless test runs create no window at all.
    if _G.HEADLESS then
        t.window = false
        t.modules.audio = false
        t.modules.sound = false
        t.modules.joystick = false
        t.modules.physics = false
        t.modules.touch = false
        t.modules.video = false
    end
end
