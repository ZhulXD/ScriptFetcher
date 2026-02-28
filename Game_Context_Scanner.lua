local game = game
local getgenv = getgenv
local cloneref = cloneref

-- Fix: Robust initialization for environments with restricted/broken 'game'
if not pcall(function() return game:GetService("Players") end) then
    if type(getgenv) == "function" and pcall(function() return getgenv().game end) then
        game = getgenv().game
    end
    if type(cloneref) == "function" and pcall(function() return cloneref(game) end) then
        local s, r = pcall(cloneref, game)
        if s and r then game = r end
    end
end

local function GetService(name)
    if not game then return nil end
    local success, service = pcall(function() return game:GetService(name) end)
    if success and service then return service end
    -- Fallback for some exploits or older environments
    return game:FindFirstChild(name) or game[name]
end

local Players = GetService("Players")

local math = math
-- ATTEMPT TO RESOLVE DECOMPILER
local decompile = decompile
if not decompile and type(getgenv) == "function" then
    decompile = getgenv().decompile
end
if not decompile and debug and debug.decompile then
    decompile = debug.decompile
end

local FILENAME = "Game_Context_" .. game.PlaceId .. ".txt"
local success, err = pcall(function()
    writefile(FILENAME, "=== GAME CONTEXT SCAN ===\nTime: " .. tostring(os.date()) .. "\nPlace ID: " .. game.PlaceId .. "\n\n")
end)
if not success then
    warn("[SCANNER] Failed to create log file: " .. tostring(err))
end

-- OPTIMIZATION: Buffer logs to reduce I/O
local LOG_BUFFER = {}
local BUFFER_SIZE = 5000

local function flush_log()
    if #LOG_BUFFER > 0 then
        -- appendfile is expensive, so we do it once per chunk
        local ok, writeErr = pcall(appendfile, FILENAME, table.concat(LOG_BUFFER, ""))
        if not ok then
            warn("[SCANNER] Failed to append log: " .. tostring(writeErr))
        end
        if table.clear then
            table.clear(LOG_BUFFER)
        else
            LOG_BUFFER = {}
        end
    end
end

local function append_log(...)
    for _, v in ipairs({...}) do
        table.insert(LOG_BUFFER, v)
    end
    table.insert(LOG_BUFFER, "\n")
    if #LOG_BUFFER >= BUFFER_SIZE then
        flush_log()
    end
end

print("[SCANNER] Starting Context Scanner...")

-- 3. CONFIGURATION: DEFAULT IGNORE LIST
local DEFAULT_CONFIG = {
    ignore_list = {
        ["PlayerModule"] = true,
        ["RbxCharacterSounds"] = true,
        ["ChatScript"] = true,
        ["BubbleChat"] = true,
        ["CameraScript"] = true,
        ["ControlScript"] = true,
        ["Animate"] = true
    }
}

local function should_ignore(obj, ignore_list)
    if not obj then return true end
    -- Fallback to default if not provided
    local list = ignore_list or DEFAULT_CONFIG.ignore_list
    if list[obj.Name] then return true end

    -- OPTIMIZATION: Skipped IsDescendantOf(CoreGui/etc) checks because we only scan disjoint services.

    -- NOTE: Removed redundant IsDescendantOf checks for CoreGui/Chat
    -- as we strictly scan user services (Workspace, ReplicatedStorage, etc)
    -- which are disjoint from internal services.
    -- If 'game' or 'CoreGui' is added to scan list, restore checks here.
    return false
end

-- 5. HELPER: SANITIZE
-- Defined earlier to ensure availability
local function sanitize(val)
    return (tostring(val):gsub("[%c]", function(c)
        if c == "\n" then return "\\n" end
        if c == "\r" then return "\\r" end
        if c == "\t" then return "\\t" end
        return string.format("\\%03d", string.byte(c))
    end))
end

-- 4. ROBUST DECOMPILER
local function get_script_source(scriptObj)
    if not decompile then return "-- [Decompiler not available]" end
    local attempts = 0
    local success = false
    local source = "-- [Failed to decompile]"
    local retry_delay = 0.02

    while attempts < 5 and not success do
        attempts = attempts + 1
        local ok, result = pcall(decompile, scriptObj)

        if ok and result and string.find(result, "failed to decompile bytecode: Too Many Requests", 1, true) then
            warn("[SCANNER] Rate limit on " .. sanitize(scriptObj.Name) .. " - Waiting 1.5s...")
            task.wait(1.5)
        elseif ok and result and result ~= "" then
            source = result
            success = true
        else
            if attempts < 5 then
                task.wait(retry_delay)
                retry_delay = math.min(0.1, retry_delay * 2)
            end
        end
    end
    return source
