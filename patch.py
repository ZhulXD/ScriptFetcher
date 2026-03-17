with open("tests/test_units.lua", "r") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if 'print("FAIL: generate_tree_map function not exported")' in line and 'Test execute_full_scan' in lines[i+1]:
        new_lines.append("    failed = failed + 1\nend\n")

with open("tests/test_units.lua", "w") as f:
    f.writelines(new_lines)
