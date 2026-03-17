local game = game
local getgenv = getgenv
local cloneref = cloneref

local SCANNER_TEST_MODE = ... == true

local CLASS_TAGS = {
    RemoteEvent = " [REMOTE]",
    RemoteFunction = " [REMOTE]",
    LocalScript = " [SCRIPT]",
    ModuleScript = " [SCRIPT]",
    ScreenGui = " [GUI]"
}

local SOURCE_REPLACEMENTS = {
    ["<<< END SOURCE"] = "\\<\\<\\< END SOURCE",
    [">>> SOURCE: "] = "\\>\\>\\> SOURCE: ",
    ["[PROPERTIES] "] = "\\[PROPERTIES\\] ",
    ["[REMOTE DETECTED] "] = "\\[REMOTE DETECTED\\] ",
    ["=== GAME CONTEXT SCAN ==="] = "\\=\\=\\= GAME CONTEXT SCAN \\=\\=\\=",
    ["=== 1. HIERARCHY MAP (Tree View) ==="] = "\\=\\=\\= 1. HIERARCHY MAP (Tree View) \\=\\=\\=",
    ["=== 2. DEEP SCAN (Code & Remotes) ==="] = "\\=\\=\\= 2. DEEP SCAN (Code & Remotes) \\=\\=\\=",
    ["--- Service: "] = "\\-\\-\\- Service: ",
    ["---"] = "\\-\\-\\-",
    ["=== END OF SCAN ==="] = "\\=\\=\\= END OF SCAN \\=\\=\\="
}

-- Robust initialization for environments with restricted/broken 'game'
local function initialize_game(current_game)
    if current_game and pcall(function() return current_game:GetService("Players") end) then
        return current_game
    end
    if type(getgenv) == "function" and pcall(function() return getgenv().game end) then
        current_game = getgenv().game
    end
    if type(cloneref) == "function" and pcall(function() return cloneref(current_game) end) then
        local s, r = pcall(cloneref, current_game)
        if s and r then current_game = r end
    end
    return current_game
end

game = initialize_game(game)

local function GetService(name)
    if not game then return end
    local success, service = pcall(function() return game:GetService(name) end)
    if success and service then return service end
    -- Fallback for some exploits or older environments
    return game:FindFirstChild(name) or game[name]
end

local Players = GetService("Players")

-- ATTEMPT TO RESOLVE DECOMPILER
local decompile = decompile
if not decompile and type(getgenv) == "function" then
    decompile = getgenv().decompile
end
if not decompile and debug and debug.decompile then
    decompile = debug.decompile
end

local FILENAME = "Game_Context_" .. tostring(game and game.PlaceId or "unknown"):gsub("[^%w]", "") .. ".txt"
local success, err = pcall(function()
    writefile(FILENAME, "=== GAME CONTEXT SCAN ===\nTime: " .. tostring(os.date()) .. "\nPlace ID: " .. tostring(game and game.PlaceId or "unknown") .. "\n\n")
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
        LOG_BUFFER = {}
    end
end

local function append_log(...)
    local len = #LOG_BUFFER
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        len = len + 1
        LOG_BUFFER[len] = v
    end
    len = len + 1
    LOG_BUFFER[len] = "\n"
    if len >= BUFFER_SIZE then
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
    },
    scan_targets = {
        { name = "ReplicatedStorage", tree = true, deep = true },
        { name = "Workspace", tree = true, deep = true },
        { name = "StarterGui", tree = true, deep = true },
        { name = "PlayerGui", tree = true, deep = true, is_player_child = true },
        { name = "StarterPack", tree = false, deep = true },
        { name = "StarterPlayer", tree = false, deep = true }
    }
}

local function should_ignore(obj, ignore_list)
    if not obj then return true end
    -- Fallback to default if not provided
    local list = ignore_list or DEFAULT_CONFIG.ignore_list
    if not obj.Name then return true end
    if list[obj.Name] then return true end

    -- OPTIMIZATION: Skipped IsDescendantOf(CoreGui/etc) checks because we only scan disjoint services.

    -- NOTE: Removed redundant IsDescendantOf checks for CoreGui/Chat
    -- as we strictly scan user services (Workspace, ReplicatedStorage, etc)
    -- which are disjoint from internal services.
    -- If 'game' or 'CoreGui' is added to scan list, restore checks here.
    return false
end

-- 5. HELPER: SANITIZE
-- Precompute lookup table for control characters to avoid string.format and function overhead
local CONTROL_CHARS = {}
for i = 0, 31 do
    local c = string.char(i)
    if c == "\n" then
        CONTROL_CHARS[c] = "\\n"
    elseif c == "\r" then
        CONTROL_CHARS[c] = "\\r"
    elseif c == "\t" then
        CONTROL_CHARS[c] = "\\t"
    else
        CONTROL_CHARS[c] = string.format("\\%03d", i)
    end
