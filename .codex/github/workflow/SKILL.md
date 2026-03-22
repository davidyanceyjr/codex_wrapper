# workflow

Purpose
-------
Manage the GitHub-centered lifecycle: issue -> branch -> PR -> merge.

Procedure
---------
1. Identify or create the relevant issue using the approval checkpoint model.
2. Ensure the branch naming ties back to the issue and is approved before branch creation.
3. Check for spec/design/test linkage in issue or PR context.
4. Prepare a PR only when patch review, testing, and docs checks are complete.
5. Ensure the PR summary explains problem, approach, testing, and tradeoffs.
6. Treat commit text, PR text, and merge action as explicit approval checkpoints.
7. Use `merge` only after review-quality checks are done and merge approval is explicit.
8. Use `cleanup` only after the merge is confirmed.
