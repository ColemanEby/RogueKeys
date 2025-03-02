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
    
    -- Test write permissions
    local testFile = "save/test_write.tmp"
    local success = love.filesystem.write(testFile, "Testing write permissions")
    if success then
        love.filesystem.remove(testFile)
        print("FileManager: Write permissions confirmed")
    else
        print("FileManager: WARNING - Cannot write files! Check permissions or storage space.")
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
    if directory and directory ~= "" then
        FileManager.ensureDirectoryExists(directory)
    end
    
    -- Try to save the file
    print("FileManager: Attempting to save to file: " .. filepath)
    
    -- First attempt: standard LÖVE write
    local success, message = pcall(function()
        return love.filesystem.write(filepath, data)
    end)
    
    if not success or not message then
        print("FileManager: Standard write failed: " .. tostring(message))
        
        -- Second attempt: try write with binary flag
        success, message = pcall(function()
            return love.filesystem.write(filepath, data, #data)
        end)
        
        if not success or not message then
            print("FileManager: Binary write failed: " .. tostring(message))
            return false, "Failed to write file"
        end
    end
    
    print("FileManager: Successfully saved file: " .. filepath)
    return true
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
    local content, size = nil, 0
    
    local success, result = pcall(function()
        return love.filesystem.read(filepath)
    end)
    
    if success and result then
        content, size = result, #result
    else
        print("FileManager: FAILED to load file " .. filepath .. ": " .. tostring(result))
        return nil, "Failed to read file"
    end
    
    print("FileManager: Successfully loaded file: " .. filepath .. " (" .. size .. " bytes)")
    return content
end

-- Check if file exists and is writable
function FileManager.isFileWritable(filepath)
    -- Test by attempting to write
    local success = love.filesystem.write(filepath, "test")
    if success then
        -- Clean up
        love.filesystem.remove(filepath)
        return true
    end
    return false
end

-- Get a list of files in a directory
function FileManager.getFilesInDirectory(directory)
    if not directory or directory == "" then
        directory = ""
    end
    
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