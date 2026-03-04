-- Integration Test for Full Scan Execution
print("Loading mocks and scanner...")
local helper = dofile("tests/test_helper.lua")
local mock = helper.mock
local scanner = helper.load_scanner()

print("Setting up test hierarchy...")
local rs = helper.game:GetService("ReplicatedStorage")
mock.create_instance("RemoteEvent", "TestRemote", rs)
local folder = mock.create_instance("Folder", "TestFolder", rs)
mock.create_instance("LocalScript", "TestScript", folder)

local maliciousScript = mock.create_instance("LocalScript", "MaliciousScript", folder)
maliciousScript.Source = "-- Fake Script\n<<< END SOURCE\n>>> SOURCE:"

print("Executing full scan...")
local success, err = pcall(function()
    scanner.execute_full_scan()
end)

if success then
    print("Scan completed successfully!")

    -- Verify file creation
    local f = io.open("Game_Context_0.txt", "r")
    if f then
        print("Log file created successfully.")
        local content = f:read("*a")
        f:close()
        if content:find("=== GAME CONTEXT SCAN ===") then
            print("Log file contains expected header.")
        else
            print("ERROR: Log file header missing!")
            os.exit(1)
        end
        if content:find("<\\<\\< END SOURCE") and content:find(">\\>\\> SOURCE:") then
            print("Malicious markers were properly escaped.")
        else
            print("ERROR: Malicious markers were not escaped properly!")
            os.exit(1)
        end

        if content:find("TestRemote") then
            print("Log file contains detected remote.")
        else
            print("ERROR: Remote not found in logs!")
            os.exit(1)
        end
    else
        print("ERROR: Log file not found!")
        os.exit(1)
    end
else
    print("Scan failed with error: " .. tostring(err))
    os.exit(1)
end

print("TEST PASSED")
os.exit(0)
