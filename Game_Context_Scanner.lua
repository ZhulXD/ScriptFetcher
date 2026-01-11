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

-- 1. REMOTE SPY
local mt = getrawmetatable(game)
local old_namecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "FireServer" or method == "InvokeServer" then
        if self.ClassName == "RemoteEvent" or self.ClassName == "RemoteFunction" then
            task.spawn(function()
                local argsStr = "[]"
                pcall(function() argsStr = HttpService:JSONEncode(args) end)

                local log = string.format("[REMOTE SPY] %s: %s | Args: %s", method, self:GetFullName(), argsStr)
                append_log(log)
            end)
        end
    end

    return old_namecall(self, ...)
end)

setreadonly(mt, true)
print("[SCANNER] Remote Spy Active. Play the game to capture remote calls.")

-- 2. HELPER: IGNORE LIST
local function should_ignore(obj)
    if not obj then return true end
    local name = obj.Name

    -- Service Checks
    if obj:IsDescendantOf(CoreGui) or obj:IsDescendantOf(CorePackages) or obj:IsDescendantOf(game:GetService("Chat")) then
        return true
    end

    -- Common Roblox Scripts
    local blacklist = {"PlayerModule", "RbxCharacterSounds", "ChatScript", "BubbleChat", "CameraScript", "ControlScript"}
    for _, blocked in ipairs(blacklist) do
        if name == blocked then return true end
    end

    return false
end

-- 3. ROBUST DECOMPILER
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

-- 4. STATIC SCANNER
task.spawn(function()
    task.wait(1) -- Let spy initialize
    append_log("\n=== STATIC ANALYSIS & DECOMPILATION ===\n")

    local services_to_scan = {
        game:GetService("Workspace"),
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterGui"),
        game:GetService("StarterPack"),
        game:GetService("StarterPlayer")
    }

    for _, service in ipairs(services_to_scan) do
        print("[SCANNER] Scanning " .. service.Name .. "...")
        append_log("\n--- Service: " .. service.Name .. " ---")

        for _, obj in pairs(service:GetDescendants()) do
            if not should_ignore(obj) then
                -- Log Remotes
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    append_log("[REMOTE FOUND] " .. obj:GetFullName() .. " (" .. obj.ClassName .. ")")
                end

                -- Dump Scripts
                if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local source = get_script_source(obj)
                    if source then
                        append_log("\n>>> SCRIPT: " .. obj:GetFullName())
                        append_log(source)
                        append_log("<<< END SCRIPT\n")
                    end
                end
            end
        end
    end

    print("[SCANNER] Static Analysis Complete! File Saved: " .. FILENAME)
    append_log("\n=== STATIC ANALYSIS FINISHED ===")
end)
