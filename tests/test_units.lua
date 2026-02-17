-- Unit Tests for Game_Context_Scanner.lua
_G.SCANNER_TEST_MODE = true

print("Loading mocks...")
local mock = dofile("tests/mock_roblox.lua")

print("Loading scanner...")
local scanner = dofile("Game_Context_Scanner.lua")

local passed = 0
local failed = 0

local function assert_equal(expected, actual, msg)
    if expected ~= actual then
        print("FAIL: " .. (msg or "") .. " Expected '" .. tostring(expected) .. "', got '" .. tostring(actual) .. "'")
        failed = failed + 1
    else
        passed = passed + 1
    end
end

local function assert_match(pattern, actual, msg)
    if not actual then
        print("FAIL: " .. (msg or "") .. " Got nil, expected pattern '" .. pattern .. "'")
        failed = failed + 1
        return
    end
    if not string.match(tostring(actual), pattern) then
        print("FAIL: " .. (msg or "") .. " Expected pattern '" .. pattern .. "', got '" .. tostring(actual) .. "'")
        failed = failed + 1
    else
        passed = passed + 1
    end
end

print("Running Unit Tests...")

-- Test sanitize
if scanner.sanitize then
    print("Testing sanitize...")
    assert_equal("foo\\nbar", scanner.sanitize("foo\nbar"), "Newline escape")
    assert_equal("foo\\rbar", scanner.sanitize("foo\rbar"), "Carriage return escape")
    assert_equal("nil", scanner.sanitize(nil), "Nil handling")
else
    print("FAIL: sanitize function not exported")
    failed = failed + 1
end

-- Test should_ignore
if scanner.should_ignore then
    print("Testing should_ignore...")
    local ignoredObj = { Name = "ChatScript" }
    local validObj = { Name = "MyScript" }

    assert_equal(true, scanner.should_ignore(ignoredObj), "Should ignore ChatScript")
    assert_equal(false, scanner.should_ignore(validObj), "Should not ignore MyScript")
    assert_equal(true, scanner.should_ignore(nil), "Should ignore nil")
else
    print("FAIL: should_ignore function not exported")
    failed = failed + 1
end

-- Test get_properties_string
if scanner.get_properties_string then
    print("Testing get_properties_string...")

    -- Test Part
    local part = mock.create_instance("Part", "TestPart")

    -- Patch IsA for inheritance mock
    local oldIsA = part.IsA
    function part:IsA(className)
        if className == "BasePart" then return true end
        return oldIsA(self, className)
    end

    part.Transparency = 1
    part.Size = "1, 1, 1"
    part.CanCollide = true
    part.Position = "0, 10, 0"

    local props = scanner.get_properties_string(part)
    assert_match("Transparency: 1", props, "Part transparency check")

    -- Test Tool
    local tool = mock.create_instance("Tool", "Sword")
    tool.Enabled = true
    tool.ToolTip = "A sharp sword"
    tool.TextureId = ""
    tool.Grip = "0,0,0,1,0,0,0,1,0,0,0,1"

    local toolProps = scanner.get_properties_string(tool)
    assert_match("ToolTip: A sharp sword", toolProps, "Tool tooltip check")

    -- Test StringValue
    local sv = mock.create_instance("StringValue", "Status")
    sv.Value = "Ready"
    local svProps = scanner.get_properties_string(sv)
    assert_match("Value: Ready", svProps, "StringValue check")
else
    print("FAIL: get_properties_string function not exported")
    failed = failed + 1
end

-- Test generate_tree_map
if scanner.generate_tree_map then
    print("Testing generate_tree_map...")
    local root = mock.create_instance("Folder", "Root")
    local child1 = mock.create_instance("Part", "Child1", root)
    local child3 = mock.create_instance("LocalScript", "ClientScript", root)

    local tree = scanner.generate_tree_map(root)
    assert_match("ClientScript %[SCRIPT%]", tree, "Tree map includes script")
else
    print("FAIL: generate_tree_map function not exported")
    failed = failed + 1
end

print("\nTest Summary: " .. passed .. " passed, " .. failed .. " failed.")

if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
