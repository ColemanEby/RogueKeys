-- modules/util/fileManager.lua
-- A robust file management system to handle file operations safely

local FileManager = {}

-- Initialize file system management
function FileManager.init()
    print("FileManager: Initializing file system")
    
    -- Get save directory
    local saveDir = love.filesystem.getSaveDirectory()
    print("FileManager: Save directory is " .. saveDir)
    
    -- List of required directories
    local directories = {
        "", -- Root directory
        "config",
        "save",
        "data",
        "resources",
        "resources/sprites",
        "resources/fonts",
        "resources/sounds"
    }
    
    -- Ensure all directories exist
    for _, dir in ipairs(directories) do
        FileManager.ensureDirectoryExists(dir)
    end
    
    return true
end

-- Ensure a directory exists, creating it if necessary
function FileManager.ensureDirectoryExists(dir)
    if dir == "" then return true end -- Root directory
    
    local info = love.filesystem.getInfo(dir)
    if info and info.type == "directory" then
        print("FileManager: Directory exists: " .. dir)
        return true
    end
    
    print("FileManager: Creating directory: " .. dir)
    local success = love.filesystem.createDirectory(dir)
    if not success then
        print("FileManager: FAILED to create directory: " .. dir)
    end
    return success
end

-- Safely save data to a file
function FileManager.saveToFile(filepath, data)
    -- Make sure the directory exists
    local directory = filepath:match("(.*)/")
    if directory then
        FileManager.ensureDirectoryExists(directory)
    end
    
    -- Try to save the file
    print("FileManager: Saving to file: " .. filepath)
    local success, message = love.filesystem.write(filepath, data)
    
    if not success then
        print("FileManager: FAILED to save file " .. filepath .. ": " .. tostring(message))
    else
        print("FileManager: Successfully saved file: " .. filepath)
    end
    
    return success, message
end

-- Safely load data from a file
function FileManager.loadFromFile(filepath)
    -- Check if file exists
    local info = love.filesystem.getInfo(filepath)
    if not info then
        print("FileManager: File does not exist: " .. filepath)
        return nil, "File not found"
    end
    
    -- Try to load the file
    print("FileManager: Loading file: " .. filepath)
    local content, size = love.filesystem.read(filepath)
    
    if not content then
        print("FileManager: FAILED to load file " .. filepath)
        return nil, "Failed to read file"
    end
    
    print("FileManager: Successfully loaded file: " .. filepath .. " (" .. size .. " bytes)")
    return content
end

-- Debug function to print out file system information
function FileManager.printFileSystemInfo()
    print("\n=== File System Information ===")
    print("Save directory: " .. love.filesystem.getSaveDirectory())
    print("Identity: " .. (love.filesystem.getIdentity() or "default"))
    print("Working directory: " .. love.filesystem.getWorkingDirectory())
    
    -- List files in key directories
    local directories = {"", "config", "save", "data"}
    for _, dir in ipairs(directories) do
        print("\nFiles in '" .. (dir == "" and "root" or dir) .. "':")
        local items = love.filesystem.getDirectoryItems(dir)
        if #items == 0 then
            print("  (empty)")
        else
            for _, item in ipairs(items) do
                local path = dir == "" and item or dir .. "/" .. item
                local info = love.filesystem.getInfo(path)
                local type = info and info.type or "unknown"
                print("  " .. item .. " (" .. type .. ")")
            end
        end
    end
    print("===========================\n")
end

return FileManager