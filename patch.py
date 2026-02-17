import sys

with open("Game_Context_Scanner.lua", "r") as f:
    lines = f.readlines()

# Locate the lines
start_line = -1
end_line = -1

for i, line in enumerate(lines):
    if 'writefile(FILENAME, "=== GAME CONTEXT SCAN ===' in line:
        start_line = i
    if 'end' in line and 'LOG_BUFFER = {}' in lines[i-1]:
        # This is the end of flush_log?
        pass

# It's safer to just replace the specific block if I can identify it by range or content
# Let's try to match the exact block string

block_start = 'writefile(FILENAME, "=== GAME CONTEXT SCAN ==='
block_end = 'LOG_BUFFER = {}\n        end\n    end\nend'

content = "".join(lines)

search_block = """writefile(FILENAME, "=== GAME CONTEXT SCAN ===\nTime: " .. tostring(os.date()) .. "\nPlace ID: " .. game.PlaceId .. "\n\n")

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
end"""

replace_block = """local success, err = pcall(function()
    writefile(FILENAME, "=== GAME CONTEXT SCAN ===\nTime: " .. tostring(os.date()) .. "\nPlace ID: " .. game.PlaceId .. "\n\n")
end)
if not success then
    warn("[SCANNER] Failed to create log file: " .. tostring(err))
end

-- OPTIMIZATION: Buffer logs to reduce I/O
local LOG_BUFFER = {}
local BUFFER_SIZE = 1000

local function flush_log()
    if #LOG_BUFFER > 0 then
        -- appendfile is expensive, so we do it once per chunk
        local ok, writeErr = pcall(appendfile, FILENAME, table.concat(LOG_BUFFER, "\n") .. "\n")
        if not ok then
            warn("[SCANNER] Failed to append log: " .. tostring(writeErr))
        end
        if table.clear then
            table.clear(LOG_BUFFER)
        else
            LOG_BUFFER = {}
        end
    end
end"""

if search_block in content:
    new_content = content.replace(search_block, replace_block)
    with open("Game_Context_Scanner.lua", "w") as f:
        f.write(new_content)
    print("Success")
else:
    print("Search block not found")
    # Debug info
    print("Content snippet:")
    print(content[content.find("writefile(FILENAME"):content.find("end", content.find("writefile(FILENAME"))+200])
    sys.exit(1)
