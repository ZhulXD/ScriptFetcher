-- tests/test_file_error_handling.lua
local helper = dofile("tests/test_helper.lua")

-- Override file functions to simulate failure
function writefile(f, c) error("writefile failed") end
function appendfile(f, c) error("appendfile failed") end

print("Loading scanner...")
local status, result = pcall(helper.load_scanner)

if not status then
    print("FAILURE: Script crashed on load (top-level writefile?): " .. tostring(result))
    os.exit(1)
end

local scanner = result

print("Executing scan...")
local scan_status, scan_err = pcall(function()
    scanner.execute_full_scan()
end)

if not scan_status then
    print("FAILURE: execute_full_scan crashed: " .. tostring(scan_err))
    os.exit(1)
end

print("SUCCESS: Handled errors.")
