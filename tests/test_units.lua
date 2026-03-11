-- Unit Tests for Game_Context_Scanner.lua
print("Loading mocks and scanner...")
local helper = dofile("tests/test_helper.lua")
local mock = helper.mock
local scanner = helper.load_scanner()

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
    -- Lua pattern matching. Escape special chars if needed in pattern.
    if not string.match(tostring(actual), pattern) then
        print("FAIL: " .. (msg or "") .. " Expected pattern '" .. pattern .. "', got '" .. tostring(actual) .. "'")
        failed = failed + 1
    else
        passed = passed + 1
    end
end

local function assert_nil(actual, msg)
    if actual ~= nil then
        print("FAIL: " .. (msg or "") .. " Expected nil, got '" .. tostring(actual) .. "'")
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

    -- 1. Default behavior (nil ignore_list)
    assert_equal(true, scanner.should_ignore(ignoredObj), "Should ignore ChatScript (default)")
    assert_equal(false, scanner.should_ignore(validObj), "Should not ignore MyScript (default)")
    assert_equal(true, scanner.should_ignore(nil), "Should ignore nil")

    -- 2. Custom ignore list
    local customIgnore = { ["MyScript"] = true }
    assert_equal(true, scanner.should_ignore(validObj, customIgnore), "Should ignore MyScript with custom list")
    assert_equal(false, scanner.should_ignore(ignoredObj, customIgnore), "Should NOT ignore ChatScript with custom list (override)")
else
    print("FAIL: should_ignore function not exported")
    failed = failed + 1
end

