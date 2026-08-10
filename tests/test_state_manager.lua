-- tests/test_state_manager.lua
-- Headless coverage for engine/stateManager.lua: real transitions, params
-- delivery, the overlay stack, and the back() history fix. Uses plain fake
-- state tables (not real states/*.lua) so this needs no graphics context.

local H = require("tests/helpers")

-- StateManager is a singleton module full of mutable state (current, history,
-- overlayStack). Reload it fresh for every case so cases can't see each
-- other's leftovers.
local function fresh()
    package.loaded["engine/stateManager"] = nil
    return require("engine/stateManager")
end

-- Transitions are timer-driven; force one to completion in a single tick
-- without depending on love.timer (unavailable headless).
local function finishTransition(SM)
    SM.updateTransition(SM.transitionDuration)
end

return {

    ["switch calls exit on the old state then enter on the new one"] = function()
        local SM = fresh()
        local order = {}
        local A = {
            name = "A",
            enter = function() order[#order + 1] = "A.enter" end,
            exit = function() order[#order + 1] = "A.exit" end,
        }
        local B = {
            name = "B",
            enter = function() order[#order + 1] = "B.enter" end,
            exit = function() order[#order + 1] = "B.exit" end,
        }

        SM.switchImmediate(A)
        order = {}

        SM.switch(B)
        H.isTrue(SM.transitioning, "switch should start a transition, not swap synchronously")
        H.equal(#order, 0, "the swap must not happen before the transition midpoint")

        finishTransition(SM)
        H.isFalse(SM.transitioning, "transition should be finished after a full-duration tick")
        H.deepEqual(order, { "A.exit", "B.enter" })
        H.equal(SM.current, B)
    end,

    ["switch(name, params) delivers params to enter"] = function()
        local SM = fresh()
        local received = "unset"
        local A = { name = "A" }
        local B = { name = "B", enter = function(params) received = params end }

        SM.switchImmediate(A)
        SM.switch(B, { returnTo = "resultsState" })
        finishTransition(SM)

        H.deepEqual(received, { returnTo = "resultsState" })
    end,

    ["push does not exit the underlying state; pop resumes it"] = function()
        local SM = fresh()
        local order = {}
        local A = {
            name = "A",
            exit = function() order[#order + 1] = "A.exit" end,
            enter = function() order[#order + 1] = "A.enter" end,
            resume = function() order[#order + 1] = "A.resume" end,
        }
        local Overlay = {
            name = "Overlay",
            enter = function() order[#order + 1] = "Overlay.enter" end,
            exit = function() order[#order + 1] = "Overlay.exit" end,
        }

        SM.switchImmediate(A)
        order = {}

        SM.push(Overlay)
        H.deepEqual(order, { "Overlay.enter" }, "push must not touch the underlying state")
        H.equal(SM.current, Overlay)
        H.isTrue(SM.isOverlayActive())

        order = {}
        SM.pop()
        H.deepEqual(order, { "Overlay.exit", "A.resume" }, "pop must resume, not re-enter")
        H.equal(SM.current, A)
        H.isFalse(SM.isOverlayActive())
    end,

    ["pop falls back to enter when the underlying state has no resume"] = function()
        local SM = fresh()
        local order = {}
        local A = { name = "A", enter = function() order[#order + 1] = "A.enter" end }
        local Overlay = { name = "Overlay" }

        SM.switchImmediate(A)
        order = {}

        SM.push(Overlay)
        order = {}

        SM.pop()
        H.deepEqual(order, { "A.enter" })
    end,

    ["nested push and pop restores the right state"] = function()
        local SM = fresh()
        SM.switchImmediate({ name = "A" })
        SM.push({ name = "B" })
        SM.push({ name = "C" })

        H.equal(SM.current.name, "C")
        H.isTrue(SM.isOverlayActive())

        SM.pop()
        H.equal(SM.current.name, "B")
        H.isTrue(SM.isOverlayActive())

        SM.pop()
        H.equal(SM.current.name, "A")
        H.isFalse(SM.isOverlayActive())
    end,

    ["back() twice walks back two states"] = function()
        local SM = fresh()
        SM.switchImmediate({ name = "A" })
        SM.switchImmediate({ name = "B" })
        SM.switchImmediate({ name = "C" })

        SM.back()
        finishTransition(SM)
        H.equal(SM.current.name, "B", "first back() should land on B")

        SM.back()
        finishTransition(SM)
        H.equal(SM.current.name, "A", "second back() should land on A, not bounce back to C")
    end,

    ["history is capped at maxHistorySize"] = function()
        local SM = fresh()
        local total = SM.maxHistorySize + 5

        for i = 1, total do
            SM.switchImmediate({ name = "S" .. i })
        end

        H.equal(#SM.history, SM.maxHistorySize, "history must not grow past the cap")

        local pushes = total - 1 -- the first switchImmediate has no prior state to push
        local survivingStart = pushes - SM.maxHistorySize + 1
        H.equal(SM.history[1].name, "S" .. survivingStart, "oldest surviving entry should be trimmed correctly")
    end,

    ["a state that throws in enter does not corrupt the manager"] = function()
        local SM = fresh()
        SM.switchImmediate({ name = "A" })

        local Bad = { name = "Bad", enter = function() error("boom") end }
        H.succeeds(function() SM.switchImmediate(Bad) end)
        H.equal(SM.current.name, "Bad", "current should still update even though enter raised")

        -- The manager must still be fully usable afterward.
        H.succeeds(function() SM.switchImmediate({ name = "C" }) end)
        H.equal(SM.current.name, "C")
    end,

    ["isOverlayActive reflects the stack"] = function()
        local SM = fresh()
        H.isFalse(SM.isOverlayActive())

        SM.switchImmediate({ name = "A" })
        H.isFalse(SM.isOverlayActive())

        SM.push({ name = "B" })
        H.isTrue(SM.isOverlayActive())

        SM.pop()
        H.isFalse(SM.isOverlayActive())
    end,

    ["keyboard input is dropped mid-transition and delivered once settled"] = function()
        local SM = fresh()
        SM.switchImmediate({ name = "A" })

        local pressed = false
        local B = { name = "B", keypressed = function() pressed = true end }

        SM.switch(B)
        SM.keypressed("a")
        H.isFalse(pressed, "a keypress mid-fade must not reach the incoming state")

        finishTransition(SM)
        SM.keypressed("a")
        H.isTrue(pressed, "once settled, input should reach the current state again")
    end,

    ["update advances a fade without starving state updates"] = function()
        local SM = fresh()
        local updates = {}
        local A = {
            name = "A",
            update = function(dt) updates[#updates + 1] = { state = "A", dt = dt } end,
        }
        local B = {
            name = "B",
            update = function(dt) updates[#updates + 1] = { state = "B", dt = dt } end,
        }

        SM.switchImmediate(A)
        SM.switch(B)

        local quarter = SM.transitionDuration / 4
        SM.update(quarter)
        H.near(SM.transitionTimer, quarter)
        H.equal(SM.current, A, "the outgoing state should remain current before midpoint")
        H.deepEqual(updates[1], { state = "A", dt = quarter })

        SM.update(quarter)
        H.equal(SM.current, B, "the incoming state should become current at midpoint")
        H.deepEqual(updates[2], { state = "B", dt = quarter })
    end,

    ["draw is headless-safe before and after the fade midpoint"] = function()
        local SM = fresh()
        local draws = { A = 0, B = 0 }
        local A = { name = "A", draw = function() draws.A = draws.A + 1 end }
        local B = { name = "B", draw = function() draws.B = draws.B + 1 end }

        SM.switchImmediate(A)
        SM.switch(B)

        SM.updateTransition(SM.transitionDuration / 4)
        H.succeeds(function() SM.draw() end, "draw should work headless before midpoint")
        H.deepEqual(draws, { A = 1, B = 0 })

        SM.updateTransition(SM.transitionDuration / 2)
        H.equal(SM.current, B)
        H.succeeds(function() SM.draw() end, "draw should work headless after midpoint")
        H.deepEqual(draws, { A = 1, B = 1 }, "the incoming state should draw after the swap")

        SM.updateTransition(SM.transitionDuration / 4)
        H.succeeds(function() SM.draw() end, "draw should work headless after completion")
        H.deepEqual(draws, { A = 1, B = 2 })
    end,

    ["fade timeline starts swaps at midpoint and completes at duration"] = function()
        local SM = fresh()
        local draws = 0
        local A = { name = "A" }
        local B = { name = "B", draw = function() draws = draws + 1 end }

        SM.switchImmediate(A)
        H.equal(SM.transitionDuration, 0.2)

        SM.switch(B)
        H.isTrue(SM.transitioning)
        H.equal(SM.transitionTimer, 0)
        H.equal(SM.current, A)

        local half = SM.transitionDuration / 2
        SM.updateTransition(half - 0.001)
        H.equal(SM.current, A, "the state must not swap before midpoint")

        SM.updateTransition(0.001)
        H.equal(SM.current, B, "the state must swap at midpoint")
        H.isTrue(SM.transitioning, "the fade-out half should still be in progress")

        SM.updateTransition(half)
        H.isFalse(SM.transitioning, "the fade should finish at its full duration")
        H.succeeds(function() SM.draw() end, "normal drawing should resume after completion")
        H.equal(draws, 1)
    end,

    ["switching again during a fade leaves the manager valid"] = function()
        local SM = fresh()
        local entered = {}
        local A = { name = "A" }
        local B = { name = "B", enter = function() entered[#entered + 1] = "B" end }
        local C = { name = "C", enter = function() entered[#entered + 1] = "C" end }

        SM.switchImmediate(A)
        SM.switch(B)
        SM.updateTransition(SM.transitionDuration / 4)

        H.succeeds(function() SM.switch(C) end, "a second switch should safely restart the fade")
        H.equal(SM.current, A, "restarting before midpoint should keep the current state until the new midpoint")
        H.equal(SM.transitionTimer, 0)

        finishTransition(SM)
        H.equal(SM.current, C)
        H.deepEqual(entered, { "C" }, "the superseded transition must not enter its target")
        H.isFalse(SM.transitioning)
    end,

}