end

-- 6. PROPERTY DUMPER
local function get_properties_string(obj)
    local props = {}

    if obj:IsA("BasePart") then
        if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
            table.insert(props, "Occupant: " .. (obj.Occupant and sanitize(obj.Occupant:GetFullName()) or "nil"))
            table.insert(props, "Disabled: " .. tostring(obj.Disabled))
        else
            -- Only log interesting parts to reduce spam
            local name = obj.Name
            local transparency = obj.Transparency
            local shouldLog = name == "Handle" or transparency > 0.9

            if not shouldLog then
                local lowerName = name:lower()
                shouldLog = lowerName:find("hitbox") or lowerName:find("root")
            end

            if shouldLog then
                table.insert(props, "Size: " .. tostring(obj.Size))
                table.insert(props, "Transparency: " .. tostring(transparency))
                table.insert(props, "CanCollide: " .. tostring(obj.CanCollide))
                table.insert(props, "Position: " .. tostring(obj.Position))
            end
        end
    elseif obj:IsA("Tool") then
        table.insert(props, "Enabled: " .. tostring(obj.Enabled))
        table.insert(props, "Grip: " .. tostring(obj.Grip))
        if obj.ToolTip ~= "" then table.insert(props, "ToolTip: " .. sanitize(obj.ToolTip)) end
        if obj.TextureId ~= "" then table.insert(props, "TextureId: " .. sanitize(obj.TextureId)) end
    elseif obj:IsA("ProximityPrompt") then
        table.insert(props, "ActionText: " .. sanitize(obj.ActionText))
        table.insert(props, "ObjectText: " .. sanitize(obj.ObjectText))
        table.insert(props, "HoldDuration: " .. tostring(obj.HoldDuration))
        table.insert(props, "KeyCode: " .. tostring(obj.KeyboardKeyCode))
    elseif obj:IsA("Humanoid") then
        table.insert(props, "Health: " .. tostring(obj.Health))
        table.insert(props, "MaxHealth: " .. tostring(obj.MaxHealth))
        table.insert(props, "WalkSpeed: " .. tostring(obj.WalkSpeed))
        table.insert(props, "JumpPower: " .. tostring(obj.JumpPower))
        table.insert(props, "RigType: " .. tostring(obj.RigType))
    elseif obj:IsA("ClickDetector") then
        table.insert(props, "MaxActivationDistance: " .. tostring(obj.MaxActivationDistance))
    elseif obj:IsA("StringValue") or obj:IsA("IntValue") or obj:IsA("BoolValue") or obj:IsA("NumberValue") then
        table.insert(props, "Value: " .. sanitize(obj.Value))
    elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        table.insert(props, 'Text: "' .. sanitize(obj.Text) .. '"')
        table.insert(props, "Visible: " .. tostring(obj.Visible))
        if obj:IsA("TextButton") or obj:IsA("TextBox") then
            table.insert(props, "Active: " .. tostring(obj.Active))
        end
    elseif obj:IsA("ImageButton") or obj:IsA("ImageLabel") then
        table.insert(props, "Image: " .. sanitize(obj.Image))
        table.insert(props, "Visible: " .. tostring(obj.Visible))
        if obj:IsA("ImageButton") then
            table.insert(props, "Active: " .. tostring(obj.Active))
        end
    end

    if #props > 0 then
        return table.concat(props, ", ")
    end
    return nil
end

