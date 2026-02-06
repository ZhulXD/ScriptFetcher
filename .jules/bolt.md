## 2025-02-18 - [Roblox Instance Traversal]
**Learning:** `GetDescendants()` in Roblox allocates a table of all nodes and flattening hierarchy prevents pruning.
**Action:** Use recursive `GetChildren()` with early returns (`should_ignore`) for deep scanning tasks to save memory and CPU.
