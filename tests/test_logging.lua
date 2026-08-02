-- tests/test_logging.lua
-- Coverage for the leveled logger in modules/util/debugHelper.lua, and for
-- the file-write honesty and save-file safety fixes in this unit.

local H = require("tests/helpers")

local Log = require("modules/util/debugHelper")
local FileManager = require("modules/util/fileManager")
local StatVerifier = require("modules/util/statVerifier")

local T = {}

-- Capture output via an injected sink instead of monkeypatching `print`.
local function captureLines(fn)
    local lines = {}
    Log.setSink(function(line) lines[#lines + 1] = line end)
    local ok, err = pcall(fn)
    Log.setSink(print)
    if not ok then error(err, 0) end
    return lines
end

function T.debug_and_info_are_suppressed_when_debug_mode_is_off()
    local previous = _G.DEBUG_MODE
    _G.DEBUG_MODE = false

    local lines = captureLines(function()
        Log.debug("should not appear")
        Log.info("should not appear either")
    end)

    _G.DEBUG_MODE = previous
    H.equal(#lines, 0, "debug/info must be silent when DEBUG_MODE is off")
end

function T.debug_and_info_emit_when_debug_mode_is_on()
    local previous = _G.DEBUG_MODE
    _G.DEBUG_MODE = true

    local lines = captureLines(function()
        Log.debug("debug line")
        Log.info("info line")
    end)

    _G.DEBUG_MODE = previous
    H.equal(#lines, 2)
    H.isTrue(lines[1]:find("DEBUG", 1, true) ~= nil, "expected a DEBUG tag")
    H.isTrue(lines[2]:find("INFO", 1, true) ~= nil, "expected an INFO tag")
end

function T.warn_and_error_always_emit_regardless_of_debug_mode()
    local previous = _G.DEBUG_MODE
    _G.DEBUG_MODE = false

    local lines = captureLines(function()
        Log.warn("a warning")
        Log.error("an error")
    end)

    _G.DEBUG_MODE = previous
    H.equal(#lines, 2, "warn/error must never be suppressed")
    H.isTrue(lines[1]:find("WARN", 1, true) ~= nil)
    H.isTrue(lines[2]:find("ERROR", 1, true) ~= nil)
end

function T.for_module_tags_every_line()
    local log = Log.forModule("Widget")
    local lines = captureLines(function()
        log.warn("careful")
    end)

    H.equal(#lines, 1)
    H.isTrue(lines[1]:find("[Widget]", 1, true) ~= nil, "expected the module tag in the line")
end

function T.format_arguments_are_applied()
    local lines = captureLines(function()
        Log.warn("count=%d name=%s", 3, "keycap")
    end)

    H.isTrue(lines[1]:find("count=3 name=keycap", 1, true) ~= nil)
end

function T.malformed_format_string_does_not_raise()
    -- A stray %s with no argument must not crash the caller.
    H.succeeds(function()
        captureLines(function() Log.warn("bad format %s %s", "only-one") end)
    end)
end

function T.inspect_table_handles_nested_tables()
    local nested = { a = 1, b = { c = 2, d = { e = 3 } } }
    local text = H.succeeds(function() return Log.inspectTable(nested) end)
    H.isTrue(text:find("a", 1, true) ~= nil)
    H.isTrue(text:find("c", 1, true) ~= nil)
end

function T.inspect_table_handles_cycles_without_looping_forever()
    local cyclic = {}
    cyclic.self = cyclic
    H.succeeds(function() return Log.inspectTable(cyclic) end)
end

function T.inspect_table_handles_nil()
    H.equal(Log.inspectTable(nil), "nil")
end

function T.dump_does_not_raise_either_way_of_debug_mode()
    local previous = _G.DEBUG_MODE

    _G.DEBUG_MODE = false
    H.succeeds(function() Log.dump("thing", { x = 1 }) end)

    _G.DEBUG_MODE = true
    H.succeeds(function() Log.dump("thing", { x = 1 }) end)

    _G.DEBUG_MODE = previous
end

function T.filemanager_savetofile_reports_genuine_failure()
    -- "save" is a directory (FileManager creates it on init). Writing a file
    -- *to* that same path must fail, and saveToFile must report that
    -- honestly instead of returning true.
    FileManager.ensureDirectoryExists("save")
    local ok, err = FileManager.saveToFile("save", "this should not write")
    H.isFalse(ok, "writing over an existing directory must fail")
    H.isTrue(err ~= nil, "a failed save should explain why")
end

function T.filemanager_savetofile_reports_genuine_success()
    local ok = FileManager.saveToFile("save/test_logging_roundtrip.tmp", "hello")
    H.isTrue(ok)
    H.equal(FileManager.loadFromFile("save/test_logging_roundtrip.tmp"), "hello")
    love.filesystem.remove("save/test_logging_roundtrip.tmp")
end

function T.statverifier_never_writes_the_real_save_file()
    local path = "save/player.lua"
    local existedBefore = love.filesystem.getInfo(path) ~= nil
    local contentBefore = existedBefore and love.filesystem.read(path) or nil

    H.succeeds(function() StatVerifier.runIntegrationTest() end)

    local existedAfter = love.filesystem.getInfo(path) ~= nil
    H.equal(existedAfter, existedBefore, "StatVerifier must not create or delete save/player.lua")

    if existedBefore then
        H.equal(love.filesystem.read(path), contentBefore, "StatVerifier must not modify save/player.lua")
    end
end

return T
