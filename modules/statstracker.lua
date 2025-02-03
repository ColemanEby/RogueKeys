-- modules/statstracker.lua
local StatTracker = {}

local stats = {
    totalSessions = 0,
    totalKeystrokes = 0,
    totalMistakes = 0,
    totalCorrect = 0,
    totalTime = 0,
    bestAPM = 0,
    bestAccuracy = 0,
    bestStreak = 0,
    roundsWithoutError = 0,
}

local filename = "stats.txt"

-- Load stats from the file if it exists.
function StatTracker.load()
    if love.filesystem.getInfo(filename) then
        local contents = love.filesystem.read(filename)
        for line in contents:gmatch("[^\r\n]+") do
            local key, value = line:match("^(%w+)=(%d+%.?%d*)$")
            if key and value then
                stats[key] = tonumber(value)
            end
        end
    end
end

-- Save the stats table to file.
local function saveStats()
    local lines = {}
    for k, v in pairs(stats) do
        table.insert(lines, k .. "=" .. tostring(v))
    end
    love.filesystem.write(filename, table.concat(lines, "\n"))
end

-- Record a session’s stats.
-- session is a table with:
--   keystrokes, mistakes, correct, time, apm, accuracy, longestStreak
function StatTracker.recordSession(session)
    stats.totalSessions = stats.totalSessions + 1
    stats.totalKeystrokes = stats.totalKeystrokes + session.keystrokes
    stats.totalMistakes = stats.totalMistakes + session.mistakes
    stats.totalCorrect = stats.totalCorrect + session.correct
    stats.totalTime = stats.totalTime + session.time
    if session.apm > stats.bestAPM then stats.bestAPM = session.apm end
    if session.accuracy > stats.bestAccuracy then stats.bestAccuracy = session.accuracy end
    if session.longestStreak > stats.bestStreak then stats.bestStreak = session.longestStreak end
    if session.mistakes == 0 then stats.roundsWithoutError = stats.roundsWithoutError + 1 end

    saveStats()
end

function StatTracker.getStats()
    return stats
end

return StatTracker
