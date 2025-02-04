-- modules/keyboard.lua
local Keyboard = {}

function Keyboard.new()
    local self = {
         multiplier = 1.0,  -- (Not used now, since upgrades are per key.)
         name = "Standard Keyboard",
         upgrades = {}      -- mapping: key (lowercase) → bonus (e.g., 0.1)
    }
    return self
end

return Keyboard
