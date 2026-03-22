# deliver

Purpose
-------
Deliver the current slice from staged patch to reviewable pull request.

Procedure
---------
1. Verify branch and staged scope readiness.
2. Confirm the commit message, PR title, and PR body were explicitly approved.
3. Perform the mechanical delivery steps:

   - `git add` as needed
   - `git commit`
   - `git push`
   - `gh pr create`

4. Update `SESSION.md` as operational state.
5. End with:

   - a short summary of what `deliver` completed
   - `Next Skill: merge`
   - a short explanation that `merge` will request final merge approval and
     then perform the merge if approved
