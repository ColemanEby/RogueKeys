-- Headless runs must never share the player's real LOVE save directory.

local H = require("tests/helpers")

local T = {}

function T.uses_an_isolated_test_identity()
    local identity = love.filesystem.getIdentity()
    H.equal(identity, "RogueKeys-test")
    H.notEqual(identity, "RogueKeys")
end

return T
