-- modules/util/debugHelper.lua
-- Leveled logging plus a couple of small inspection helpers. debug/info are
-- gated on _G.DEBUG_MODE so a normal boot stays quiet; warn/error always
-- print because something has already gone wrong when they fire.
--
-- Usage:
--   local Log = require("modules/util/debugHelper")
--   Log.warn("something odd: %s", value)
--
--   local log = Log.forModule("FileManager")
--   log.debug("wrote %s", path)

local Log = {}

Log.LEVELS = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }

-- Tests inject a sink here to capture output instead of monkeypatching the
-- global `print`. Defaults to print for real use.
local sink = print

function Log.setSink(fn)
    sink = fn or print
end

local function formatMessage(fmt, ...)
    if select("#", ...) == 0 then return tostring(fmt) end
    local ok, msg = pcall(string.format, fmt, ...)
    return ok and msg or tostring(fmt)
end

local function emit(levelName, tag, fmt, ...)
    local prefix = "[" .. levelName .. "]"
    if tag then prefix = prefix .. "[" .. tag .. "]" end
    sink(prefix .. " " .. formatMessage(fmt, ...))
end

function Log.error(fmt, ...) emit("ERROR", nil, fmt, ...) end
function Log.warn(fmt, ...) emit("WARN", nil, fmt, ...) end

function Log.info(fmt, ...)
    if _G.DEBUG_MODE then emit("INFO", nil, fmt, ...) end
end

function Log.debug(fmt, ...)
    if _G.DEBUG_MODE then emit("DEBUG", nil, fmt, ...) end
end

-- Returns a logger with the same four methods, prefixed with `tag`. Lets a
-- module identify its own lines without every call site repeating the name.
function Log.forModule(tag)
    return {
        error = function(fmt, ...) emit("ERROR", tag, fmt, ...) end,
        warn = function(fmt, ...) emit("WARN", tag, fmt, ...) end,
        info = function(fmt, ...)
            if _G.DEBUG_MODE then emit("INFO", tag, fmt, ...) end
        end,
        debug = function(fmt, ...)
            if _G.DEBUG_MODE then emit("DEBUG", tag, fmt, ...) end
        end,
    }
end

-- Render a table as a readable string. Depth-capped rather than tracking
-- "seen" tables: depth strictly increases on every recursive call, so a
-- cyclic table still terminates -- it just bottoms out at the cap.
function Log.inspectTable(t, depth)
    if type(t) ~= "table" then
        return tostring(t)
    end

    depth = depth or 0
    local indent = string.rep("  ", depth)
    local result = "{\n"

    for k, v in pairs(t) do
        result = result .. indent .. "  "

        if type(k) == "string" then
            result = result .. k
        else
            result = result .. "[" .. tostring(k) .. "]"
        end

        result = result .. " = "

        if type(v) == "table" and depth < 3 then
            result = result .. Log.inspectTable(v, depth + 1)
        else
            result = result .. tostring(v)
        end

        result = result .. ",\n"
    end

    result = result .. indent .. "}"
    return result
end

-- Dump a table at debug level (a no-op unless _G.DEBUG_MODE is on).
function Log.dump(name, t)
    Log.debug("%s: %s", name, Log.inspectTable(t))
end

-- Time a function call and log its duration at debug level. Always runs
-- `func`; only the logging is gated.
function Log.timeFunction(name, func, ...)
    local startTime = love.timer.getTime()
    local result = { func(...) }
    local endTime = love.timer.getTime()

    Log.debug("%s execution time: %.6f seconds", name, endTime - startTime)
    return unpack(result)
end

return Log
