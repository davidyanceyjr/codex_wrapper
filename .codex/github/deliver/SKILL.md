# deliver

Purpose
-------
Deliver the current slice from staged patch to reviewable pull request.

Procedure
---------
1. Verify branch and staged scope readiness.
2. Commit with issue linkage.
3. Push the branch.
4. Create the PR using the prepared proposal.
5. Update `SESSION.md` as operational state.
6. End with:

   - a short summary of what `deliver` completed
   - `Next Skill: merge`
   - a short explanation that `merge` will merge the review-ready PR once the
     human is satisfied with the review state
