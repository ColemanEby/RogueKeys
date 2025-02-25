-- modules/util/debugHelper.lua
-- Debugging utilities to help troubleshoot issues

local DebugHelper = {}

-- Debug logging levels
DebugHelper.LOG_LEVELS = {
    ERROR = 1,
    WARNING = 2,
    INFO = 3,
    DEBUG = 4
}

-- Current log level (change to adjust verbosity)
DebugHelper.currentLogLevel = DebugHelper.LOG_LEVELS.DEBUG

-- Enable/disable debug features
DebugHelper.enabled = true
DebugHelper.drawStats = true

-- Log a message at a specific level
function DebugHelper.log(level, message, ...)
    if not DebugHelper.enabled then return end

    -- Only log if the current level is high enough
    if level <= DebugHelper.currentLogLevel then
        local prefix = "[INFO] "
        if level == DebugHelper.LOG_LEVELS.ERROR then
            prefix = "[ERROR] "
        elseif level == DebugHelper.LOG_LEVELS.WARNING then
            prefix = "[WARNING] "
        elseif level == DebugHelper.LOG_LEVELS.DEBUG then
            prefix = "[DEBUG] "
        end

        -- Format the message with any additional arguments
        local formattedMessage = message
        if ... then
            formattedMessage = string.format(message, ...)
        end

        print(prefix .. formattedMessage)
    end
end

-- Shortcut functions for different log levels
function DebugHelper.error(message, ...)
    DebugHelper.log(DebugHelper.LOG_LEVELS.ERROR, message, ...)
end

function DebugHelper.warning(message, ...)
    DebugHelper.log(DebugHelper.LOG_LEVELS.WARNING, message, ...)
end

function DebugHelper.info(message, ...)
    DebugHelper.log(DebugHelper.LOG_LEVELS.INFO, message, ...)
end

function DebugHelper.debug(message, ...)
    DebugHelper.log(DebugHelper.LOG_LEVELS.DEBUG, message, ...)
end

-- Draw debug information on screen
function DebugHelper.drawDebugInfo()
    if not DebugHelper.enabled or not DebugHelper.drawStats then return end

    local stats = {
        "FPS: " .. love.timer.getFPS(),
        "Memory: " .. string.format("%.2f MB", collectgarbage("count") / 1024),
        "Dimensions: " .. love.graphics.getWidth() .. "x" .. love.graphics.getHeight()
    }

    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 200, 15 * #stats + 10)

    -- Draw stats text
    love.graphics.setColor(1, 1, 1, 1)
    for i, stat in ipairs(stats) do
        love.graphics.print(stat, 20, 10 + (i-1) * 15)
    end
end

-- Inspect a table and return a string representation
function DebugHelper.inspectTable(t, depth)
    if type(t) ~= "table" then
        return tostring(t)
    end

    depth = depth or 0
    local indent = string.rep("  ", depth)
    local result = "{\n"

    for k, v in pairs(t) do
        result = result .. indent .. "  "

        -- Format the key
        if type(k) == "string" then
            result = result .. k
        else
            result = result .. "[" .. tostring(k) .. "]"
        end

        result = result .. " = "

        -- Format the value
        if type(v) == "table" and depth < 3 then
            result = result .. DebugHelper.inspectTable(v, depth + 1)
        else
            result = result .. tostring(v)
        end

        result = result .. ",\n"
    end

    result = result .. indent .. "}"
    return result
end

-- Dump a table to the console for inspection
function DebugHelper.dump(name, t)
    DebugHelper.debug("%s: %s", name, DebugHelper.inspectTable(t))
end

-- Track function execution time
function DebugHelper.timeFunction(name, func, ...)
    local startTime = love.timer.getTime()
    local result = {func(...)}
    local endTime = love.timer.getTime()

    DebugHelper.debug("%s execution time: %.6f seconds", name, endTime - startTime)
    return unpack(result)
end

return DebugHelper