# bisect

Purpose
-------
Locate the commit that introduced a regression.

Procedure
---------
1. Identify known good and bad commits.
2. Start bisect with `git bisect start`, `git bisect bad`, and `git bisect good <commit>`.
3. Run the smallest reliable repro or test at each step.
4. Mark each midpoint good or bad.
5. Summarize the offending commit and likely cause.
