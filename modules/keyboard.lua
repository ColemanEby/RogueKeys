-- modules/keyboard.lua
local Keyboard = {}

function Keyboard.new()
    local self = {
        multiplier = 1.0,      -- Multiplier starts at 1.0.
        name = "Standard Keyboard",
        upgrades = {}          -- (Could later store details of purchased keycaps.)
    }
    return self
end

return Keyboard
