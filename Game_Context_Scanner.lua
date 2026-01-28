local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local CorePackages = game:GetService("CorePackages")

local FILENAME = "Game_Context_" .. game.PlaceId .. ".txt"
writefile(FILENAME, "=== GAME CONTEXT SCAN ===\nTime: " .. tostring(os.date()) .. "\nPlace ID: " .. game.PlaceId .. "\n\n")

local function append_log(text)
    appendfile(FILENAME, text .. "\n")
end

print("[SCANNER] Starting Context Scanner...")
append_log("=== STARTING REMOTE SPY ===")

-- 1. ENHANCED SERIALIZER
local function serialize_args(args)
    local parts = {}
    for i, v in ipairs(args) do
        local typeStr = typeof(v)
        local valStr = tostring(v)

        if typeStr == "Instance" then
            valStr = v:GetFullName()
        elseif typeStr == "string" then
            valStr = '"' .. v .. '"'
        elseif typeStr == "table" then
            pcall(function() valStr = HttpService:JSONEncode(v) end)
        end

        table.insert(parts, string.format("[%d] (%s) %s", i, typeStr, valStr))
    end
    return table.concat(parts, ", ")
end

-- 2. REMOTE SPY (Updated)
local mt = getrawmetatable(game)
local old_namecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "FireServer" or method == "InvokeServer" then
        if self.ClassName == "RemoteEvent" or self.ClassName == "RemoteFunction" then
            task.spawn(function()
                local argsStr = serialize_args(args)
                local log = string.format("[REMOTE SPY] %s: %s | Args: %s", method, self:GetFullName(), argsStr)
                append_log(log)
            end)
        end
    end

    return old_namecall(self, ...)
end)

setreadonly(mt, true)
print("[SCANNER] Remote Spy Active. Play the game to capture remote calls.")

-- 3. HELPER: IGNORE LIST
local function should_ignore(obj)
    if not obj then return true end
    local name = obj.Name

    if obj:IsDescendantOf(CoreGui) or obj:IsDescendantOf(CorePackages) or obj:IsDescendantOf(game:GetService("Chat")) then return true end

    local blacklist = {"PlayerModule", "RbxCharacterSounds", "ChatScript", "BubbleChat", "CameraScript", "ControlScript", "Animate"}
    for _, blocked in ipairs(blacklist) do
        if name == blocked then return true end
    end

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

-- 6. TREE MAP GENERATOR
local function generate_tree_map(root, indent)
    indent = indent or ""
    local tree = ""
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
                tree = tree .. indent .. prefix .. child.Name .. tag .. "\n"
                tree = tree .. generate_tree_map(child, indent .. subIndent)
            end
        end
    end
    return tree
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

            for _, obj in pairs(service:GetDescendants()) do
                if not should_ignore(obj) then

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
            end
        end
    end

    print("[SCANNER] Complete! File Saved: " .. FILENAME)
    append_log("\n=== END OF SCAN ===")

    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Scan Complete!",
        Text = "Saved to " .. FILENAME,
        Duration = 5
    })
end)
