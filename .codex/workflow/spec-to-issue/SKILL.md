# spec-to-issue

Purpose
-------
Convert closed specification clauses into a tracked implementation issue.

Use When
--------
- a specification slice is closed enough to implement without guessing
- no tracked issue exists yet for that slice
- the next correct step is to create reviewable work from the active spec

Inputs
------
Active concept document
Active specification
`docs/design/spec-log.md` if present
Any existing related issues

Procedure
---------
1. Identify the controlling specification clauses for one bounded implementation slice.
2. Restate the slice as executable repository work, not as a restatement of the whole specification.
3. Define:

   - problem
   - scope
   - non-goals
   - acceptance criteria
   - conformance tests
   - spec references

4. Draft a focused issue title and body.
5. Provide the exact `gh issue create` command needed to create that issue.
6. Recommend a branch slug and branch type prefix.
7. Recommend `branch` as the next action once the issue number exists.

Output
------
Return:

Issue Title:
Issue Body:
Issue Create Command:
Spec References:
Recommended Branch:
Next Skill:
