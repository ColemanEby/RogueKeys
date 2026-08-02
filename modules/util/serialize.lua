-- modules/util/serialize.lua
-- Canonical table <-> save-file encoding, backed by serpent (MIT).
--
-- This replaces the two hand-rolled serializers that used to live in
-- playerModel and configManager. Both of them dropped numeric keys (emitting
-- array values positionally), which silently re-indexed sparse arrays and
-- destroyed match-history ordering, and neither escaped backslashes or
-- newlines in strings.
--
-- Use Serialize.encode/decode for anything written to disk so the two callers
-- can never drift apart again.

local serpent = require("lib/serpent")

local Serialize = {}

-- sparse=true keeps explicit [n]= keys for arrays with holes instead of
-- collapsing them; sortkeys=true makes saves diffable and deterministic.
local ENCODE_OPTS = {
    comment = false,
    sortkeys = true,
    sparse = true,
    indent = "  ",
    nocode = true,
}

-- Serialize a table to a complete, loadable Lua chunk ("return {...}").
function Serialize.encode(value)
    local ok, body = pcall(serpent.block, value, ENCODE_OPTS)
    if not ok then
        return nil, "serialization failed: " .. tostring(body)
    end
    return "return " .. body
end

-- Parse a chunk produced by Serialize.encode. Returns (value) on success or
-- (nil, error) on failure. The chunk runs in an empty environment, so a
-- corrupted save cannot reach into the game.
function Serialize.decode(chunk)
    if type(chunk) ~= "string" or chunk == "" then
        return nil, "empty chunk"
    end

    local loader = loadstring or load
    local fn, err = loader(chunk, "=save")
    if not fn then
        return nil, "parse error: " .. tostring(err)
    end

    -- Sandbox: Lua 5.1/LuaJIT uses setfenv, 5.2+ uses the load env argument.
    if setfenv then
        setfenv(fn, {})
    end

    local ok, value = pcall(fn)
    if not ok then
        return nil, "execution error: " .. tostring(value)
    end
    if type(value) ~= "table" then
        return nil, "chunk did not return a table"
    end

    return value
end

return Serialize
