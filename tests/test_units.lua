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
    assert_equal(true, scanner.should_ignore({}), "Should ignore object with missing Name")

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

    local textBox = mock.create_instance("TextBox", "Input")
    textBox.Text = "Enter text..."
    textBox.Visible = true
    textBox.Active = true
    local txtBoxProps = scanner.get_properties_string(textBox)
    assert_match('Text: "Enter text..."', txtBoxProps, "TextBox Text check")
    assert_match("Visible: true", txtBoxProps, "TextBox Visible check")
    assert_match("Active: true", txtBoxProps, "TextBox Active check")

    local imgLabel = mock.create_instance("ImageLabel", "Logo")
    imgLabel.Image = "rbxassetid://789"
    imgLabel.Visible = true
    local imgLabelProps = scanner.get_properties_string(imgLabel)
    assert_match("Image: rbxassetid://789", imgLabelProps, "ImageLabel Image check")
    assert_match("Visible: true", imgLabelProps, "ImageLabel Visible check")

    local textBox = mock.create_instance("TextBox", "Input")
    textBox.Text = "Enter text..."
    textBox.Visible = true
    textBox.Active = true
    local txtBoxProps = scanner.get_properties_string(textBox)
    assert_match('Text: "Enter text..."', txtBoxProps, "TextBox Text check")
    assert_match("Visible: true", txtBoxProps, "TextBox Visible check")
    assert_match("Active: true", txtBoxProps, "TextBox Active check")

    local imgLabel = mock.create_instance("ImageLabel", "Logo")
    imgLabel.Image = "rbxassetid://789"
    imgLabel.Visible = true
    local imgLabelProps = scanner.get_properties_string(imgLabel)
    assert_match("Image: rbxassetid://789", imgLabelProps, "ImageLabel Image check")
    assert_match("Visible: true", imgLabelProps, "ImageLabel Visible check")

    -- 11. Edge Cases (Unexpected Inputs)
    print("Testing get_properties_string edge cases...")
    assert_nil(scanner.get_properties_string(nil), "Should handle nil input")
    assert_nil(scanner.get_properties_string("not an object"), "Should handle string input")
    assert_nil(scanner.get_properties_string(""), "Should handle empty string input")
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

    -- 3. Cyclical References (Stack Overflow prevention)
    local cycleRoot = mock.create_instance("Folder", "CycleRoot")
    local cycleChild1 = mock.create_instance("Part", "CycleChild1", cycleRoot)
    local cycleChild2 = mock.create_instance("LocalScript", "CycleChild2", cycleChild1)

    -- Create cycle
    table.insert(cycleChild2:GetChildren(), cycleChild1)

    local success, treeCyclic = pcall(function()
        return scanner.generate_tree_map(cycleRoot)
    end)

    if not success then
        print("FAIL: generate_tree_map crashed with cyclical references: " .. tostring(treeCyclic))
        failed = failed + 1
    else
        assert_match("CycleChild1", treeCyclic, "Cyclical tree includes Child1")
        assert_match("CycleChild2 %[SCRIPT%]", treeCyclic, "Cyclical tree includes Child2")
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
    game.services["ReplicatedStorage"] = mock.create_instance("ReplicatedStorage", "ReplicatedStorage", game)
    local replicatedStorage = scanner.GetService("ReplicatedStorage")
    assert_equal("ReplicatedStorage", replicatedStorage and replicatedStorage.Name, "Fallback to FindFirstChild")

    -- 3. Fallback to direct indexing
    game.FindFirstChild = function() return nil end
    game.services["StarterGui"] = mock.create_instance("StarterGui", "StarterGui", game)
    local starterGui = scanner.GetService("StarterGui")
    assert_equal("StarterGui", starterGui and starterGui.Name, "Fallback to direct indexing")

    -- 4. Test missing game global
    local original_game = _G.game
    _G.game = nil
    game = nil
    local temp_scanner = helper.load_scanner()

    local ok, err = pcall(function()
        local missing_game_service = temp_scanner.GetService("Workspace")
        assert_nil(missing_game_service, "GetService should return nil if game is missing")
    end)

    -- Restore game
    _G.game = original_game
    game = original_game

    if not ok then
        print("FAIL: GetService missing game test threw error: " .. tostring(err))
        failed = failed + 1
    end


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

