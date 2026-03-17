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

if old_logic in content:
    print("Found old logic")
else:
    print("Old logic missing")
