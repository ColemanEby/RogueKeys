-- tests/run.lua
-- Headless test runner. Invoked by main.lua when the game is started with
-- `love . --test`, which conf.lua turns into a window-less run.
--
-- Adding tests: drop a file at tests/test_<name>.lua returning a table of
-- { ["case name"] = function() ... end }. It is discovered automatically.
-- Use tests/helpers.lua for assertions.
--
-- A suite table may also export `setup` / `teardown` functions; if present
-- they run around every case in that suite (not just once per suite) and are
-- never treated as cases themselves.
--
-- Flags:
--   --filter <a,b,c>   run only files/cases whose name contains any of the
--                      comma-separated substrings (plain substring match).
--   --list             print discovered suites/cases (honors --filter) and
--                      exit without running anything.

local Runner = {}

local helpers = require("tests/helpers")

-- A case slower than this is still a pass, but gets flagged in the output --
-- the word-list preload (4.2 MB) is the expected outlier.
local SLOW_MS = 100

local function hasFlag(flag)
    if type(arg) ~= "table" then return false end
    for _, a in ipairs(arg) do
        if a == flag then return true end
    end
    return false
end

-- Returns an array of filter substrings, or nil if --filter was not passed.
local function getFilters()
    if type(arg) ~= "table" then return nil end
    local raw = nil
    for i, a in ipairs(arg) do
        if a == "--filter" then
            raw = arg[i + 1]
            break
        end
        local inline = a:match("^%-%-filter=(.+)$")
        if inline then
            raw = inline
            break
        end
    end
    if not raw then return nil end

    local filters = {}
    for term in raw:gmatch("[^,]+") do
        filters[#filters + 1] = term
    end
    return filters
end

local function matchesFilter(filters, fileName, caseName)
    if not filters then return true end
    for _, f in ipairs(filters) do
        if fileName:find(f, 1, true) or caseName:find(f, 1, true) then
            return true
        end
    end
    return false
end

local function discover()
    local files = {}
    local items = love.filesystem.getDirectoryItems("tests")
    table.sort(items)

    for _, item in ipairs(items) do
        local name = item:match("^(test_[%w_]+)%.lua$")
        if name then
            files[#files + 1] = name
        end
    end

    return files
end

-- setup/teardown are suite lifecycle hooks, never cases, even though
-- discovery otherwise treats every function value as a case.
local function caseNamesOf(suite)
    local caseNames = {}
    for caseName, value in pairs(suite) do
        if type(value) == "function" and caseName ~= "setup" and caseName ~= "teardown" then
            caseNames[#caseNames + 1] = caseName
        end
    end
    table.sort(caseNames)
    return caseNames
end

local function now()
    if love.timer and love.timer.getTime then return love.timer.getTime() end
    return os.clock()
end

-- Guarded so a broken Context module can never take down the runner itself --
-- isolation between suites must not become its own source of failures.
local function resetContext()
    local ok = pcall(function()
        local Context = require("modules/game/context")
        if Context and type(Context.reset) == "function" then
            Context.reset()
        end
    end)
    if not ok then
        print("  WARNING: Context.reset() failed between suites")
    end
end

local function listMode(files, filters)
    print("")
    print("=== RogueKeys test suite (--list) ===")
    if filters then print("filter: " .. table.concat(filters, ",")) end

    for _, name in ipairs(files) do
        local okLoad, suite = pcall(require, "tests/" .. name)
        print("")
        print(name)

        if not okLoad or type(suite) ~= "table" then
            print("  <load failed: " .. tostring(suite) .. ">")
        else
            for _, caseName in ipairs(caseNamesOf(suite)) do
                if matchesFilter(filters, name, caseName) then
                    print("  " .. caseName)
                end
            end
        end
    end
    print("")
end

function Runner.run()
    local filters = getFilters()
    local files = discover()

    if hasFlag("--list") then
        listMode(files, filters)
        return 0
    end

    local passed, failed, skipped = 0, 0, 0
    local failures = {}

    print("")
    print("=== RogueKeys test suite ===")
    if filters then print("filter: " .. table.concat(filters, ",")) end

    for _, name in ipairs(files) do
        local okLoad, suite = pcall(require, "tests/" .. name)

        if not okLoad then
            failed = failed + 1
            failures[#failures + 1] = { name = name, case = "<load>", err = tostring(suite) }
            print("  LOAD FAIL  " .. name .. ": " .. tostring(suite))
        elseif type(suite) ~= "table" then
            failed = failed + 1
            failures[#failures + 1] = { name = name, case = "<load>", err = "suite did not return a table" }
            print("  LOAD FAIL  " .. name .. ": did not return a table")
        else
            local caseNames = caseNamesOf(suite)

            print("")
            print(name)

            for _, caseName in ipairs(caseNames) do
                if not matchesFilter(filters, name, caseName) then
                    skipped = skipped + 1
                else
                    local setupOk, setupErr = true, nil
                    if type(suite.setup) == "function" then
                        setupOk, setupErr = pcall(suite.setup)
                    end

                    local start = now()
                    local okCase, err

                    if not setupOk then
                        okCase, err = false, "setup failed: " .. tostring(setupErr)
                    else
                        okCase, err = xpcall(suite[caseName], function(e)
                            return tostring(e) .. "\n" .. debug.traceback("", 2)
                        end)
                    end

                    if type(suite.teardown) == "function" then
                        local tdOk, tdErr = pcall(suite.teardown)
                        if not tdOk and okCase then
                            okCase, err = false, "teardown failed: " .. tostring(tdErr)
                        end
                    end

                    local elapsedMs = (now() - start) * 1000
                    local timing = string.format(" (%.1fms)", elapsedMs)
                    if elapsedMs >= SLOW_MS then timing = timing .. " SLOW" end

                    if okCase then
                        passed = passed + 1
                        print("  pass  " .. caseName .. timing)
                    else
                        failed = failed + 1
                        failures[#failures + 1] = { name = name, case = caseName, err = err }
                        print("  FAIL  " .. caseName .. timing)
                    end
                end
            end
        end

        -- One suite's leftover Context state (a loaded player, an active run)
        -- must never bleed into the next suite's assumptions.
        resetContext()
    end

    if #failures > 0 then
        print("")
        print("--- failures ---")
        for _, f in ipairs(failures) do
            print("")
            print(f.name .. " :: " .. f.case)
            print(f.err)
        end
    end

    print("")
    print(string.format("TESTS: %d passed, %d failed, %d skipped", passed, failed, skipped))

    if failed == 0 then
        print("")
        print("=========================================")
        print("  ALL TESTS PASSED (" .. passed .. ")")
        print("=========================================")
    end
    print("")

    return failed
end

return Runner
