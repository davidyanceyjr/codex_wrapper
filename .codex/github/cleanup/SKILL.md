# cleanup

Purpose
-------
Perform post-merge local cleanup and reset session state.

Procedure
---------
1. Confirm the PR was already merged.
2. Confirm the linked issue is closed or note follow-up.
3. Sync `main`, remove stale local/remote branch state, and reset
   `SESSION.md` appropriately.
4. Recommend `finish` or the next candidate task.
