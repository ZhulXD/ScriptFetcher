-- Reproduction script for Synchronous Scanning DoS
_G.SCANNER_TEST_MODE = true
local mock = dofile("tests/mock_roblox.lua")

-- Mock task.wait to track calls
local wait_count = 0
task.wait = function(n)
    wait_count = wait_count + 1
end

local scanner = dofile("Game_Context_Scanner.lua")

-- Create a large hierarchy
local rs = game:GetService("ReplicatedStorage")
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
