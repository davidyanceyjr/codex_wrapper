# workflow

Purpose
-------
Manage the GitHub-centered lifecycle: issue -> branch -> PR -> merge.

Procedure
---------
1. Identify or create the relevant issue.
2. Ensure the branch naming ties back to the issue.
3. Check for spec/design/test linkage in issue or PR context.
4. Prepare a PR only when patch review, testing, and docs checks are complete.
5. Ensure the PR summary explains problem, approach, testing, and tradeoffs.
6. Use `merge` to perform the merge only after review-quality checks are done.
7. Use `cleanup` only after the merge is confirmed.
