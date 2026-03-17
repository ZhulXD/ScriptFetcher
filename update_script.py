import re

with open("Game_Context_Scanner.lua", "r") as f:
    content = f.read()

old_logic = """    if handler ~= nil then
        if handler ~= false then
            handler(obj, props)
        end
    else
        local found = false
        for i = 1, #PROPERTY_HANDLERS do
            local mapping = PROPERTY_HANDLERS[i]
            if obj:IsA(mapping.class) then
                if className then
                    CLASS_HANDLER_CACHE[className] = mapping.handler
                end
                mapping.handler(obj, props)
                found = true
                break
            end
        end
        if not found and className then
            CLASS_HANDLER_CACHE[className] = false
        end
    end"""

new_logic = """    if handler == nil then
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
        handler(obj, props)
    end"""

if old_logic in content:
    content = content.replace(old_logic, new_logic)
    with open("Game_Context_Scanner.lua", "w") as f:
        f.write(content)
    print("Success replacing scanner logic")
else:
    print("Failed to find logic in scanner")


with open("tests/test_units.lua", "r") as f:
    test_content = f.read()

replacement = """    local ok, err = pcall(function()
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
    end)"""

start_str = "    local ok, err = pcall(function()\n        -- 1. Test fallback to getgenv().game"
end_str = "        local result3 = scanner.initialize_game(mock_current_game)\n        assert_equal(mock_current_game, result3, \"Should fallback to original current_game if all fallbacks fail\")\n    end)"

if start_str in test_content and end_str in test_content:
    start_idx = test_content.index(start_str)
    end_idx = test_content.index(end_str) + len(end_str)

    test_content = test_content[:start_idx] + replacement + test_content[end_idx:]
    with open("tests/test_units.lua", "w") as f:
        f.write(test_content)
    print("Success fixing test logic")
else:
    print("Failed to find logic in test")
