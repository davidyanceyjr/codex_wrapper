# session-handoff

Purpose
-------
Capture working state so future-you or the next AI session can resume quickly.

Procedure
---------
1. Record current branch, active issue, current stage, completed work, remaining work, blockers, relevant spec clauses, files in play, and commands/tests to rerun.
2. Update `SESSION.md`.
3. Keep notes short and factual.
4. Do not replace the issue/spec/design with session notes.
5. When the repository is in post-merge cleanup on `main`, it is valid for `SESSION.md` to remain intentionally unstaged as a human review buffer while the rest of the working tree is clean.
6. If `SESSION.md` is intentionally left unstaged, state that explicitly so the next session does not treat it as accidental dirt.
