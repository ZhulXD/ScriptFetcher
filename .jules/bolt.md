## 2026-02-06 - [Roblox Traversal Optimization]
**Learning:** `GetDescendants()` in Roblox is a flat list generator that precludes branch pruning. For tasks requiring filtering of large subtrees (like ignoring `PlayerModule`), recursive `GetChildren()` is vastly superior (O(Relevant) vs O(Total)).
**Action:** Always prefer recursive traversal over flat iterators when "ignore" logic exists for container objects.
