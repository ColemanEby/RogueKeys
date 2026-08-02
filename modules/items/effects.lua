-- modules/items/effects.lua
-- The nine keycap effect behaviours. Every function has the shape
--   (item, ctx, state) -> points, procs
-- documented in the shared contract. `ctx` carries this keystroke's situation
-- (streak/prevChar/round/isVowel, plus a couple of fields keyboardModel
-- precomputes for effects that need them -- see the comments below). `state`
-- is the round-scoped bookkeeping table keyboardModel hands back in on every
-- call for the same key; effects that need memory (grace, echo) read/write it
-- and nothing else, so they stay deterministic given (item, ctx, state).
--
-- `procs` is a small table of what happened, consumed by juice/audio (unit
-- 16) and by keyboardModel itself for the aggregate crit/coins/echo/set flags
-- on computeKeyScore's return value. Effects that don't proc anything return
-- an empty table rather than nil, so callers never need a nil-guard.

local Effects = {}

-- The guaranteed point value of a correct keystroke before any item touches
-- it. crit and echo reference this rather than a hardcoded 1 so the "double"
-- and "bank" language in the design stays literally true.
Effects.BASE_SCORE = 1.0

Effects.KINDS = {
    "flat", "streak", "adjacent", "echo", "coin",
    "grace", "crit", "protect", "set",
}

-- "flat": a constant bonus on this key. The baseline effect kind; commons are
-- almost always this.
function Effects.flat(item, ctx, state)
    return item.effect.value, {}
end

-- "streak": scales with the current streak. Streak 0 (first keystroke, or
-- right after a mistake) yields zero -- it rewards sustained accuracy, not
-- the press itself.
function Effects.streak(item, ctx, state)
    local streak = ctx.streak or 0
    return item.effect.value * streak, {}
end

-- "adjacent": doubles this key's base value if the previous character typed
-- was a physical neighbour on the current layout. keyboardModel precomputes
-- `ctx.adjacentToPrev` (via KeyboardModel:isAdjacent) so this stays a pure
-- lookup -- no prevChar (start of text) is simply "not adjacent".
function Effects.adjacent(item, ctx, state)
    local points = item.effect.value
    local procs = { adjacent = false }

    if ctx.adjacentToPrev then
        points = points * 2
        procs.adjacent = true
    end

    return points, procs
end

-- "echo": a fraction of this key's base score is banked into a shared pool
-- (state.echoBank) every press; the pool pays out in full the next time a
-- vowel is typed (by any key, not just this one), then resets. Consonant
-- presses with an echo item never score directly from it -- they only ever
-- feed the pool, which is what "echoes to all vowels" means here.
function Effects.echo(item, ctx, state)
    state.echoBank = state.echoBank or 0

    local points = 0
    local procs = { echo = false }

    if ctx.isVowel and state.echoBank > 0 then
        points = state.echoBank
        state.echoBank = 0
        procs.echo = true
    end

    state.echoBank = state.echoBank + item.effect.value * Effects.BASE_SCORE
    return points, procs
end

-- "coin": no score, just currency. procs.coins is read by keyboardModel and
-- summed into the aggregate coin payout for the keystroke.
function Effects.coin(item, ctx, state)
    return 0, { coins = item.effect.value }
end

-- "grace": the first error per round on this key is forgiven. Scoring-wise
-- this never contributes points; it only matters on the error path, which is
-- why it keys off ctx.isError rather than a correct keystroke. Consumption is
-- tracked per (item, round) in state.graceUsed so a new round automatically
-- has a fresh grace without needing an explicit reset call.
function Effects.grace(item, ctx, state)
    state.graceUsed = state.graceUsed or {}
    local usedRounds = state.graceUsed[item.id]

    local procs = { forgiven = false }
    if ctx.isError and not (usedRounds and usedRounds[ctx.round]) then
        state.graceUsed[item.id] = usedRounds or {}
        state.graceUsed[item.id][ctx.round] = true
        procs.forgiven = true
    end

    return 0, procs
end

-- "crit": value is the crit chance (0..1). A crit doubles the keystroke by
-- contributing another BASE_SCORE on top of the guaranteed one. The roll can
-- be injected via ctx.forceRoll for deterministic tests; real play always
-- goes through love.math.random.
function Effects.crit(item, ctx, state)
    local roll = ctx.forceRoll
    if roll == nil then roll = love.math.random() end

    local procs = { crit = false }
    local points = 0

    if roll < item.effect.value then
        points = Effects.BASE_SCORE
        procs.crit = true
    end

    return points, procs
end

-- "protect": an error on this key never resets the streak. Like grace, it
-- only does anything on the error path and never scores points directly.
function Effects.protect(item, ctx, state)
    return 0, { protected = ctx.isError == true }
end

-- "set": a bonus that only activates once every id in item.effect.setMembers
-- is also installed somewhere on the board. keyboardModel populates
-- state.installedIds (id -> true) once per computeKeyScore call.
function Effects.set(item, ctx, state)
    local members = item.effect.setMembers or {}
    local installed = state.installedIds or {}

    local complete = true
    for _, id in ipairs(members) do
        if not installed[id] then
            complete = false
            break
        end
    end

    if complete then
        return item.effect.value, { set = true }
    end
    return 0, { set = false }
end

-- Dispatch by effect.kind. Unknown kinds score nothing rather than raising --
-- a malformed/legacy item should never crash a keystroke.
function Effects.compute(kind, item, ctx, state)
    local fn = Effects[kind]
    if type(fn) ~= "function" then
        return 0, {}
    end
    return fn(item, ctx, state)
end

return Effects