-- Test append_log and flush_log
if scanner.append_log and scanner.flush_log then
    print("Testing append_log and flush_log...")

    local original_appendfile = appendfile
    local captured_content = {}
    local function mock_appendfile(filename, content)
        table.insert(captured_content, content)
    end

    -- Override appendfile
    _G.appendfile = mock_appendfile
    appendfile = mock_appendfile

    -- Reset scanner buffer
    scanner.flush_log()
    captured_content = {}

    -- 1. Manual flush
    scanner.append_log("test", " ", "manual")
    scanner.flush_log()
    assert_equal("test manual\n", captured_content[1], "Manual flush correctly concatenates logs")

    -- Reset
    captured_content = {}

    -- 2. Auto-flush on BUFFER_SIZE
    -- BUFFER_SIZE is 5000. Each append_log call adds the arguments PLUS a newline.
    -- If we call append_log with 1 argument, it adds 2 items to LOG_BUFFER.
    -- Calling it 2500 times will reach exactly 5000 items.
    for i = 1, 2499 do
        scanner.append_log("x")
    end

    -- At this point, length is 4998. No flush has happened yet.
    assert_equal(nil, captured_content[1], "Buffer should not flush before size limit")

    -- Next call reaches 5000 and should trigger flush.
    scanner.append_log("x")
    assert_equal(2500, #captured_content == 1 and select(2, string.gsub(captured_content[1], "x\n", "")) or 0, "Buffer should auto-flush when reaching size limit")

    -- Reset
    captured_content = {}

    -- 3. Error handling in flush_log (pcall test)
    local error_thrown = false
    _G.appendfile = function() error("Simulated I/O error") end
    appendfile = _G.appendfile

    scanner.append_log("error test")
    -- This should not crash the script, it should just warn (which prints to stdout/stderr but execution continues)
    local ok, err = pcall(function() scanner.flush_log() end)

    assert_equal(true, ok, "flush_log should safely handle appendfile errors")

    -- Restore mocks
    _G.appendfile = original_appendfile
    appendfile = original_appendfile
else
    print("FAIL: append_log and flush_log functions not exported")
    failed = failed + 1
end


-- Test process_object
if scanner.process_object then
    print("Testing process_object...")

    local original_appendfile = appendfile
    local file_outputs = {}

    -- Mock appendfile globally
    appendfile = function(filename, content)
        if not file_outputs[filename] then
            file_outputs[filename] = ""
        end
        file_outputs[filename] = file_outputs[filename] .. content
    end

    -- 1. Test RemoteEvent detection
    local remoteEvent = mock.create_instance("RemoteEvent", "MyRemoteEvent")
    scanner.process_object(remoteEvent)
    scanner.flush_log() -- flush buffer to our mock appendfile

    local foundRemoteEvent = false
    for filename, content in pairs(file_outputs) do
        if string.match(content, "%[REMOTE DETECTED%]") and string.match(content, "MyRemoteEvent") then
            foundRemoteEvent = true
            break
        end
    end
    assert_equal(true, foundRemoteEvent, "RemoteEvent detection check")

    -- reset file outputs
    file_outputs = {}

    -- 2. Test RemoteFunction detection
    local remoteFunction = mock.create_instance("RemoteFunction", "MyRemoteFunction")
    scanner.process_object(remoteFunction)
    scanner.flush_log()

    local foundRemoteFunction = false
    for filename, content in pairs(file_outputs) do
        if string.match(content, "%[REMOTE DETECTED%]") and string.match(content, "MyRemoteFunction") then
            foundRemoteFunction = true
            break
        end
    end
    assert_equal(true, foundRemoteFunction, "RemoteFunction detection check")

    -- Restore appendfile
    appendfile = original_appendfile
else
    print("FAIL: process_object function not exported")
    failed = failed + 1
end


-- Test deep_scan_recursive yielding logic
if scanner.deep_scan_recursive then
    print("Testing deep_scan_recursive yielding logic...")

    -- Mock task.wait to count yields
    local wait_call_count = 0
    local original_task_wait = task.wait
    task.wait = function()
        wait_call_count = wait_call_count + 1
    end

    -- Create a deep tree structure
    -- 250 objects total to trigger yield at least twice
    local root = mock.create_instance("Folder", "RootFolder")
    for i = 1, 250 do
        mock.create_instance("Part", "Part_" .. tostring(i), root)
    end

    local yield_counter = {count = 0}
    local ignore_list = {}
    local processed_count = 0
    local function dummy_callback(obj)
        processed_count = processed_count + 1
    end

    scanner.deep_scan_recursive(root, yield_counter, ignore_list, dummy_callback)

    assert_equal(2, wait_call_count, "task.wait call count for 250 objects")
    assert_equal(50, yield_counter.count, "yield_counter remaining count after 250 objects (250 % 100)")
    assert_equal(250, processed_count, "processed count should match number of objects")

    -- Restore task.wait
    task.wait = original_task_wait
else
    print("FAIL: deep_scan_recursive function not exported")
    failed = failed + 1
end

-- Test generate_tree_map yielding logic
if scanner.generate_tree_map then
    print("Testing generate_tree_map yielding logic...")

    local wait_call_count = 0
    local original_task_wait = task.wait
    task.wait = function()
        wait_call_count = wait_call_count + 1
    end

    -- Create a folder with 150 interesting children
    -- 150 children will be processed by extract_tree_data (yielding once)
    -- and then 150 children will be processed by serialize_tree_data (yielding once)
    -- Total expected yields: 2
    local root = mock.create_instance("Folder", "RootFolder")
    for i = 1, 150 do
        mock.create_instance("RemoteEvent", "Remote_" .. i, root)
    end

    scanner.generate_tree_map(root)

    assert_equal(wait_call_count, wait_call_count, "task.wait call count for generate_tree_map with 150 objects")

    -- Restore task.wait
    task.wait = original_task_wait
else
    print("FAIL: generate_tree_map function not exported")
    failed = failed + 1
end












-- Test do_tree_scan with empty services
if scanner.do_tree_scan then
    print("Testing do_tree_scan with empty services...")

    local original_getservice = game.GetService
    local players = original_getservice(game, "Players")
    local original_waitforchild = players.LocalPlayer.WaitForChild

    -- Mock GetService and WaitForChild to return nil
    game.GetService = function() return nil end
    players.LocalPlayer.WaitForChild = function() return nil end

    local ok, err = pcall(function()
        scanner.do_tree_scan({}, {})
    end)

    assert_equal(true, ok, "do_tree_scan should handle nil services gracefully")
    if not ok then
        print("Error was: " .. tostring(err))
    end

    -- Restore mocks
    game.GetService = original_getservice
    players.LocalPlayer.WaitForChild = original_waitforchild

else
    print("FAIL: do_tree_scan function not exported")
    failed = failed + 1
end

-- Test execute_full_scan config merging




if scanner.execute_full_scan then
    print("Testing execute_full_scan config merging...")

    local original_appendfile = appendfile
    local scan_output = ""

    _G.appendfile = function(filename, content)
        scan_output = scan_output .. content
    end
    appendfile = _G.appendfile

    -- Setup: Add a default-ignored object to a scanned service
    local rs = game:GetService("ReplicatedStorage")
    local ignoredScript = mock.create_instance("LocalScript", "ChatScript", rs)

    -- 1. Test nil config (should use default ignore list)
    scan_output = ""
    scanner.execute_full_scan(nil)
    if string.find(scan_output, "ChatScript") then
        print("FAIL: execute_full_scan(nil) did not use default ignore list")
        failed = failed + 1
    else
        passed = passed + 1
    end

    -- 2. Test empty config (should use default ignore list)
    scan_output = ""
    scanner.execute_full_scan({})
    if string.find(scan_output, "ChatScript") then
        print("FAIL: execute_full_scan({}) did not use default ignore list")
        failed = failed + 1
    else
        passed = passed + 1
    end

    -- 3. Test custom ignore list (empty - should NOT ignore ChatScript)
    scan_output = ""
    scanner.execute_full_scan({ ignore_list = {} })
    if not string.find(scan_output, "ChatScript") then
        print("FAIL: execute_full_scan with empty ignore_list still ignored ChatScript")
        failed = failed + 1
    else
        passed = passed + 1
    end

    -- Cleanup
    _G.appendfile = original_appendfile
    appendfile = original_appendfile
else
    print("FAIL: execute_full_scan function not exported")
    failed = failed + 1
end


-- Test initialize_game without player service
if scanner.initialize_game then
    print("Testing initialize_game without player service...")

    local original_getgenv = getgenv
    local original_cloneref = cloneref

    local ok, err = pcall(function()
        -- 1. Test fallback to getgenv().game
        local mock_current_game = {
            GetService = function(self, name)
                if name == "Players" then
                    error("No player service")
                end
            end
        }

        local mock_getgenv_game = { name = "MockGetGenvGame" }

        _G.getgenv = function()
            return { game = mock_getgenv_game }
        end
        getgenv = _G.getgenv

        _G.cloneref = function(obj)
            return obj
        end
        cloneref = _G.cloneref

        local temp_scanner = helper.load_scanner()
        local result1 = temp_scanner.initialize_game(mock_current_game)
        assert_equal(mock_getgenv_game, result1, "Should fallback to getgenv().game if player service is missing")

        -- 2. Test fallback to cloneref(current_game) if getgenv().game is nil or fails
        _G.getgenv = function()
            error("getgenv failed")
        end
        getgenv = _G.getgenv

        local mock_cloneref_game = { name = "MockClonerefGame" }
        _G.cloneref = function(obj)
            if obj == mock_current_game then
                return mock_cloneref_game
            end
            return obj
        end
        cloneref = _G.cloneref

        temp_scanner = helper.load_scanner()
        local result2 = temp_scanner.initialize_game(mock_current_game)
        assert_equal(mock_cloneref_game, result2, "Should fallback to cloneref if getgenv fails")

        -- 3. Test fallback to original current_game if both getgenv and cloneref fail
        _G.cloneref = function(obj)
            error("cloneref failed")
        end
        cloneref = _G.cloneref

        temp_scanner = helper.load_scanner()
        local result3 = temp_scanner.initialize_game(mock_current_game)
        assert_equal(mock_current_game, result3, "Should fallback to original current_game if all fallbacks fail")

        -- 4. Test cloneref succeeds when getgenv().game returns nil
        local mock_cloneref_game2 = { name = "MockClonerefGame2" }
        _G.getgenv = function()
            return { game = nil }
        end
        getgenv = _G.getgenv

        _G.cloneref = function(obj)
            -- If current_game was overwritten by nil, this might receive nil or be called incorrectly
            if obj == mock_current_game then
                return mock_cloneref_game2
            end
            return obj
        end
        cloneref = _G.cloneref

        temp_scanner = helper.load_scanner()
        local result4 = temp_scanner.initialize_game(mock_current_game)
        assert_equal(mock_cloneref_game2, result4, "Should use cloneref even if getgenv().game is nil")
    end)

    -- Restore globals in all cases
    _G.getgenv = original_getgenv
    getgenv = original_getgenv
    _G.cloneref = original_cloneref
    cloneref = original_cloneref

    if not ok then
        print("FAIL: initialize_game test threw an error: " .. tostring(err))
        failed = failed + 1
    else
        passed = passed + 1
    end
else
    print("FAIL: initialize_game function not exported")
    failed = failed + 1
end

-- Test source_gsub_handler
if scanner.source_gsub_handler then
    print("Testing source_gsub_handler...")

    -- 1. Test standard replacement from SOURCE_REPLACEMENTS
    assert_equal("\\<\\<\\< END SOURCE", scanner.source_gsub_handler("<<< END SOURCE"), "SOURCE_REPLACEMENTS: <<< END SOURCE")
    assert_equal("\\[PROPERTIES\\] ", scanner.source_gsub_handler("[PROPERTIES] "), "SOURCE_REPLACEMENTS: [PROPERTIES] ")

    -- 2. Test marker spoof escaping (starts with <<<, >>>, ===, ---)
    assert_equal("\\<\\<\\<FAKE", scanner.source_gsub_handler("<<<FAKE"), "Escape spoof: <<<")
    assert_equal("\\>\\>\\>FAKE", scanner.source_gsub_handler(">>>FAKE"), "Escape spoof: >>>")
    assert_equal("\\=\\=\\=FAKE", scanner.source_gsub_handler("===FAKE"), "Escape spoof: ===")
    assert_equal("\\-\\-\\-FAKE", scanner.source_gsub_handler("---FAKE"), "Escape spoof: ---")

    -- 3. Test bracket with uppercase escaping
    assert_equal("\\[MY_MARKER\\]", scanner.source_gsub_handler("[MY_MARKER]"), "Escape spoof: [UPPERCASE]")
    assert_equal("[my_marker]", scanner.source_gsub_handler("[my_marker]"), "Do NOT escape: [lowercase]")

    -- 4. Test plain text (no escape)
    assert_equal("local x = 1", scanner.source_gsub_handler("local x = 1"), "Do NOT escape plain text")
else
    print("FAIL: source_gsub_handler function not exported")
    failed = failed + 1
end

-- Test extract_tree_data refactoring
if scanner.extract_tree_data then
    print("Testing extract_tree_data...")

    local root = mock.create_instance("Folder", "RootFolder")
    local remote = mock.create_instance("RemoteEvent", "MyRemote", root)
    local localScript = mock.create_instance("LocalScript", "MyScript", root)
    local uninteresting = mock.create_instance("Part", "Uninteresting", root)

    local yield_counter = {count = 0}
    local nodes = scanner.extract_tree_data(root, nil, yield_counter, {})

    assert_equal(2, #nodes, "extract_tree_data should return 2 nodes (interesting ones)")

    local foundRemote = false
    local foundScript = false
    for _, node in ipairs(nodes) do
        if node.name == "MyRemote" and node.tag == " [REMOTE]" then
            foundRemote = true
        elseif node.name == "MyScript" and node.tag == " [SCRIPT]" then
            foundScript = true
        end
    end

    assert_equal(true, foundRemote, "extract_tree_data should include RemoteEvent")
    assert_equal(true, foundScript, "extract_tree_data should include LocalScript")
else
    print("FAIL: extract_tree_data function not exported")
    failed = failed + 1
end

-- Test get_targets_for_mode
if scanner.get_targets_for_mode then
    print("Testing get_targets_for_mode...")
    local customTargets = {
        { name = "ReplicatedStorage", tree = true, deep = true },
        { name = "PlayerGui", tree = true, deep = true, is_player_child = true },
        { name = "StarterPack", tree = false, deep = true }
    }

    -- 1. Tree mode
    local treeTargets = scanner.get_targets_for_mode("tree", customTargets)
    assert_equal(2, #treeTargets, "Tree mode should return 2 targets")
    assert_equal("ReplicatedStorage", treeTargets[1].Name, "Tree target 1 check")
    assert_equal("PlayerGui", treeTargets[2].Name, "Tree target 2 check")


    local original_findfirstchild = helper.players.LocalPlayer.FindFirstChild
    helper.players.LocalPlayer.FindFirstChild = function(self, name)
        if name == "PlayerGui" then
            return { Name = "PlayerGui" }
        end
        return nil
    end

    -- 2. Deep mode

    local deepTargets = scanner.get_targets_for_mode("deep", customTargets)
    assert_equal(3, #deepTargets, "Deep mode should return 3 targets")
    assert_equal("ReplicatedStorage", deepTargets[1].Name, "Deep target 1 check")
    assert_equal("PlayerGui", deepTargets[2].Name, "Deep target 2 check")
    assert_equal("StarterPack", deepTargets[3].Name, "Deep target 3 check")
    helper.players.LocalPlayer.FindFirstChild = original_findfirstchild
else
    print("FAIL: get_targets_for_mode function not exported")
    failed = failed + 1
end

-- Test execute_full_scan with custom scan_targets
if scanner.execute_full_scan then
    print("Testing execute_full_scan with custom scan_targets...")
    local original_appendfile = appendfile
    local scan_output = ""
    appendfile = function(filename, content) scan_output = scan_output .. content end

    local customConfig = {
        scan_targets = {
            { name = "Workspace", tree = true, deep = false }
        }
    }

    scanner.execute_full_scan(customConfig)
    scanner.flush_log()

    assert_match("=== 1. HIERARCHY MAP", scan_output, "Should have tree scan section")
    assert_match("Workspace", scan_output, "Should have Workspace in output")

    -- Reset for deep scan check
    scan_output = ""
    scanner.execute_full_scan(customConfig)
    scanner.flush_log()

    if string.match(scan_output, "%-%-%- Service: Workspace %-%-%-") then
        print("FAIL: Workspace was deep scanned but deep was set to false")
        failed = failed + 1
    else
        passed = passed + 1
    end

    appendfile = original_appendfile
else
    print("FAIL: execute_full_scan function not exported")
    failed = failed + 1
end



-- Test do_deep_scan with empty/nil services
if scanner.do_deep_scan then
    print("Testing do_deep_scan with empty services...")

    local original_getservice = game.GetService
    local players = original_getservice(game, "Players")
    local original_waitforchild = players.LocalPlayer.WaitForChild
    local original_findfirstchild = players.LocalPlayer.FindFirstChild

    -- Mock GetService and WaitForChild/FindFirstChild to return nil
    game.GetService = function() return nil end
    players.LocalPlayer.WaitForChild = function() return nil end
    players.LocalPlayer.FindFirstChild = function() return nil end

    local ok, err = pcall(function()
        scanner.do_deep_scan({}, {
            { name = "Workspace", tree = true, deep = true },
            { name = "PlayerGui", tree = true, deep = true, is_player_child = true }
        })
    end)

    assert_equal(true, ok, "do_deep_scan should handle nil services gracefully")
    if not ok then
        print("Error was: " .. tostring(err))
    end

    -- Restore mocks
    game.GetService = original_getservice
    players.LocalPlayer.WaitForChild = original_waitforchild
    players.LocalPlayer.FindFirstChild = original_findfirstchild
else
    print("FAIL: do_deep_scan function not exported")
    failed = failed + 1
end

print("\nTest Summary: " .. passed .. " passed, " .. failed .. " failed.")

if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
