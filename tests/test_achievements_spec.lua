-- Keeps the Steamworks achievement reference synchronized with gameplay code.
-- docs/ is intentionally absent from packaged .love builds, so that environment
-- skips this source-tree-only guard.

local H = require("tests/helpers")

local T = {}

local function collectLuaFiles(path, files)
    files = files or {}

    for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
        local child = path .. "/" .. item
        local info = love.filesystem.getInfo(child)

        if info and info.type == "directory" then
            collectLuaFiles(child, files)
        elseif info and info.type == "file" and item:match("%.lua$") then
            files[#files + 1] = child
        end
    end

    return files
end

local function readGameplaySources()
    local chunks = {}

    for _, root in ipairs({ "modules", "states" }) do
        for _, path in ipairs(collectLuaFiles(root)) do
            local contents = love.filesystem.read(path)
            H.isTrue(contents ~= nil, "could not read gameplay source " .. path)
            chunks[#chunks + 1] = contents
        end
    end

    return table.concat(chunks, "\n")
end

function T.documented_achievement_ids_match_heading_and_gameplay_call_sites()
    local docPath = "docs/ACHIEVEMENTS.md"
    if not love.filesystem.getInfo(docPath) then
        print("  SKIP: docs/ACHIEVEMENTS.md is absent from this packaged build")
        return
    end

    local doc = love.filesystem.read(docPath)
    H.isTrue(doc ~= nil, "could not read " .. docPath)

    local ids = {}
    for line in doc:gmatch("[^\r\n]+") do
        local id = line:match("^|%s*`([A-Z][A-Z0-9_]*)`%s*|")
        if id then ids[#ids + 1] = id end
    end

    H.isTrue(#ids >= 25,
        "achievement table parse returned fewer than 25 ids: " .. tostring(#ids))

    local gameplaySources = readGameplaySources()
    local missing = {}
    for _, id in ipairs(ids) do
        local doubleQuoted = 'unlockAchievement("' .. id .. '")'
        local singleQuoted = "unlockAchievement('" .. id .. "')"
        if not gameplaySources:find(doubleQuoted, 1, true)
            and not gameplaySources:find(singleQuoted, 1, true) then
            missing[#missing + 1] = id
        end
    end

    H.equal(#missing, 0,
        "documented achievement ids missing gameplay call sites: " .. table.concat(missing, ", "))

    local headingCount = tonumber(doc:match("## The list %((%d+)%)"))
    H.isTrue(headingCount ~= nil, "missing achievement list count heading")
    H.equal(headingCount, #ids, "achievement heading count must match table row count")
end

return T
