-- Mock Roblox Environment
_G = _G or {}

local function create_instance(className, name, parent)
    local obj = {
        ClassName = className,
        Name = name or className,
        Parent = parent
    }
    local children = {}

    function obj:IsA(name)
        return self.ClassName == name or (name == "Instance")
    end

    function obj:GetChildren()
        return children
    end

    function obj:GetFullName()
        if self.Parent and self.Parent ~= game then
            return self.Parent:GetFullName() .. "." .. self.Name
        end
        return self.Name
    end

    function obj:WaitForChild(name, timeout)
        for _, child in ipairs(children) do
            if child.Name == name then return child end
        end
        return nil
    end

    function obj:FindFirstChild(name)
        for _, child in ipairs(children) do
            if child.Name == name then return child end
        end
        return nil
    end

    function obj:SetCore(...) end

    if parent then
        table.insert(parent:GetChildren(), obj)
    end

    return obj
end

-- Global game object
game = {
    PlaceId = 0,
    services = {}
}

function game:GetService(name)
    if not self.services[name] then
        self.services[name] = create_instance(name, name, self)
    end
    return self.services[name]
end

function game:GetChildren()
    local res = {}
    for _, s in pairs(self.services) do
        table.insert(res, s)
    end
    return res
end

-- Players mock
local players = game:GetService("Players")
players.LocalPlayer = {
    Name = "LocalPlayer",
    WaitForChild = function(self, name) return create_instance("Folder", name) end,
    FindFirstChild = function(self, name) return nil end
}

-- Global functions
function writefile(filename, content)
    local f = io.open(filename, "w")
    if f then
        f:write(content)
        f:close()
    end
end

function appendfile(filename, content)
    local f = io.open(filename, "a")
    if f then
        f:write(content)
        f:close()
    end
end

function decompile(scriptObj)
    return "-- Mock decompiled source for " .. scriptObj.Name
end

-- Task mock
task = {
    spawn = function(f) f() end,
    wait = function(n) end
}

-- Other globals
print = print or function(...) end
warn = warn or function(...) end
tick = os.time

return {
    create_instance = create_instance
}
