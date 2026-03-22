# start

Purpose
-------
Start or resume work from the correct repository state.

This is the canonical user-facing bootstrap skill. It absorbs the user-facing
roles previously split across `start-session`, `repo-state`, and `next-task`.

Procedure
---------
1. Restore `SESSION.md` if present.
2. Inspect the current repository and GitHub state:

   - `git status --short`
   - `git branch --show-current`
   - `git log --oneline -n 5`
   - relevant issue / PR state when needed

3. Read the active source-of-truth documents:

   - `docs/design/autopsyctl_concept.md`
   - `docs/design/autopsyctl_specification.md`
   - `docs/design/spec-log.md` if present

4. Determine the current workflow stage.
5. Record the live session state in `SESSION.md`.
6. Recommend exactly one next canonical workflow skill.

Output
------
Return:

Current Branch
Active Issue
Workflow Stage
Recommended Next Skill
