local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local ROOT_FOLDER = "Workspace_Dump"
if not isfolder(ROOT_FOLDER) then makefolder(ROOT_FOLDER) end

-- 1. Serialization Helpers
local function serialize_value(val)
    local typeOf = typeof(val)
    if typeOf == "Vector3" then
        return {Type = "Vector3", X = val.X, Y = val.Y, Z = val.Z}
    elseif typeOf == "Vector2" then
        return {Type = "Vector2", X = val.X, Y = val.Y}
    elseif typeOf == "CFrame" then
        local components = {val:GetComponents()}
        return {Type = "CFrame", Components = components}
    elseif typeOf == "Color3" then
        return {Type = "Color3", R = val.R, G = val.G, B = val.B}
    elseif typeOf == "EnumItem" then
        return tostring(val)
    elseif typeOf == "Instance" then
        return val:GetFullName()
    elseif typeOf == "BrickColor" then
        return val.Name
    elseif typeOf == "UDim2" then
        return {Type = "UDim2", X = {Scale = val.X.Scale, Offset = val.X.Offset}, Y = {Scale = val.Y.Scale, Offset = val.Y.Offset}}
    elseif typeOf == "string" or typeOf == "number" or typeOf == "boolean" then
        return val
    else
        return tostring(val) -- Fallback
    end
end

local function get_properties(obj)
    local props = {}
    props.Name = obj.Name
    props.ClassName = obj.ClassName

    -- Common Physical Properties
    pcall(function() props.Position = serialize_value(obj.Position) end)
    pcall(function() props.Size = serialize_value(obj.Size) end)
    pcall(function() props.Color = serialize_value(obj.Color) end)
    pcall(function() props.Transparency = serialize_value(obj.Transparency) end)
    pcall(function() props.Reflectance = serialize_value(obj.Reflectance) end)
    pcall(function() props.Material = serialize_value(obj.Material) end)
    pcall(function() props.Anchored = serialize_value(obj.Anchored) end)
    pcall(function() props.CanCollide = serialize_value(obj.CanCollide) end)
    pcall(function() props.Locked = serialize_value(obj.Locked) end)
    pcall(function() props.CastShadow = serialize_value(obj.CastShadow) end)

    -- Transforms
    pcall(function() props.CFrame = serialize_value(obj.CFrame) end)
    pcall(function() props.Rotation = serialize_value(obj.Rotation) end)

    -- Light Properties
    if obj:IsA("Light") then
        pcall(function() props.Brightness = serialize_value(obj.Brightness) end)
        pcall(function() props.Range = serialize_value(obj.Range) end)
        pcall(function() props.Shadows = serialize_value(obj.Shadows) end)
    end

    -- Text/Gui Properties (Basic)
    pcall(function() props.Text = serialize_value(obj.Text) end)
    pcall(function() props.TextColor3 = serialize_value(obj.TextColor3) end)
    pcall(function() props.BackgroundTransparency = serialize_value(obj.BackgroundTransparency) end)
    pcall(function() props.BackgroundColor3 = serialize_value(obj.BackgroundColor3) end)

    return props
end

-- 2. Robust Decompiler
local function save_script_source(scriptObj, folderPath)
    -- Skip if not a script type we can read
    if not (scriptObj:IsA("LocalScript") or scriptObj:IsA("ModuleScript") or (scriptObj:IsA("Script") and scriptObj.RunContext == Enum.RunContext.Client)) then
        return
    end

    local attempts = 0
    local success = false
    local source = ""

    while attempts < 5 and not success do
        attempts += 1
        local ok, result = pcall(decompile, scriptObj)

        if ok and result and string.find(result, "failed to decompile bytecode: Too Many Requests") then
            warn("[DUMPER] Rate limit on " .. scriptObj.Name .. " - Waiting 1.5s...")
            task.wait(1.5)
        elseif ok and result and result ~= "" then
            source = result
            success = true
        else
            task.wait(0.1)
        end
    end

    if success then
        writefile(folderPath .. "/source.lua", source)
    else
        warn("[DUMPER] Failed to decompile: " .. scriptObj:GetFullName())
        writefile(folderPath .. "/decompile_failed.txt", "Failed after 5 attempts.")
    end
end

-- 3. Recursive Dumper
local function sanitize_name(name)
    return name:gsub("[^%w%-%_]", "_")
end

local function dump_recursive(instance, currentPath)
    local children = instance:GetChildren()
    local nameCounts = {}

    for _, child in ipairs(children) do
        local safeName = sanitize_name(child.Name)

        -- Handle Duplicates
        if nameCounts[safeName] then
            nameCounts[safeName] += 1
            safeName = safeName .. "_" .. nameCounts[safeName]
        else
            nameCounts[safeName] = 1
        end

        local childPath = currentPath .. "/" .. safeName

        -- Create Folder for Object
        if not isfolder(childPath) then
            makefolder(childPath)
        end

        -- Save Properties
        local props = get_properties(child)
        local json = HttpService:JSONEncode(props)
        writefile(childPath .. "/properties.json", json)

        -- Save Script (if applicable)
        save_script_source(child, childPath)

        -- Recurse
        task.wait() -- Yield to prevent freezing
        dump_recursive(child, childPath)
    end
end

print("[DUMPER] Starting Workspace Dump...")
dump_recursive(Workspace, ROOT_FOLDER)
print("[DUMPER] Dump Complete!")
