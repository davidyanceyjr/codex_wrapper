# merge

Purpose
-------
Merge a review-ready pull request explicitly.

Procedure
---------
1. Confirm the PR is open and ready to merge.
2. Confirm issue-closing linkage is present.
3. Present merge readiness and the exact merge command for approval,
   preferring:

   `gh pr merge <pr-number> --squash --delete-branch`

4. After explicit approval, run the chosen merge command.
5. Verify the PR merged and the linked issue closed.
6. Recommend `cleanup` next.
