-- tests/helpers.lua
-- Minimal assertion library for the headless test suite. No dependencies, so it
-- works under `love . --test` with most LOVE modules disabled.

local H = {}

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts + 1] = tostring(k) .. "=" .. tostring(val)
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

H.format = fmt

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
function H.deepEqual(actual, expected, msg, path)
    path = path or "root"

    if type(actual) ~= type(expected) then
        error((msg or "type mismatch") .. " at " .. path ..
            "\n  expected: " .. type(expected) ..
            "\n  actual:   " .. type(actual), 2)
    end

    if type(expected) ~= "table" then
        if actual ~= expected then
            error((msg or "values differ") .. " at " .. path ..
                "\n  expected: " .. fmt(expected) ..
                "\n  actual:   " .. fmt(actual), 2)
        end
        return true
    end

    for k, v in pairs(expected) do
        H.deepEqual(actual[k], v, msg, path .. "." .. tostring(k))
    end
    for k in pairs(actual) do
        if expected[k] == nil then
            error((msg or "unexpected key") .. " at " .. path .. "." .. tostring(k), 2)
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

return H
