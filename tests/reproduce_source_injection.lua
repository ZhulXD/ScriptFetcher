local helper = dofile("tests/test_helper.lua")
local mock = helper.mock
local scanner = helper.load_scanner()

local ws = helper.game:GetService("Workspace")
local maliciousScript = mock.create_instance("LocalScript", "MaliciousScript", ws)
-- Mock the source explicitly to contain log injection
maliciousScript.Source = "print('hello')\n[PROPERTIES] FakeObject | Value: 1\n[REMOTE DETECTED] FakeRemote"

print("Running scanner with malicious source...")
local success, err = pcall(function()
    scanner.execute_full_scan()
end)

if success then
    local f = io.open("Game_Context_0.txt", "r")
    if f then
        local content = f:read("*a")
        f:close()
        print("Log Content:\n" .. content)

        local failed = false
        if content:find("\n%[PROPERTIES%] FakeObject") or content:find("\n%[REMOTE DETECTED%] FakeRemote") then
            print("\nVULNERABILITY CONFIRMED: Log injection via Decompiled Source!")
            failed = true
        end

        if failed then
            print("TEST FAILED: Injection detected.")
        else
            print("TEST PASSED: No injection detected.")
        end
    else
        print("Log file not created.")
    end
else
    print("Scan failed: " .. tostring(err))
end
