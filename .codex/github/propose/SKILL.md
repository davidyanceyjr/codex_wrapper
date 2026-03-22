# propose

Purpose
-------
Prepare the reviewable pull request proposal for the current slice.

Procedure
---------
1. Verify PR readiness.
2. Draft a truthful commit message, PR title, and PR body grounded in the diff
   and validation.
3. Include issue-closing linkage.
4. Present the exact text for human approval and identify this as an approval
   checkpoint.
5. Optionally prepare the body file or command that `deliver` will use after
   approval.
6. End with:

   - a short summary of what `propose` produced
   - `Next Skill: deliver`
   - a short explanation that `deliver` will verify staged scope and, after
     approval, perform commit, push, and PR creation
