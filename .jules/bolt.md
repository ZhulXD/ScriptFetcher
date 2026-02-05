## 2024-05-22 - [Roblox Filtered Traversal]
**Learning:** `GetDescendants()` is inefficient for filtered scanning because it allocates the entire tree (O(N)) before filtering. Recursive traversal allows O(N - Ignored) complexity by pruning entire branches early.
**Action:** Use recursive `GetChildren()` instead of `GetDescendants()` when scanning large trees with known ignored subtrees.
