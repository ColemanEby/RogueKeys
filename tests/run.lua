-- tests/run.lua
-- Headless test runner. Invoked by main.lua when the game is started with
-- `love . --test`, which conf.lua turns into a window-less run.
--
-- Adding tests: drop a file at tests/test_<name>.lua returning a table of
-- { ["case name"] = function() ... end }. It is discovered automatically.
-- Use tests/helpers.lua for assertions.
--
-- Filtering: `love . --test --filter items` runs only files/cases matching.

local Runner = {}

local helpers = require("tests/helpers")

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

local function getFilter()
    if type(arg) ~= "table" then return nil end
    for i, a in ipairs(arg) do
        if a == "--filter" then return arg[i + 1] end
        local inline = a:match("^%-%-filter=(.+)$")
        if inline then return inline end
    end
    return nil
end

function Runner.run()
    local filter = getFilter()
    local files = discover()

    local passed, failed, skipped = 0, 0, 0
    local failures = {}

    print("")
    print("=== RogueKeys test suite ===")
    if filter then print("filter: " .. filter) end

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
            -- Deterministic case order.
            local caseNames = {}
            for caseName in pairs(suite) do
                if type(suite[caseName]) == "function" then
                    caseNames[#caseNames + 1] = caseName
                end
            end
            table.sort(caseNames)

            print("")
            print(name)

            for _, caseName in ipairs(caseNames) do
                if filter and not (name:find(filter, 1, true) or caseName:find(filter, 1, true)) then
                    skipped = skipped + 1
                else
                    local okCase, err = xpcall(suite[caseName], function(e)
                        return tostring(e) .. "\n" .. debug.traceback("", 2)
                    end)

                    if okCase then
                        passed = passed + 1
                        print("  pass  " .. caseName)
                    else
                        failed = failed + 1
                        failures[#failures + 1] = { name = name, case = caseName, err = err }
                        print("  FAIL  " .. caseName)
                    end
                end
            end
        end
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
    print("")

    return failed
end

return Runner
