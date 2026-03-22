Reference only.
Not required for runtime skill dispatch.

# AI + Human Pair Workflow

This document explains the collaboration model inside the canonical workflow.
For a human-oriented overview of the whole workflow, read
`.codex/docs/HUMAN_WORKFLOW.md`.

Canonical lifecycle:

concept -> spec -> issue -> branch -> plan -> pair -> test -> debug -> review -> propose -> deliver -> merge -> cleanup -> finish

## Human owns

- `gh issue create`
- `git switch -c ...`
- problem framing
- scope approval
- final choice on uncontrolled implementation decisions that affect solution
  shape, interfaces, architecture, workflow, compatibility, security,
  persistence, performance, or maintenance
- review of whether the active slice is still the right slice
- `git commit`
- `git push`
- `gh pr create`
- `gh pr merge`
- local cleanup

## AI owns

- issue drafting from closed spec clauses
- branch naming guidance
- specification critique and closure guidance
- implementation planning
- bounded execution inside the approved slice
- test generation
- patch review
- PR drafting
- cleanup checklist
- decision briefs for uncontrolled implementation choices

## Collaboration Contract For `pair`

During `pair`, the human and AI should divide work this way:

- The human defines the goal of the slice and approves its boundaries.
- The AI restates the slice before acting.
- The AI says what it will do now, what it needs the human to decide, and what
  validation will close the slice.
- The AI performs the bounded execution work.
- The human reviews whether the work stayed inside scope.
- If an uncontrolled decision appears, the AI stops and escalates instead of
  improvising.

The intent is not for the human to micromanage commands.
The intent is for the human to control direction while the AI carries the
bounded implementation work.

At the end of a `pair` slice, the AI should make the handoff explicit:
- what changed
- what remains open
- the next skill
- what that next skill will do

This keeps the human in control of the transition instead of forcing them to
guess the meaning of the next step name.

## Session loop

1. `start`
2. If concept/spec are not ready: `spec`
3. `issue`
4. `branch`
5. `plan`
6. `pair`
7. if an implementation choice is open, stop and present a decision brief
8. `test`
9. debug skills as needed
10. `review`
11. `propose`
12. `deliver`
13. `merge`
14. `cleanup`
15. `finish`

## Safety rules

- never implement on `main`
- no implementation branch without an issue number
- no implementation without a tracked issue unless explicitly overridden
- `SESSION.md` must be updated at session start and end
- implement in small slices, then verify before widening scope
- if behavior is not already controlled, stop and escalate instead of guessing
- every PR must include `Fixes #<issue>` or equivalent
- after merge, delete local branch and prune stale remote refs