-- Test get_properties_string
if scanner.get_properties_string then
    print("Testing get_properties_string...")

    -- 1. BasePart (Standard)
    local part = mock.create_instance("Part", "TestPart")
    part.Transparency = 1
    part.Size = "1, 1, 1"
    part.CanCollide = true
    part.Position = "0, 10, 0"
    local props = scanner.get_properties_string(part)
    assert_match("Transparency: 1", props, "Part transparency check")

    -- 2. BasePart (Seat)
    local seat = mock.create_instance("Seat", "PilotSeat")
    seat.Disabled = false
    -- Mock occupant
    local occupant = mock.create_instance("Humanoid", "Pilot", mock.create_instance("Model", "Character"))
    seat.Occupant = occupant
    local seatProps = scanner.get_properties_string(seat)
    assert_match("Occupant: Character%.Pilot", seatProps, "Seat occupant check")
    assert_match("Disabled: false", seatProps, "Seat disabled check")

    -- 3. BasePart (VehicleSeat)
    local vSeat = mock.create_instance("VehicleSeat", "DriverSeat")
    vSeat.Disabled = true
    local vSeatProps = scanner.get_properties_string(vSeat)
    assert_match("Disabled: true", vSeatProps, "VehicleSeat disabled check")

    -- 4. BasePart Filtering Logic
    local handle = mock.create_instance("Part", "Handle")
    handle.Transparency = 0 -- Need to set default values
    handle.Size = "1,1,1"
    handle.CanCollide = true
    handle.Position = "0,0,0"
    assert_match("Size:", scanner.get_properties_string(handle), "Should log Handle")

    local hitbox = mock.create_instance("Part", "HitboxPart")
    hitbox.Transparency = 0
    hitbox.Size = "1,1,1"
    hitbox.CanCollide = false
    hitbox.Position = "0,0,0"
    assert_match("Size:", scanner.get_properties_string(hitbox), "Should log Hitbox")

    local root = mock.create_instance("Part", "HumanoidRootPart")
    root.Transparency = 0
    root.Size = "2,2,1"
    root.CanCollide = false
    root.Position = "0,5,0"
    assert_match("Size:", scanner.get_properties_string(root), "Should log Root")

    local ignoredPart = mock.create_instance("Part", "Wall")
    ignoredPart.Transparency = 0
    assert_nil(scanner.get_properties_string(ignoredPart), "Should ignore generic part")

    -- 5. Tool
    local tool = mock.create_instance("Tool", "Sword")
    tool.Enabled = true
    tool.ToolTip = "A sharp sword"
    tool.TextureId = "rbxassetid://123"
    tool.Grip = "0,0,0,1,0,0,0,1,0,0,0,1"
    local toolProps = scanner.get_properties_string(tool)
    assert_match("ToolTip: A sharp sword", toolProps, "Tool tooltip check")
    assert_match("TextureId: rbxassetid://123", toolProps, "Tool texture check")

    -- 6. ProximityPrompt
    local prompt = mock.create_instance("ProximityPrompt", "Interact")
    prompt.ActionText = "Pick Up"
    prompt.ObjectText = "Apple"
    prompt.HoldDuration = 0.5
    prompt.KeyboardKeyCode = "Enum.KeyCode.E"
    local promptProps = scanner.get_properties_string(prompt)
    assert_match("ActionText: Pick Up", promptProps, "Prompt ActionText check")
    assert_match("KeyCode: Enum%.KeyCode%.E", promptProps, "Prompt KeyCode check")

    -- 7. Humanoid
    local human = mock.create_instance("Humanoid", "Humanoid")
    human.Health = 100
    human.MaxHealth = 100
    human.WalkSpeed = 16
    human.JumpPower = 50
    human.RigType = "Enum.HumanoidRigType.R15"
    local humanProps = scanner.get_properties_string(human)
    assert_match("Health: 100", humanProps, "Humanoid Health check")
    assert_match("RigType: Enum%.HumanoidRigType%.R15", humanProps, "Humanoid RigType check")

    -- 8. ClickDetector
    local cd = mock.create_instance("ClickDetector", "Click")
    cd.MaxActivationDistance = 32
    local cdProps = scanner.get_properties_string(cd)
    assert_match("MaxActivationDistance: 32", cdProps, "ClickDetector check")

    -- 9. Value Types
    local intVal = mock.create_instance("IntValue", "Coins")
    intVal.Value = 50
    assert_match("Value: 50", scanner.get_properties_string(intVal), "IntValue check")

    local boolVal = mock.create_instance("BoolValue", "IsActive")
    boolVal.Value = true
    assert_match("Value: true", scanner.get_properties_string(boolVal), "BoolValue check")

    local stringVal = mock.create_instance("StringValue", "Message")
    stringVal.Value = "Hello\nWorld"
    assert_match("Value: Hello\\nWorld", scanner.get_properties_string(stringVal), "StringValue check with newline")

    local numberVal = mock.create_instance("NumberValue", "Health")
    numberVal.Value = 3.1415
    assert_match("Value: 3.1415", scanner.get_properties_string(numberVal), "NumberValue check")

    -- 10. GUI Objects
    local label = mock.create_instance("TextLabel", "Title")
    label.Text = "Welcome"
    label.Visible = true
    assert_match('Text: "Welcome"', scanner.get_properties_string(label), "TextLabel check")

    local button = mock.create_instance("TextButton", "Play")
    button.Text = "Play Game"
    button.Visible = true
    button.Active = true
    local btnProps = scanner.get_properties_string(button)
    assert_match("Active: true", btnProps, "TextButton Active check")

    local imgBtn = mock.create_instance("ImageButton", "Icon")
    imgBtn.Image = "rbxassetid://456"
    imgBtn.Visible = false
    imgBtn.Active = false
    local imgProps = scanner.get_properties_string(imgBtn)
    assert_match("Image: rbxassetid://456", imgProps, "ImageButton Image check")
    assert_match("Visible: false", imgProps, "ImageButton Visible check")

    -- 11. Edge Cases (Unexpected Inputs)
    print("Testing get_properties_string edge cases...")
    assert_nil(scanner.get_properties_string(nil), "Should handle nil input")
    assert_nil(scanner.get_properties_string("not an object"), "Should handle string input")
    assert_nil(scanner.get_properties_string(123), "Should handle number input")
    assert_nil(scanner.get_properties_string({}), "Should handle empty table")
    assert_nil(scanner.get_properties_string({ Name = "Fake" }), "Should handle table without IsA")

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
    local childIgnore = mock.create_instance("LocalScript", "ChatScript", root)

    -- 1. Default (ignore ChatScript)
    local tree = scanner.generate_tree_map(root)
    assert_match("ClientScript %[SCRIPT%]", tree, "Tree map includes script")
    if string.match(tree, "ChatScript") then
        print("FAIL: Default tree map includes ChatScript")
        failed = failed + 1
    else
        passed = passed + 1
    end

    -- 2. Custom Ignore (Include ChatScript, Ignore ClientScript)
    local customIgnore = { ["ClientScript"] = true }
    local treeCustom = scanner.generate_tree_map(root, customIgnore)

    assert_match("ChatScript %[SCRIPT%]", treeCustom, "Custom tree map includes ChatScript")
    if string.match(treeCustom, "ClientScript") then
        print("FAIL: Custom tree map includes ClientScript (should be ignored)")
        failed = failed + 1
    else
        passed = passed + 1
    end

