## 2024-05-23 - Recursive Pruning vs Flat Iteration
**Learning:** In Roblox API, `GetDescendants()` is convenient but eagerly allocates all nodes and prevents pruning. For scans where large subtrees (like standard libraries) are ignored, recursive `GetChildren()` is significantly faster (O(RelevantNodes) vs O(AllNodes)) because it allows skipping traversal of ignored branches entirely.
**Action:** When optimizing tree traversals with ignore conditions, always verify if the API supports partial traversal (like recursion) versus eager retrieval.
