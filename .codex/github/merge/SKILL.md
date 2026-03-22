# merge

Purpose
-------
Merge a review-ready pull request explicitly.

Procedure
---------
1. Confirm the PR is open and ready to merge.
2. Confirm issue-closing linkage is present.
3. Run the chosen merge command, preferring:

   `gh pr merge <pr-number> --squash --delete-branch`

4. Verify the PR merged and the linked issue closed.
5. Recommend `cleanup` next.
