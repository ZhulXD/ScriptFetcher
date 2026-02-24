-- Reproduction script for Synchronous Scanning DoS
local helper = dofile("tests/test_helper.lua")
local mock = helper.mock

-- Mock task.wait to track calls
local wait_count = 0
task.wait = function(n)
    wait_count = wait_count + 1
end

local scanner = helper.load_scanner()

-- Create a large hierarchy
local rs = helper.game:GetService("ReplicatedStorage")
local current = rs
for i = 1, 100 do
    current = mock.create_instance("Folder", "Folder" .. i, current)
end

print("Starting deep scan...")
scanner.execute_full_scan()
print("Deep scan finished. task.wait called " .. wait_count .. " times.")

if wait_count == 0 then
    print("VULNERABILITY CONFIRMED: No task.wait() calls during deep scan of large tree.")
else
    print("Vulnerability not present or already fixed. task.wait() called " .. wait_count .. " times.")
end
