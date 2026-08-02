-- modules/util/fileManager.lua
-- A robust file management system to handle file operations safely.
--
-- init() is called by both main.lua and ConfigManager during boot; it is
-- idempotent so that doesn't repeat its directory bootstrap or its console
-- output on the second call.

local FileManager = {}

local Log = require("modules/util/debugHelper").forModule("FileManager")

local REQUIRED_DIRECTORIES = {
    "", -- root
    "config",
    "save",
    "data",
    "resources",
    "resources/sprites",
    "resources/fonts",
    "resources/sounds",
}

local initialized = false

-- Ensure a directory exists, creating it if necessary.
function FileManager.ensureDirectoryExists(dir)
    if dir == "" then return true end -- root always exists

    local info = love.filesystem.getInfo(dir)
    if info and info.type == "directory" then
        return true
    end

    local success = love.filesystem.createDirectory(dir)
    if not success then
        Log.warn("Failed to create directory: %s", dir)
    end
    return success
end

-- Initialize file system management. Safe to call more than once -- only the
-- first call does any work.
function FileManager.init()
    if initialized then return true end
    initialized = true

    Log.debug("Initializing file system at %s", love.filesystem.getSaveDirectory())

    for _, dir in ipairs(REQUIRED_DIRECTORIES) do
        FileManager.ensureDirectoryExists(dir)
    end

    local testFile = "save/test_write.tmp"
    local success = love.filesystem.write(testFile, "Testing write permissions")
    if success then
        love.filesystem.remove(testFile)
    else
        Log.warn("Cannot write files! Check permissions or storage space.")
    end

    return true
end

-- Safely save data to a file. Returns true on success, or false plus an
-- error message -- callers must not assume success just because this
-- returned without raising.
function FileManager.saveToFile(filepath, data)
    local directory = filepath:match("(.*)/")
    if directory and directory ~= "" then
        FileManager.ensureDirectoryExists(directory)
    end

    local ok, success, err = pcall(love.filesystem.write, filepath, data)
    if not ok then
        Log.warn("Write raised an error for %s: %s", filepath, tostring(success))
        return false, tostring(success)
    end
    if not success then
        Log.warn("Failed to write %s: %s", filepath, tostring(err))
        return false, err or "write failed"
    end

    Log.debug("Saved %s", filepath)
    return true
end

-- Safely load data from a file.
function FileManager.loadFromFile(filepath)
    if not love.filesystem.getInfo(filepath) then
        Log.debug("File does not exist: %s", filepath)
        return nil, "File not found"
    end

    local ok, result = pcall(love.filesystem.read, filepath)
    if not ok or not result then
        Log.warn("Failed to load file %s: %s", filepath, tostring(result))
        return nil, "Failed to read file"
    end

    Log.debug("Loaded %s (%d bytes)", filepath, #result)
    return result
end

-- Get a list of files (not subdirectories) in a directory.
function FileManager.getFilesInDirectory(directory)
    directory = directory or ""

    local files = {}
    if love.filesystem.getInfo(directory) then
        local items = love.filesystem.getDirectoryItems(directory)
        for _, item in ipairs(items) do
            local path = directory == "" and item or directory .. "/" .. item
            local info = love.filesystem.getInfo(path)
            if info and info.type == "file" then
                table.insert(files, path)
            end
        end
    end

    return files
end

-- On-demand debug dump of the save directory layout. Callers are expected to
-- gate this behind _G.DEBUG_MODE themselves; it also only prints when
-- DEBUG_MODE is on since it goes through Log.info.
function FileManager.printFileSystemInfo()
    Log.info("=== File System Information ===")
    Log.info("Save directory: %s", love.filesystem.getSaveDirectory())
    Log.info("Identity: %s", love.filesystem.getIdentity() or "default")
    Log.info("Working directory: %s", love.filesystem.getWorkingDirectory())

    for _, dir in ipairs({ "", "config", "save", "data" }) do
        local label = dir == "" and "root" or dir
        local items = love.filesystem.getDirectoryItems(dir)
        if #items == 0 then
            Log.info("%s: (empty)", label)
        else
            for _, item in ipairs(items) do
                local path = dir == "" and item or dir .. "/" .. item
                local info = love.filesystem.getInfo(path)
                Log.info("%s: %s (%s)", label, item, info and info.type or "unknown")
            end
        end
    end
end

return FileManager
