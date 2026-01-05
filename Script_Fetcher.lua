local Services = {
    Players = game:GetService("Players"),
    CoreGui = game:GetService("CoreGui"),
    CorePackages = game:GetService("CorePackages"),
    StarterPlayer = game:GetService("StarterPlayer"),
    Chat = game:GetService("Chat"),
    StarterGui = game:GetService("StarterGui")
}

local LocalPlayer = Services.Players.LocalPlayer
local PlayerName = LocalPlayer.Name

if not isfolder("fetched") then makefolder("fetched") end

Services.StarterGui:SetCore("SendNotification", {
    Title = "Script Fetcher",
    Text = "Starting optimization...",
    Duration = 5
})

print("[FETCHER] Optimization started")

-- Cache visited scripts to avoid processing duplicates
local visited = {}

-- Helper: Check if script should be ignored
local function should_ignore(script)
    if not script or not script.Parent then return true end

    -- Class Check
    local isModule = script.ClassName == "ModuleScript"
    local isLocal = script.ClassName == "LocalScript"
    local isRunContextClient = (script.ClassName == "Script" and script.RunContext == Enum.RunContext.Client)

    if not (isModule or isLocal or isRunContextClient) then return true end

    -- Service Blacklist
    if script:IsDescendantOf(Services.CoreGui) or
       script:IsDescendantOf(Services.CorePackages) or
       script:IsDescendantOf(Services.StarterPlayer) or
       script:IsDescendantOf(Services.Chat) then
       return true
    end

    -- Name Blacklist
    local fullName = script:GetFullName()
    local blacklist = {
        "PlayerModule", "RbxCharacterSounds", "ChatScript", "BubbleChat",
        "Satchel", "TopbarPlus", "PlayerScriptsLoader", "Icon"
    }

    for _, name in ipairs(blacklist) do
        if fullName:match(name) then return true end
    end

    if script.Name == "Animate" then return true end

    -- Players Service Logic
    if script:IsDescendantOf(Services.Players) and not script:IsDescendantOf(LocalPlayer) then
        return true
    end

    -- Character Logic (Don't steal other players' scripts)
    if script.Parent and script.Parent.ClassName == "Model" and script.Parent:FindFirstChildOfClass("Humanoid") then
        if script.Parent ~= LocalPlayer.Character then
            return true
        end
    end

    -- Workspace Logic
    if script:IsDescendantOf(game.Workspace) and not fullName:match(PlayerName) then
        return true
    end

    return false
end

-- Helper: Generate file path
local function get_file_info(script)
    local cleanName = script:GetFullName():gsub(PlayerName, "LocalPlayer"):gsub("%.", "_")
    local prefix = "Base"
    if script.ClassName == "ModuleScript" then prefix = "Module"
    elseif script.ClassName == "LocalScript" then prefix = "Local"
    end

    local filename = string.format("fetched/%s_%s.luau", prefix, cleanName)
    return filename, prefix
end

-- Helper: Attempt decompile with retry
local function attempt_save(script)
    local filename, prefix = get_file_info(script)

    -- Skip if already saved on disk
    if isfile(filename) then return end

    local source = nil
    local success = false
    local attempts = 0

    -- Retry logic
    while attempts < 3 and not success do
        attempts += 1
        local ok, result = pcall(decompile, script)
        if ok and result and result ~= "" then
            source = result
            success = true
        else
            -- Small wait before retry
            task.wait(0.1)
        end
    end

    if success then
        local fullPath = script:GetFullName():gsub(PlayerName, "LocalPlayer")
        local parentName = script.Parent and script.Parent:GetFullName():gsub(PlayerName, "LocalPlayer") or "nil"

        local fileContent = string.format(
            "--[[\nScript Type: %s\nFull Path: %s\nParent: %s\n]]\n\n%s",
            script.ClassName, fullPath, parentName, source
        )

        writefile(filename, fileContent)
        print(string.format("[FETCHER] Saved %s: %s", prefix, fullPath))
    else
        warn(string.format("[FETCHER] Failed to decompile: %s", script:GetFullName()))
    end
end

-- Function to process a single object
local function process_object(script)
    if visited[script] then return end

    -- Perform check
    if not should_ignore(script) then
        visited[script] = true -- Mark as visited

        -- Fast check if file exists
        local filename = get_file_info(script)
        if not isfile(filename) then
            task.wait() -- Minimal yield per save attempt to keep UI responsive
            attempt_save(script)
        end
    end
end

-- Main Processing Loop
task.spawn(function()
    for i = 1, 3 do
        -- Iterate Descendants directly (Memory Efficient)
        for _, obj in pairs(game:GetDescendants()) do
            process_object(obj)
        end

        -- Iterate LoadedModules directly
        if getloadedmodules then
            for _, obj in pairs(getloadedmodules()) do
                process_object(obj)
            end
        end

        -- Wait before next sweep to allow new scripts to load
        if i < 3 then task.wait(1) end
    end

    print("[FETCHER] All done.")
    Services.StarterGui:SetCore("SendNotification", {
        Title = "Script Fetcher",
        Text = "All scripts fetched successfully!",
        Duration = 10
    })
end)
