-- tests/test_helper.lua
-- Common setup for tests

-- Load mocks
local mock = dofile("tests/mock_roblox.lua")

-- Helper function to load the scanner script
-- Returns the module exported by the scanner
local function load_scanner()
    local f = io.open("Game_Context_Scanner.lua", "r")
    if not f then error("Could not open Game_Context_Scanner.lua") end
    local content = f:read("*a")
    f:close()

    local func, err = (loadstring or load)(content, "@Game_Context_Scanner.lua")
    if not func then error("Could not load Game_Context_Scanner.lua: " .. tostring(err)) end

    -- Execute with true to enable test mode
    return func(true)
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
