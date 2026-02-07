import time

class Instance:
    def __init__(self, name, parent=None):
        self.Name = name
        self.Parent = parent
        self.children = []
        if parent:
            parent.children.append(self)

    def GetChildren(self):
        return self.children

    def GetDescendants(self):
        descendants = []
        for child in self.children:
            descendants.append(child)
            descendants.extend(child.GetDescendants())
        return descendants

# Setup Mock Hierarchy
workspace = Instance("Workspace")
replicated_storage = Instance("ReplicatedStorage")
starter_gui = Instance("StarterGui")

# Add some non-ignored content
for i in range(100):
    Instance(f"Part_{i}", workspace)

# Add a HUGE ignored branch (e.g. PlayerModule)
player_module = Instance("PlayerModule", starter_gui)
for i in range(5000):
    Instance(f"Script_{i}", player_module)

# IGNORE LIST
IGNORE_NAMES = {
    "PlayerModule": True,
    "RbxCharacterSounds": True,
    "ChatScript": True
}

def should_ignore(obj):
    if not obj: return True
    if obj.Name in IGNORE_NAMES: return True
    return False

# BASELINE: GetDescendants
start_time = time.time()
processed_count_baseline = 0
visited_count_baseline = 0

services = [workspace, replicated_storage, starter_gui]

print("--- BASELINE: GetDescendants ---")
for service in services:
    descendants = service.GetDescendants()
    visited_count_baseline += len(descendants)
    for obj in descendants:
        if not should_ignore(obj):
            processed_count_baseline += 1

end_time = time.time()
baseline_duration = end_time - start_time
print(f"Time: {baseline_duration:.4f}s")
print(f"Visited Nodes: {visited_count_baseline}")
print(f"Processed Nodes: {processed_count_baseline}")


# OPTIMIZED: Recursive Scan
start_time = time.time()
processed_count_opt = 0
visited_count_opt = 0

def scan_recursively(obj):
    global processed_count_opt, visited_count_opt
    visited_count_opt += 1

    if should_ignore(obj):
        return

    # Process object
    processed_count_opt += 1

    for child in obj.GetChildren():
        scan_recursively(child)

print("\n--- OPTIMIZED: Recursive Scan ---")
for service in services:
    # scan_recursively counts the root itself as visited/processed too, unlike GetDescendants which only counts descendants.
    # To be fair, let's call it on children or adjust count.
    # The original code calls GetDescendants on service, so service itself is NOT processed in the loop.
    # But recursive scan calls it on service, so service IS processed.
    # Let's align: we want to process descendants.

    # Actually, the recursive function should handle the service root check too.
    # But wait, should_ignore check is done inside scan_recursively.

    # Let's simulate calling it on children to match GetDescendants scope exactly for fair comparison
    # (though in reality we might want to scan the service root too, but let's stick to descendants for now).

    for child in service.GetChildren():
        scan_recursively(child)

end_time = time.time()
opt_duration = end_time - start_time
print(f"Time: {opt_duration:.4f}s")
print(f"Visited Nodes: {visited_count_opt}")
print(f"Processed Nodes: {processed_count_opt}")

print(f"\nImprovement Factor (Nodes Visited): {visited_count_baseline / visited_count_opt:.2f}x")