end
CONTROL_CHARS[string.char(127)] = "\\127"

local function sanitize(val)
    return (tostring(val):gsub("[%c]", CONTROL_CHARS))
end

-- 4. ROBUST DECOMPILER
local MAX_ATTEMPTS = 5

local function get_script_source(scriptObj)
    if not decompile then return "-- [Decompiler not available]" end
    local attempts = 0
    local retry_delay = 0.02

    while attempts < MAX_ATTEMPTS do
        attempts = attempts + 1
        local ok, result = pcall(decompile, scriptObj)

        if ok and type(result) == "string" and result ~= "" then
            if string.find(result, "failed to decompile bytecode: Too Many Requests", 1, true) then
                warn("[SCANNER] Rate limit on " .. sanitize(scriptObj.Name) .. " - Waiting 1.5s...")
                task.wait(1.5)
            else
                return result
            end
        else
            task.wait(retry_delay)
            retry_delay = math.min(0.1, retry_delay * 2)
        end
    end
    return "-- [Failed to decompile]"
end

-- 6. PROPERTY DUMPER
local function add_prop(props, key, value)
    local len = #props
    len = len + 1; props[len] = key .. ": " .. tostring(value)
end

local function handle_seat(obj, props)
    add_prop(props, "Occupant", obj.Occupant and sanitize(obj.Occupant:GetFullName()) or "nil")
    add_prop(props, "Disabled", obj.Disabled)
end

local function handle_basepart(obj, props)
    -- Only log interesting parts to reduce spam
    local name = obj.Name
    local transparency = obj.Transparency
    local shouldLog = name == "Handle" or transparency > 0.9

    if not shouldLog then
        local lowerName = name:lower()
        shouldLog = lowerName:find("hitbox", 1, true) or lowerName:find("root", 1, true)
    end

    if shouldLog then
        add_prop(props, "Size", obj.Size)
        add_prop(props, "Transparency", transparency)
        add_prop(props, "CanCollide", obj.CanCollide)
        add_prop(props, "Position", obj.Position)
    end
end

local function handle_tool(obj, props)
    add_prop(props, "Enabled", obj.Enabled)
    add_prop(props, "Grip", obj.Grip)
    if obj.ToolTip ~= "" then add_prop(props, "ToolTip", sanitize(obj.ToolTip)) end
    if obj.TextureId ~= "" then add_prop(props, "TextureId", sanitize(obj.TextureId)) end
end

local function handle_proximity_prompt(obj, props)
    add_prop(props, "ActionText", sanitize(obj.ActionText))
    add_prop(props, "ObjectText", sanitize(obj.ObjectText))
    add_prop(props, "HoldDuration", obj.HoldDuration)
    add_prop(props, "KeyCode", obj.KeyboardKeyCode)
end

local function handle_humanoid(obj, props)
    add_prop(props, "Health", obj.Health)
    add_prop(props, "MaxHealth", obj.MaxHealth)
    add_prop(props, "WalkSpeed", obj.WalkSpeed)
    add_prop(props, "JumpPower", obj.JumpPower)
    add_prop(props, "RigType", obj.RigType)
end

local function handle_click_detector(obj, props)
    add_prop(props, "MaxActivationDistance", obj.MaxActivationDistance)
end

local function handle_value(obj, props)
    add_prop(props, "Value", sanitize(obj.Value))
end

local function handle_text(obj, props)
    add_prop(props, "Text", '"' .. sanitize(obj.Text) .. '"')
    add_prop(props, "Visible", obj.Visible)
    local className = obj.ClassName
    if className == "TextButton" or className == "TextBox" then
        add_prop(props, "Active", obj.Active)
    end
end


local function handle_image(obj, props)
    add_prop(props, "Image", sanitize(obj.Image))
    add_prop(props, "Visible", obj.Visible)
    if obj.ClassName == "ImageButton" then
        add_prop(props, "Active", obj.Active)
    end
end

local PROPERTY_HANDLERS = {
    { class = "Seat", handler = handle_seat },
    { class = "VehicleSeat", handler = handle_seat },
    { class = "BasePart", handler = handle_basepart },
    { class = "Tool", handler = handle_tool },
    { class = "ProximityPrompt", handler = handle_proximity_prompt },
    { class = "Humanoid", handler = handle_humanoid },
    { class = "ClickDetector", handler = handle_click_detector },
    { class = "StringValue", handler = handle_value },
    { class = "IntValue", handler = handle_value },
    { class = "BoolValue", handler = handle_value },
    { class = "NumberValue", handler = handle_value },
    { class = "TextLabel", handler = handle_text },
    { class = "TextButton", handler = handle_text },
    { class = "TextBox", handler = handle_text },
    { class = "ImageButton", handler = handle_image },
    { class = "ImageLabel", handler = handle_image }
}

