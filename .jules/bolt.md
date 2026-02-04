# Bolt's Journal

## 2024-10-24 - Roblox Deep Scan Optimization
**Learning:** `GetDescendants()` is convenient but allocates the entire tree and prevents pruning. For scanners that ignore branches (like `PlayerModule` or `Chat`), recursive `GetChildren()` is vastly superior (O(Pruned N) vs O(N)).
**Action:** Always check if a traversal logic implies "ignoring" containers. If so, replace `GetDescendants()` with recursion.
