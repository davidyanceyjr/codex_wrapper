# worktree

Purpose
-------
Use git worktrees to isolate concurrent work safely.

Procedure
---------
1. Identify the branch or new branch needed.
2. Create the worktree with `git worktree add`.
3. Verify with `git worktree list`.
4. Use the new directory for isolated work.
5. Remove stale worktrees with `git worktree remove` and clean metadata with `git worktree prune`.