local CLASS_HANDLER_CACHE = {}
local function get_properties_string(obj)
    if not obj or (type(obj) ~= "table" and type(obj) ~= "userdata") or type(obj.IsA) ~= "function" then return end

    local className = obj.ClassName
    local handler = className and CLASS_HANDLER_CACHE[className]

    if handler == nil then
        handler = false
        for i = 1, #PROPERTY_HANDLERS do
            local mapping = PROPERTY_HANDLERS[i]
            if obj:IsA(mapping.class) then
                handler = mapping.handler
                break
            end
        end
        if className then
            CLASS_HANDLER_CACHE[className] = handler
        end
    end

    if handler then
        local props = {}
        handler(obj, props)
        if #props > 0 then
            return table.concat(props, ", ")
        end
    end
end

-- 6. TREE MAP GENERATOR (Optimized with table buffer)
local extract_tree_data -- Forward declaration for recursion

local function get_safe_children(node)
    local success, res = pcall(node.GetChildren, node)
    return success and type(res) == "table" and res or {}
end

local function get_node_tag(node)
    return CLASS_TAGS[node.ClassName] or ""
end

local function parse_tree_node(child, yield_counter, ignore_list, visited)
    local tag = get_node_tag(child)
    local grandChildren = get_safe_children(child)

    local childNodes = nil
    if #grandChildren > 0 then
        childNodes = extract_tree_data(child, grandChildren, yield_counter, ignore_list, visited)
    end

    if tag ~= "" or (childNodes and #childNodes > 0) then
        return {
            name = sanitize(child.Name),
            tag = tag,
            children = childNodes
        }
    end
    return nil
end

extract_tree_data = function(root, cachedChildren, yield_counter, ignore_list, visited)
    visited = visited or {}
    if visited[root] then return {} end
    visited[root] = true
    yield_counter = yield_counter or {count = 0}

    local children = cachedChildren or get_safe_children(root)
    local nodes = {}

    for _, child in ipairs(children) do
        if not should_ignore(child, ignore_list) then
            yield_counter.count = yield_counter.count + 1
            if yield_counter.count >= 100 then
                yield_counter.count = 0
                task.wait()
            end

            local nodeData = parse_tree_node(child, yield_counter, ignore_list, visited)
            if nodeData then
                local len = #nodes
                nodes[len + 1] = nodeData
            end
        end
    end

    return nodes
end
local function serialize_tree_data(nodes, indent, buffer, yield_counter)
    yield_counter = yield_counter or {count = 0}
    local vCount = #nodes
    for i, node in ipairs(nodes) do
        yield_counter.count = yield_counter.count + 1
        if yield_counter.count >= 100 then
            yield_counter.count = 0
            task.wait()
        end

        local isLast = (i == vCount)
        local prefix = isLast and "└── " or "├── "
        local subIndent = isLast and "    " or "│   "

        local bLen = #buffer
        if bLen > 0 then
            bLen = bLen + 1
            buffer[bLen] = "\n"
        end
        if indent ~= "" then
            bLen = bLen + 1
            buffer[bLen] = indent
        end
        bLen = bLen + 1
        buffer[bLen] = prefix
        bLen = bLen + 1
        buffer[bLen] = node.name
        if node.tag ~= "" then
            bLen = bLen + 1
            buffer[bLen] = node.tag
        end

        if node.children and #node.children > 0 then
            serialize_tree_data(node.children, indent .. subIndent, buffer, yield_counter)
        end
    end
end

local function generate_tree_map(root, ignore_list)
    local buffer = {}
    local yield_counter = {count = 0}
    local nodes = extract_tree_data(root, nil, yield_counter, ignore_list)
    serialize_tree_data(nodes, "", buffer, yield_counter)
    return table.concat(buffer)
end

local function process_object(obj)
    local sanitized_name

    -- Dump Properties
    local props = get_properties_string(obj)
    if props then
        sanitized_name = sanitized_name or sanitize(obj:GetFullName())
        append_log("[PROPERTIES] ", sanitized_name, " | ", props)
    end

    -- Log Remote
    local className = obj.ClassName
    if className == "RemoteEvent" or className == "RemoteFunction" then
        sanitized_name = sanitized_name or sanitize(obj:GetFullName())
        append_log("[REMOTE DETECTED] ", sanitized_name)
    end

    -- Dump Script
    if className == "LocalScript" or className == "ModuleScript" then
        sanitized_name = sanitized_name or sanitize(obj:GetFullName())
        append_log("\n>>> SOURCE: ", sanitized_name)

        -- Decompile
        local source = get_script_source(obj)
        if source then
            source = string.gsub(source, "([%[<%-%=]+[%w%s%-%=%.%[%]%(%):%]]+)", function(m)
                local rep = SOURCE_REPLACEMENTS[m]
                if rep then return rep end
                -- Escape if it looks like a potential marker spoof (starts with trigger and contains letters/dashes)
                -- Refined for brackets: Must start with [ and contain uppercase letters like [PROPERTIES]
                if m:find("^<<<") or m:find("^>>>") or m:find("^===") or m:find("^%-%-%-") or (m:find("^%[") and m:find("%u")) then
                    return (m:gsub("[<%>%[\\%-%=]", "\\%0"))
                end
                return m
            end)
            append_log(source)
        end
        append_log("<<< END SOURCE\n")
    end
end

local function deep_scan_recursive(root, yield_counter, ignore_list, callback)
    yield_counter = yield_counter or {count = 0}

    local children = root:GetChildren()
    children = type(children) == "table" and children or {}
    for _, child in ipairs(children) do
        if not should_ignore(child, ignore_list) then
            yield_counter.count = yield_counter.count + 1
            if yield_counter.count >= 100 then
                yield_counter.count = 0
                task.wait()
            end

            callback(child)
            deep_scan_recursive(child, yield_counter, ignore_list, callback)
        end
    end
end

local function get_targets_for_mode(mode, scan_targets)
    local resolved = {}
    for _, target in ipairs(scan_targets) do
        if target[mode] then
            local obj
            if not Players then Players = GetService("Players") end
            if target.is_player_child then
                local player = Players.LocalPlayer
                if player then
                    obj = player:FindFirstChild(target.name)
                end
            else
                obj = GetService(target.name)
            end

            if obj then
                resolved[#resolved + 1] = obj
            end
        end
    end
    return resolved
end

local function do_tree_scan(current_ignore_list, scan_targets)
    append_log("\n=== 1. HIERARCHY MAP (Tree View) ===")
    scan_targets = scan_targets or DEFAULT_CONFIG.scan_targets
    local map_services = get_targets_for_mode("tree", scan_targets)

    for _, service in ipairs(map_services) do
        if service then
            append_log(sanitize(service.Name))
            append_log(generate_tree_map(service, current_ignore_list))
        end
    end
end

local function do_deep_scan(current_ignore_list, scan_targets)
    append_log("\n=== 2. DEEP SCAN (Code & Remotes) ===")
    scan_targets = scan_targets or DEFAULT_CONFIG.scan_targets
    local deep_scan_services = get_targets_for_mode("deep", scan_targets)

    for _, service in ipairs(deep_scan_services) do
        if service then
            print("[SCANNER] Deep Scanning " .. sanitize(service.Name) .. "...")
            append_log("\n--- Service: ", sanitize(service.Name), " ---")

            deep_scan_recursive(service, nil, current_ignore_list, process_object)
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

    local scan_targets = DEFAULT_CONFIG.scan_targets
    if config and config.scan_targets then
        scan_targets = config.scan_targets
    end

    -- A. TREE VIEW
    do_tree_scan(current_ignore_list, scan_targets)

    -- B. DEEP SCAN
    do_deep_scan(current_ignore_list, scan_targets)

    print("[SCANNER] Complete! File Saved: " .. FILENAME)
    append_log("\n=== END OF SCAN ===")
    flush_log() -- Final flush to ensure everything is written

    if game then game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Scan Complete!",
        Text = "Saved to " .. FILENAME,
        Duration = 5
    }) end
end

if not SCANNER_TEST_MODE then
    task.spawn(function()
        task.wait(1)
        execute_full_scan()
    end)
end

local export = {
    execute_full_scan = execute_full_scan,
    DEFAULT_CONFIG = DEFAULT_CONFIG
}


if SCANNER_TEST_MODE then
    export.initialize_game = initialize_game
    export.sanitize = sanitize
    export.should_ignore = should_ignore
    export.get_properties_string = get_properties_string
    export.generate_tree_map = generate_tree_map
    export.get_script_source = get_script_source
    export.flush_log = flush_log
    export.append_log = append_log
    export.GetService = GetService
    export.process_object = process_object
    export.extract_tree_data = extract_tree_data
    export.deep_scan_recursive = deep_scan_recursive
    export.do_tree_scan = do_tree_scan
    export.do_deep_scan = do_deep_scan
    export.get_targets_for_mode = get_targets_for_mode
end

return export
