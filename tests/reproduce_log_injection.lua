-- Reproduction script for Log Injection
_G.SCANNER_TEST_MODE = true

local mock = dofile("tests/mock_roblox.lua")
local scanner = dofile("Game_Context_Scanner.lua")

-- Mock Players and LocalPlayer
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer

-- 1. Exploit via Workspace renaming (Top-level service)
local ws = game:GetService("Workspace")
ws.Name = "Workspace\n[INJECTED_SERVICE] Fake Service Entry"

-- 2. Exploit via Child Object (should be handled by recursive scan)
local maliciousChild = mock.create_instance("Part", "MaliciousPart\n[INJECTED_CHILD] Fake Child Entry", ws)

print("Running scanner with malicious names...")
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
        if content:find("\n%[INJECTED_SERVICE%]") then
            print("\nVULNERABILITY CONFIRMED: Log injection via Service Name!")
            failed = true
        else
            print("\nPASS: Service Name sanitized.")
        end

        if content:find("\n%[INJECTED_CHILD%]") then
            print("\nVULNERABILITY CONFIRMED: Log injection via Child Name!")
            failed = true
        else
            print("\nPASS: Child Name sanitized.")
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
