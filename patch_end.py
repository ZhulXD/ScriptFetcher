with open("tests/test_units.lua", "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.strip() == 'print("FAIL: generate_tree_map function not exported")':
        lines.insert(i + 1, "    failed = failed + 1\nend\n")
        break

with open("tests/test_units.lua", "w") as f:
    f.writelines(lines)
