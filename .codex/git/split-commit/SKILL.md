# split-commit

Purpose
-------
Separate a noisy patch into logical commits.

Procedure
---------
1. Read the full diff.
2. Group hunks by concern: feature, refactor, test, docs, cleanup.
3. Recommend split order.
4. Suggest specific staging commands such as `git add -p`.
5. Ensure each proposed commit is coherent and reviewable.