-- 6. TREE MAP GENERATOR (Optimized with table buffer)
local function generate_tree_map_impl(root, indent, buffer, cachedChildren, yield_counter, ignore_list)
    yield_counter = yield_counter or {count = 0}
    local children = cachedChildren or root:GetChildren()
    local visibleChildren = {}

    for _, child in ipairs(children) do
        if not should_ignore(child, ignore_list) then
            table.insert(visibleChildren, child)
        end
    end

    for i, child in ipairs(visibleChildren) do
        yield_counter.count = yield_counter.count + 1
        if yield_counter.count >= 100 then
            yield_counter.count = 0
            task.wait()
        end

        local isLast = (i == #visibleChildren)
        local prefix = isLast and "└── " or "├── "
        local subIndent = isLast and "    " or "│   "

        -- Identify interesting objects
        local tag = ""
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then tag = " [REMOTE]"
        elseif child:IsA("LocalScript") or child:IsA("ModuleScript") then tag = " [SCRIPT]"
        elseif child:IsA("ScreenGui") then tag = " [GUI]"
        end

        local grandChildren = child:GetChildren()
        if tag ~= "" or #grandChildren > 0 then
            if #buffer > 0 then
                table.insert(buffer, "\n")
            end
            if indent ~= "" then
                table.insert(buffer, indent)
            end
            table.insert(buffer, prefix)
            table.insert(buffer, sanitize(child.Name))
            if tag ~= "" then
                table.insert(buffer, tag)
            end
            generate_tree_map_impl(child, indent .. subIndent, buffer, grandChildren, nil, ignore_list)
        end
    end
end

local function generate_tree_map(root, ignore_list)
    local buffer = {}
    generate_tree_map_impl(root, "", buffer, nil, nil, ignore_list)
    return table.concat(buffer)
end

local function process_object(obj)
    -- Dump Properties
    local props = get_properties_string(obj)
    if props then
        append_log("[PROPERTIES] ", sanitize(obj:GetFullName()), " | ", props)
    end

    -- Log Remote
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        append_log("[REMOTE DETECTED] ", sanitize(obj:GetFullName()))
    end

    -- Dump Script
    if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
        append_log("\n>>> SOURCE: ", sanitize(obj:GetFullName()))

        -- Decompile
        local source = get_script_source(obj)
        if source then
            append_log(source)
        end
        append_log("<<< END SOURCE\n")
    end
end

local function deep_scan_recursive(root, yield_counter, ignore_list)
    yield_counter = yield_counter or {count = 0}

    local children = root:GetChildren()
    for _, child in ipairs(children) do
        if not should_ignore(child, ignore_list) then
            yield_counter.count = yield_counter.count + 1
            if yield_counter.count >= 100 then
                yield_counter.count = 0
                task.wait()
            end

            process_object(child)
            deep_scan_recursive(child, yield_counter, ignore_list)
        end
    end
end

-- 7. MAIN SCAN
local function execute_full_scan(config)
    -- Merge config
    local current_ignore_list = DEFAULT_CONFIG.ignore_list
    if config and config.ignore_list then
        current_ignore_list = config.ignore_list
    end

    -- A. TREE VIEW
    append_log("\n=== 1. HIERARCHY MAP (Tree View) ===")
    local map_services = {
        game:GetService("ReplicatedStorage"),
        game:GetService("Workspace"),
        game:GetService("StarterGui"),
        Players.LocalPlayer:WaitForChild("PlayerGui", 5)
    }

    for _, service in ipairs(map_services) do
        if service then
            append_log(sanitize(service.Name))
            append_log(generate_tree_map(service, current_ignore_list))
        end
    end

    -- B. DEEP SCAN
    append_log("\n=== 2. DEEP SCAN (Code & Remotes) ===")

    local deep_scan_services = {
        game:GetService("ReplicatedStorage"),
        game:GetService("Workspace"),
        game:GetService("StarterGui"),
        game:GetService("StarterPack"),
        game:GetService("StarterPlayer"),
        Players.LocalPlayer:FindFirstChild("PlayerGui")
    }

    for _, service in ipairs(deep_scan_services) do
        if service then
            print("[SCANNER] Deep Scanning " .. sanitize(service.Name) .. "...")
            append_log("\n--- Service: ", sanitize(service.Name), " ---")

            deep_scan_recursive(service, nil, current_ignore_list)
        end
    end

    print("[SCANNER] Complete! File Saved: " .. FILENAME)
    append_log("\n=== END OF SCAN ===")
    flush_log() -- Final flush to ensure everything is written

    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Scan Complete!",
        Text = "Saved to " .. FILENAME,
        Duration = 5
    })
end

if not _G.SCANNER_TEST_MODE then
    task.spawn(function()
        task.wait(1)
        execute_full_scan()
    end)
end

local export = {
    execute_full_scan = execute_full_scan,
    DEFAULT_CONFIG = DEFAULT_CONFIG
}

if _G.SCANNER_TEST_MODE then
    export.sanitize = sanitize
    export.should_ignore = should_ignore
    export.get_properties_string = get_properties_string
    export.generate_tree_map = generate_tree_map
    export.get_script_source = get_script_source
end

return export
