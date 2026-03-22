# review

Purpose
-------
Review the current patch for correctness, scope, and readiness.

Procedure
---------
1. Read `git diff` and `git diff --cached`.
2. Check for:

   - unrelated changes
   - missing tests or docs updates
   - accidental behavior changes
   - formatting noise
   - patch-splitting problems

3. Summarize whether the patch is ready and what must change first.