else
    print("FAIL: generate_tree_map function not exported")
    failed = failed + 1
end


-- Test GetService
if scanner.GetService then
    print("Testing GetService...")

    local original_getservice = game.GetService
    local original_findfirstchild = game.FindFirstChild

    -- 1. Success first try
    local workspace = scanner.GetService("Workspace")
    assert_equal("Workspace", workspace and workspace.Name, "Standard GetService")

    -- 2. Fallback to FindFirstChild
    game.GetService = function() error("Simulated failure") end
    local replicatedStorage = scanner.GetService("ReplicatedStorage")
    assert_equal("ReplicatedStorage", replicatedStorage and replicatedStorage.Name, "Fallback to FindFirstChild")

    -- 3. Fallback to direct indexing
    game.FindFirstChild = function() return nil end
    local starterGui = scanner.GetService("StarterGui")
    assert_equal("StarterGui", starterGui and starterGui.Name, "Fallback to direct indexing")

    -- Restore mocks
    game.GetService = original_getservice
    game.FindFirstChild = original_findfirstchild
else
    print("FAIL: GetService function not exported")
    failed = failed + 1
end

-- Test get_script_source
if scanner.get_script_source then
    print("Testing get_script_source...")

    local original_task_wait = task.wait

    -- Mock task.wait so tests run fast
    task.wait = function() end

    local dummyScript = { Name = "TestScript" }

    -- Helper to reload scanner with new global decompile state
    local function run_decompile_test(mock_decompile)
        -- `mock_roblox.lua` exports `decompile` to the global state.
        -- We redefine the global to our test function so that when the scanner
        -- is dynamically loaded, `local decompile = decompile` captures the mock correctly.
        _G.decompile = mock_decompile
        decompile = mock_decompile

        local loaded = helper.load_scanner()
        return loaded.get_script_source(dummyScript)
    end

    -- 1. Decompiler missing
    local res1 = run_decompile_test(nil)
    assert_equal("-- [Decompiler not available]", res1, "Decompiler missing handling")

    -- 2. Success first try
    local res2 = run_decompile_test(function(obj) return "print('hello')" end)
    assert_equal("print('hello')", res2, "Successful decompilation")

    -- 3. Rate limit success after retry
    local rateLimitCalls = 0
    local res3 = run_decompile_test(function(obj)
        rateLimitCalls = rateLimitCalls + 1
        if rateLimitCalls < 3 then
            return "failed to decompile bytecode: Too Many Requests"
        end
        return "print('success')"
    end)
    assert_equal("print('success')", res3, "Rate limit retry success")
    assert_equal(3, rateLimitCalls, "Rate limit should have called decompile 3 times")

    -- 4. Rate limit exhausted
    rateLimitCalls = 0
    local res4 = run_decompile_test(function(obj)
        rateLimitCalls = rateLimitCalls + 1
        return "failed to decompile bytecode: Too Many Requests"
    end)
    assert_equal("-- [Failed to decompile]", res4, "Rate limit exhausted")
    assert_equal(5, rateLimitCalls, "Rate limit should exhaust at 5 attempts")

    -- 5. Hard failure
    local hardFailCalls = 0
    local res5 = run_decompile_test(function(obj)
        hardFailCalls = hardFailCalls + 1
        error("Some internal error")
    end)
    assert_equal("-- [Failed to decompile]", res5, "Hard failure handling")
    assert_equal(5, hardFailCalls, "Hard failure should exhaust retries")

    -- Restore mocks
    task.wait = original_task_wait
else
    print("FAIL: get_script_source function not exported")
    failed = failed + 1
end


print("\nTest Summary: " .. passed .. " passed, " .. failed .. " failed.")

if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
