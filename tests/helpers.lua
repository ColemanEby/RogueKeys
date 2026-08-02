-- tests/helpers.lua
-- Minimal assertion library for the headless test suite. No dependencies, so it
-- works under `love . --test` with most LOVE modules disabled.
--
-- Contract: existing functions (H.equal, H.notEqual, H.near, H.isTrue,
-- H.isFalse, H.deepEqual, H.raises, H.succeeds, H.count, H.fail, H.format)
-- keep their names, argument order and semantics -- eighteen other test files
-- are written against this API. Only add to it.

local H = {}

-- Compact, deterministic rendering of a value for failure messages. Tables
-- render recursively (sorted keys) up to a depth limit so nested structures
-- (save shapes, score breakdowns) are actually legible instead of collapsing
-- to "table: 0x...". Cyclic tables are handled defensively.
local function fmt(v, depth, seen)
    depth = depth or 2
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end

    seen = seen or {}
    if seen[v] then return "<cycle>" end

    if depth <= 0 then return "{...}" end

    seen[v] = true
    local parts = {}
    for k, val in pairs(v) do
        parts[#parts + 1] = tostring(k) .. "=" .. fmt(val, depth - 1, seen)
    end
    table.sort(parts)
    seen[v] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

H.format = function(v) return fmt(v) end

function H.fail(msg)
    error(msg, 2)
end

function H.isTrue(value, msg)
    if not value then
        error((msg or "expected truthy") .. ", got " .. fmt(value), 2)
    end
end

function H.isFalse(value, msg)
    if value then
        error((msg or "expected falsy") .. ", got " .. fmt(value), 2)
    end
end

function H.equal(actual, expected, msg)
    if actual ~= expected then
        error((msg or "values differ") ..
            "\n  expected: " .. fmt(expected) ..
            "\n  actual:   " .. fmt(actual), 2)
    end
end

function H.notEqual(actual, unexpected, msg)
    if actual == unexpected then
        error((msg or "values should differ") .. ", both " .. fmt(actual), 2)
    end
end

function H.near(actual, expected, tolerance, msg)
    tolerance = tolerance or 1e-6
    if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
        error((msg or "values not close") ..
            "\n  expected: " .. fmt(expected) .. " (+/- " .. tolerance .. ")" ..
            "\n  actual:   " .. fmt(actual), 2)
    end
end

-- Deep table comparison, order-insensitive for keys but order-sensitive for
-- array parts (which is exactly what the save round-trip tests need).
--
-- On failure the error shows the exact diverging key path plus a compact
-- rendering of the whole actual/expected values, so a mismatch three levels
-- deep in a save shape doesn't require re-running with print statements.
--
-- rootActual/rootExpected are internal (populated on the first, external
-- call) so recursive calls can still report the full top-level shape
-- alongside the specific diverging leaf. This function stays directly
-- recursive (no wrapper) so `error(msg, 2)` keeps blaming the caller's line
-- for a depth-1 mismatch, exactly as before.
function H.deepEqual(actual, expected, msg, path, rootActual, rootExpected)
    if path == nil then
        path, rootActual, rootExpected = "root", actual, expected
    end

    if type(actual) ~= type(expected) then
        error((msg or "type mismatch") .. " at " .. path ..
            "\n  expected type: " .. type(expected) .. " (" .. fmt(expected) .. ")" ..
            "\n  actual type:   " .. type(actual) .. " (" .. fmt(actual) .. ")" ..
            "\n  full expected: " .. fmt(rootExpected) ..
            "\n  full actual:   " .. fmt(rootActual), 2)
    end

    if type(expected) ~= "table" then
        if actual ~= expected then
            error((msg or "values differ") .. " at " .. path ..
                "\n  expected: " .. fmt(expected) ..
                "\n  actual:   " .. fmt(actual) ..
                "\n  full expected: " .. fmt(rootExpected) ..
                "\n  full actual:   " .. fmt(rootActual), 2)
        end
        return true
    end

    for k, v in pairs(expected) do
        H.deepEqual(actual[k], v, msg, path .. "." .. tostring(k), rootActual, rootExpected)
    end
    for k in pairs(actual) do
        if expected[k] == nil then
            error((msg or "unexpected key") .. " at " .. path .. "." .. tostring(k) ..
                "\n  full expected: " .. fmt(rootExpected) ..
                "\n  full actual:   " .. fmt(rootActual), 2)
        end
    end
    return true
end

-- Assert that fn raises. Returns the error message for further inspection.
function H.raises(fn, msg)
    local ok, err = pcall(fn)
    if ok then
        error(msg or "expected function to raise", 2)
    end
    return tostring(err)
end

-- Assert that fn does not raise. Returns its result.
function H.succeeds(fn, msg)
    local ok, result = pcall(fn)
    if not ok then
        error((msg or "expected function to succeed") .. ", raised: " .. tostring(result), 2)
    end
    return result
end

-- Count entries in a table (including non-array keys).
function H.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Assert haystack contains needle. Works for strings (plain substring search,
-- not a pattern) and arrays (value equality against each element).
function H.contains(haystack, needle, msg)
    if type(haystack) == "string" then
        if not haystack:find(needle, 1, true) then
            error((msg or "string does not contain substring") ..
                "\n  haystack: " .. fmt(haystack) ..
                "\n  needle:   " .. fmt(needle), 2)
        end
        return true
    end

    if type(haystack) == "table" then
        for _, v in pairs(haystack) do
            if v == needle then return true end
        end
        error((msg or "table does not contain value") ..
            "\n  haystack: " .. fmt(haystack) ..
            "\n  needle:   " .. fmt(needle), 2)
    end

    error((msg or "H.contains expects a string or table") .. ", got " .. type(haystack), 2)
end

-- Assert str matches a Lua pattern (unlike H.contains, this is a pattern, not
-- a plain substring).
function H.matches(str, pattern, msg)
    if type(str) ~= "string" or not str:find(pattern) then
        error((msg or "string does not match pattern") ..
            "\n  string:  " .. fmt(str) ..
            "\n  pattern: " .. fmt(pattern), 2)
    end
    return true
end

-- Assert type(value) == typeName.
function H.isType(value, typeName, msg)
    if type(value) ~= typeName then
        error((msg or "wrong type") ..
            "\n  expected: " .. typeName ..
            "\n  actual:   " .. type(value) .. " (" .. fmt(value) .. ")", 2)
    end
end

-- Assert lo <= value <= hi.
function H.between(value, lo, hi, msg)
    if type(value) ~= "number" or value < lo or value > hi then
        error((msg or "value out of range") ..
            "\n  expected: [" .. tostring(lo) .. ", " .. tostring(hi) .. "]" ..
            "\n  actual:   " .. fmt(value), 2)
    end
end

-- Assert tbl has every key in the `keys` array (values are not checked).
function H.hasKeys(tbl, keys, msg)
    if type(tbl) ~= "table" then
        error((msg or "expected a table") .. ", got " .. type(tbl), 2)
    end
    local missing = {}
    for _, k in ipairs(keys) do
        if tbl[k] == nil then missing[#missing + 1] = tostring(k) end
    end
    if #missing > 0 then
        error((msg or "table is missing keys") ..
            "\n  missing: " .. table.concat(missing, ", ") ..
            "\n  table:   " .. fmt(tbl), 2)
    end
end

-- Like H.deepEqual but numeric leaves are compared with a tolerance instead
-- of exact equality -- for float-heavy score/WPM assertions where accumulated
-- rounding makes exact comparison brittle. Same directly-recursive shape as
-- H.deepEqual, for the same error-level reasons.
function H.approxTable(actual, expected, tolerance, msg, path, rootActual, rootExpected)
    if path == nil then
        path, rootActual, rootExpected = "root", actual, expected
    end
    tolerance = tolerance or 1e-6

    if type(expected) == "number" then
        if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
            error((msg or "values not close") .. " at " .. path ..
                "\n  expected: " .. fmt(expected) .. " (+/- " .. tolerance .. ")" ..
                "\n  actual:   " .. fmt(actual) ..
                "\n  full expected: " .. fmt(rootExpected) ..
                "\n  full actual:   " .. fmt(rootActual), 2)
        end
        return true
    end

    if type(actual) ~= type(expected) then
        error((msg or "type mismatch") .. " at " .. path ..
            "\n  expected type: " .. type(expected) .. " (" .. fmt(expected) .. ")" ..
            "\n  actual type:   " .. type(actual) .. " (" .. fmt(actual) .. ")" ..
            "\n  full expected: " .. fmt(rootExpected) ..
            "\n  full actual:   " .. fmt(rootActual), 2)
    end

    if type(expected) ~= "table" then
        if actual ~= expected then
            error((msg or "values differ") .. " at " .. path ..
                "\n  expected: " .. fmt(expected) ..
                "\n  actual:   " .. fmt(actual) ..
                "\n  full expected: " .. fmt(rootExpected) ..
                "\n  full actual:   " .. fmt(rootActual), 2)
        end
        return true
    end

    for k, v in pairs(expected) do
        H.approxTable(actual[k], v, tolerance, msg, path .. "." .. tostring(k), rootActual, rootExpected)
    end
    for k in pairs(actual) do
        if expected[k] == nil then
            error((msg or "unexpected key") .. " at " .. path .. "." .. tostring(k) ..
                "\n  full expected: " .. fmt(rootExpected) ..
                "\n  full actual:   " .. fmt(rootActual), 2)
        end
    end
    return true
end

return H
