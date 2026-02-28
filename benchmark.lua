local function test_table(...)
    local sum = 0
    for _, v in ipairs({...}) do
        sum = sum + v
    end
    return sum
end

local function test_select(...)
    local sum = 0
    for i = 1, select('#', ...) do
        sum = sum + select(i, ...)
    end
    return sum
end

local t1 = os.clock()
for i = 1, 10000000 do
    test_table(1, 2, 3, 4, 5)
end
local t2 = os.clock()

local t3 = os.clock()
for i = 1, 10000000 do
    test_select(1, 2, 3, 4, 5)
end
local t4 = os.clock()

print(string.format("Table creation time: %.4f seconds", t2 - t1))
print(string.format("Select time: %.4f seconds", t4 - t3))
print(string.format("Improvement: %.2fx", (t2 - t1) / (t4 - t3)))
