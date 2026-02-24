-- tests/test_helper.lua
-- Common setup for tests

-- Set test mode to prevent immediate execution of the scanner
_G.SCANNER_TEST_MODE = true

-- Load mocks
local mock = dofile("tests/mock_roblox.lua")

-- Helper function to load the scanner script
-- Returns the module exported by the scanner
local function load_scanner()
    return dofile("Game_Context_Scanner.lua")
end

-- Export shared resources
return {
    mock = mock,
    load_scanner = load_scanner,
    -- Convenience accessors
    game = game,
    players = game:GetService("Players"),
    localPlayer = game:GetService("Players").LocalPlayer
}
