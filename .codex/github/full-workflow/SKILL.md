---
name: full-workflow
description: Use when work needs the complete repository Git and GitHub lifecycle in one procedure: create or identify an issue, create the issue-mapped branch, stage and commit focused changes, push the branch, create a PR that auto-closes the issue, merge it, and clean up local and remote branch state afterward.
---

# full-workflow

Purpose
-------
Run the repository's full tracked delivery flow:

`issue -> branch -> add -> commit -> push -> PR -> merge -> cleanup`

Use When
--------
- the user wants one end-to-end Git/GitHub workflow
- a tracked implementation slice is ready to move from issue creation through merge
- issue auto-closing and post-merge cleanup must be handled consistently

Inputs
------
- active issue number, or enough context to create one
- approved source-of-truth spec or bug context
- current branch and worktree state
- validation evidence for the change
- SESSION.md

Procedure
---------
1. Confirm readiness

   - Verify the current stage is compatible with implementation or merge work.
   - Do not proceed from a specification gap; create or fix the governing issue/spec first.
   - Inspect `git status --short`, current branch, and any already-staged changes.

2. Identify or create the issue

   - If no tracked issue exists, draft and create one with:
     - Problem
     - Why it matters
     - Scope
     - Non-goals
     - Acceptance criteria
     - Conformance tests
     - Spec references
   - Prefer:

     `gh issue create --title "<title>" --body-file <file>`

3. Create the issue-mapped branch

   - Branches must never implement directly on `main`.
   - Use the repository convention:

     `<type>/<issue-number>-<slug>`

   - Preferred sequence:

     `git switch main`

     `git pull --ff-only`

     `git switch -c <type>/<issue-number>-<slug>`

4. Prepare the local patch

   - Review `git diff` and `git diff --cached`.
   - Stage only one logical unit of work.
   - If mixed concerns are present, split them before committing.
   - Use targeted `git add <path>` over broad staging when possible.

5. Commit with issue linkage

   - Commit message shape:

     `type(scope): description (#issue)`

   - Example:

     `feat(cli): emit deterministic invalid-artifact metadata (#42)`

6. Push the branch

   - Push with upstream tracking:

     `git push -u origin <type>/<issue-number>-<slug>`

7. Create the PR with auto-closing issue linkage

   - PR body must state:
     - Problem
     - Approach
     - Testing
     - Notes/Tradeoffs
   - Include an explicit closing line in the PR body so GitHub closes the issue on merge:

     `Closes #<issue-number>`

   - Preferred command:

     `gh pr create --title "<pr-title>" --body-file <file>`

8. Merge deliberately

   - Merge only after review-quality checks, validation, and doc/test updates are complete.
   - Default merge command:

     `gh pr merge --squash --delete-branch`

   - If repository policy or the user requires a different merge mode, state that explicitly.

9. Verify closure and clean up

   - Confirm the PR merged.
   - Confirm the linked issue is closed.
   - Sync local default branch and remove stale branch state:

     `git switch main`

     `git pull --ff-only`

     `git branch -d <type>/<issue-number>-<slug>`

     `git remote prune origin`

10. Update session state

   - Record:
     - merged PR
     - closed issue
     - current branch
     - current stage
     - next candidate task
     - validation commands to rerun if needed

Decision Rules
--------------
- Do not create implementation branches until the relevant spec slice is closed enough to implement.
- Do not commit unrelated changes together.
- Do not open a PR without validation evidence.
- Do not rely on commit text alone for issue auto-close; include `Closes #<issue-number>` in the PR body.
- Do not recommend branch deletion with `git branch -d` unless the branch is fully merged.
- If the worktree is dirty before branch start, distinguish pre-existing changes from the active slice.

Output
------
Return a concise operator-ready summary:

- Issue: created or confirmed
- Branch: created or confirmed
- Staged scope: paths or logical slice
- Commit: proposed or created
- Push: exact command
- PR: exact `gh pr create` command and closing line
- Merge: exact `gh pr merge` command
- Cleanup: exact post-merge commands
- SESSION.md notes: short summary

Related Skills
--------------
- `workflow/spec-to-issue`
- `github/issue`
- `github/branch`
- `git/workflow-helpers`
- `github/propose`
- `github/deliver`
- `github/merge`
- `github/cleanup`
