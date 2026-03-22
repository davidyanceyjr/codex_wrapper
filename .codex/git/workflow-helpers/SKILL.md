# workflow-helpers

Purpose
-------
Enforce disciplined local repository workflow.

Procedure
---------
1. Inspect `git status --short`, `git diff`, and `git diff --cached`.
2. Confirm current branch naming makes sense.
3. Stage logically grouped changes only.
4. Detect mixed concerns and recommend splitting.
5. Suggest commit messages tied to issue numbers when possible.

Commit Message Shape
--------------------
`type(scope): description (#issue)`
