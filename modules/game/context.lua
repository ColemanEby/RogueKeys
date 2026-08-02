-- modules/game/context.lua
-- One authoritative game context shared by every state.
--
-- Historically roundState, shopState and statsState each cached their own
-- PlayerModel.load(), producing divergent copies of the player and the
-- money/upgrade desync bugs. Every state must now go through Context.player().

local Context = {}

local player = nil

-- The memoized player instance. Loads from disk on first call only.
function Context.player()
    if not player then
        local PlayerModel = require("modules/player/playerModel")
        player = PlayerModel.load()
    end
    return player
end

-- Replace the live player (used by "reset progress" and by tests).
function Context.setPlayer(newPlayer)
    player = newPlayer
    return player
end

-- Drop the cached player so the next Context.player() re-reads from disk.
function Context.reload()
    player = nil
    return Context.player()
end

-- The active run, owned by modules/game/run.lua. nil when no run is in progress.
Context.run = nil

function Context.setRun(run)
    Context.run = run
    return run
end

function Context.clearRun()
    Context.run = nil
end

-- Hand-off slot for round results travelling from roundState to resultsState /
-- gameOverState. Written once, read once.
local pendingResults = nil

function Context.setPendingResults(results)
    pendingResults = results
end

function Context.peekPendingResults()
    return pendingResults
end

function Context.takePendingResults()
    local r = pendingResults
    pendingResults = nil
    return r
end

-- Full reset, for "reset progress" and between test cases.
function Context.reset()
    player = nil
    Context.run = nil
    pendingResults = nil
end

return Context
