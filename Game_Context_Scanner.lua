local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local CorePackages = game:GetService("CorePackages")

local FILENAME = "Game_Context_" .. game.PlaceId .. ".txt"
writefile(FILENAME, "=== GAME CONTEXT SCAN ===\nTime: " .. tostring(os.date()) .. "\nPlace ID: " .. game.PlaceId .. "\n\n")

-- OPTIMIZATION: Buffer logs to reduce I/O
local LOG_BUFFER = {}
local BUFFER_SIZE = 1000

local function flush_log()
    if #LOG_BUFFER > 0 then
        -- appendfile is expensive, so we do it once per chunk
        appendfile(FILENAME, table.concat(LOG_BUFFER, "\n") .. "\n")
        if table.clear then
            table.clear(LOG_BUFFER)
        else
            LOG_BUFFER = {}
        end
    end
end

local function append_log(text)
    table.insert(LOG_BUFFER, text)
    if #LOG_BUFFER >= BUFFER_SIZE then
        flush_log()
    end
end

print("[SCANNER] Starting Context Scanner...")

-- 3. HELPER: IGNORE LIST
local IGNORE_NAMES = {
    ["PlayerModule"] = true,
    ["RbxCharacterSounds"] = true,
    ["ChatScript"] = true,
    ["BubbleChat"] = true,
    ["CameraScript"] = true,
    ["ControlScript"] = true,
    ["Animate"] = true
}

local function should_ignore(obj)
    if not obj then return true end
    if IGNORE_NAMES[obj.Name] then return true end

    -- OPTIMIZATION: Skipped IsDescendantOf(CoreGui/etc) checks because we only scan disjoint services.

    -- NOTE: Removed redundant IsDescendantOf checks for CoreGui/Chat
    -- as we strictly scan user services (Workspace, ReplicatedStorage, etc)
    -- which are disjoint from internal services.
    -- If 'game' or 'CoreGui' is added to scan list, restore checks here.

    return false
end

-- 4. ROBUST DECOMPILER
local function get_script_source(scriptObj)
    if not (scriptObj:IsA("LocalScript") or scriptObj:IsA("ModuleScript")) then return nil end

    local attempts = 0
    local success = false
    local source = "-- [Failed to decompile]"

    while attempts < 5 and not success do
        attempts += 1
        local ok, result = pcall(decompile, scriptObj)

        if ok and result and string.find(result, "failed to decompile bytecode: Too Many Requests") then
            warn("[SCANNER] Rate limit on " .. scriptObj.Name .. " - Waiting 1.5s...")
            task.wait(1.5)
        elseif ok and result and result ~= "" then
            source = result
            success = true
        else
            task.wait(0.1)
        end
    end
    return source
end

-- 5. PROPERTY DUMPER
local function get_properties_string(obj)
    local props = {}

    if obj:IsA("Tool") then
        table.insert(props, "Enabled: " .. tostring(obj.Enabled))
        table.insert(props, "Grip: " .. tostring(obj.Grip))
        if obj.ToolTip ~= "" then table.insert(props, "ToolTip: " .. obj.ToolTip) end
        if obj.TextureId ~= "" then table.insert(props, "TextureId: " .. obj.TextureId) end
    elseif obj:IsA("ProximityPrompt") then
        table.insert(props, "ActionText: " .. obj.ActionText)
        table.insert(props, "ObjectText: " .. obj.ObjectText)
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
    elseif obj:IsA("Seat") or obj:IsA("VehicleSeat") then
        table.insert(props, "Occupant: " .. (obj.Occupant and obj.Occupant:GetFullName() or "nil"))
        table.insert(props, "Disabled: " .. tostring(obj.Disabled))
    elseif obj:IsA("StringValue") or obj:IsA("IntValue") or obj:IsA("BoolValue") or obj:IsA("NumberValue") then
        table.insert(props, "Value: " .. tostring(obj.Value))
    elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        table.insert(props, 'Text: "' .. obj.Text .. '"')
        table.insert(props, "Visible: " .. tostring(obj.Visible))
        if obj:IsA("TextButton") or obj:IsA("TextBox") then
            table.insert(props, "Active: " .. tostring(obj.Active))
        end
    elseif obj:IsA("ImageButton") or obj:IsA("ImageLabel") then
        table.insert(props, "Image: " .. tostring(obj.Image))
        table.insert(props, "Visible: " .. tostring(obj.Visible))
        if obj:IsA("ImageButton") then
            table.insert(props, "Active: " .. tostring(obj.Active))
        end
    elseif obj:IsA("BasePart") then
         -- Only log interesting parts to reduce spam
         if obj.Name == "Handle" or obj.Transparency > 0.9 or obj.Name:lower():find("hitbox") or obj.Name:lower():find("root") then
             table.insert(props, "Size: " .. tostring(obj.Size))
             table.insert(props, "Transparency: " .. tostring(obj.Transparency))
             table.insert(props, "CanCollide: " .. tostring(obj.CanCollide))
             table.insert(props, "Position: " .. tostring(obj.Position))
         end
    end

    if #props > 0 then
        return table.concat(props, ", ")
    end
    return nil
end

-- 6. TREE MAP GENERATOR (Optimized with table buffer)
local function generate_tree_map_impl(root, indent, buffer)
    local children = root:GetChildren()

    for i, child in ipairs(children) do
        if not should_ignore(child) then
            local isLast = (i == #children)
            local prefix = isLast and "└── " or "├── "
            local subIndent = isLast and "    " or "│   "

            -- Identify interesting objects
            local tag = ""
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then tag = " [REMOTE]"
            elseif child:IsA("LocalScript") or child:IsA("ModuleScript") then tag = " [SCRIPT]"
            elseif child:IsA("ScreenGui") then tag = " [GUI]"
            end

            if tag ~= "" or #child:GetChildren() > 0 then
                table.insert(buffer, indent .. prefix .. child.Name .. tag)
                generate_tree_map_impl(child, indent .. subIndent, buffer)
            end
        end
    end
end

local function generate_tree_map(root)
    local buffer = {}
    generate_tree_map_impl(root, "", buffer)
    return table.concat(buffer, "\n")
end

local function process_object(obj)
    -- Dump Properties
    local props = get_properties_string(obj)
    if props then
        append_log("[PROPERTIES] " .. obj:GetFullName() .. " | " .. props)
    end

    -- Log Remote
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        append_log("[REMOTE DETECTED] " .. obj:GetFullName())
    end

    -- Dump Script
    if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
        append_log("\n>>> SOURCE: " .. obj:GetFullName())

        -- Decompile
        local source = get_script_source(obj)
        if source then
            append_log(source)
        end
        append_log("<<< END SOURCE\n")
    end
end

local function scan_service_recursively(root)
    local children = root:GetChildren()
    for _, child in ipairs(children) do
        if not should_ignore(child) then
            process_object(child)
            scan_service_recursively(child)
        end
    end
end

-- 7. MAIN SCAN
task.spawn(function()
    task.wait(1)

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
            append_log(service.Name)
            append_log(generate_tree_map(service))
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
            print("[SCANNER] Deep Scanning " .. service.Name .. "...")
            append_log("\n--- Service: " .. service.Name .. " ---")

            scan_service_recursively(service)
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
end)
