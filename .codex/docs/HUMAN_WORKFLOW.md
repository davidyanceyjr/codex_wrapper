Reference for human operators.

# Human Workflow Guide

This guide explains the repository's canonical workflow in plain language.

The user-facing workflow is:

`start -> spec -> issue -> branch -> plan -> pair -> test -> review -> propose -> deliver -> merge -> cleanup -> finish`

## What The Workflow Is For

The workflow exists to keep work traceable and reviewable.

The intended chain is:

concept -> specification -> issue -> branch -> implementation -> validation -> PR -> merge -> cleanup

The short skill names are meant to be easy to remember. You should not need
deep Git knowledge to know which workflow step comes next.

At each step transition, the AI should tell you:
- the next skill
- what that next skill will do

That handoff is important because it gives you a chance to intervene, redirect,
or reshape the collaboration before the workflow moves forward.

The human pause points in this workflow are approval checkpoints, not routine
terminal mechanics.

When the AI reaches an approval checkpoint, it should:
- make the needed approval explicit
- present its recommendation
- present the exact text or action to approve when relevant
- pause before continuing

After explicit approval, the AI may perform the repetitive terminal steps on
the human's behalf.

## The Steps

### `start`

Use `start` to begin or resume work.

It should:
- restore context from `SESSION.md`
- inspect the current repo state
- identify the active issue and stage
- recommend the next workflow step

Use this instead of trying to reason from branch state manually.

### `spec`

Use `spec` when the idea, design, or specification is still unclear.

This step is about closing ambiguity before implementation starts.

If a real implementation choice is still uncontrolled, stay in `spec`.

### `issue`

Use `issue` to create the tracked work item for one bounded slice.

The issue should explain:
- the problem
- the scope
- the non-goals
- the acceptance criteria
- the validation expected

The AI should draft the issue content first. The human approves the wording.
After approval, the AI may create the issue.

### `branch`

Use `branch` to move the work onto an issue-mapped branch.

Do not do implementation work on `main`.

Exception:
- docs-only workflow-policy maintenance that does not affect runtime behavior may be implemented, committed, and pushed on `main`

The AI should propose the branch name and intent first. After approval, the AI
may create and switch to the branch.

### `plan`

Use `plan` to break the issue into the smallest meaningful slice.

This step decides:
- what will be changed now
- what files are in scope
- which subagent lane owns each part of the slice
- what validation closes the slice
- whether any human decision is still needed

### `pair`

Use `pair` when the human and AI are actively working the implementation
slice together.

This is the main collaboration step.

When useful, `pair` may also assign bounded subagent lanes:
- `docs` for documentation and templates
- `src` for implementation behavior
- `test` for validation assets
- `debug` for repro, triage, and root-cause isolation

These lanes are execution helpers, not separate workflows. The human still owns
direction and approvals. The AI should only use multiple lanes when ownership
is clear and the slice remains bounded.

The human should focus on:
- goals
- scope
- tradeoffs
- architectural or workflow decisions
- reviewing whether the AI stayed within bounds

The AI should focus on:
- carrying out the bounded slice
- reporting what it is doing
- stopping at decision boundaries
- preparing the slice for validation

If the AI reaches a choice that affects architecture, interfaces, workflow,
compatibility, persistence, security, performance, or maintenance shape, the
AI should stop and ask for a human decision instead of guessing.

### `test`

Use `test` to determine or generate the minimum validation needed.

Not every slice needs executable tests. Some workflow or documentation slices
use review-based validation instead.

If validation work is substantial, the AI may treat `test` as its own lane. If
failures are not yet understood, move into the `debug` lane before widening the
implementation slice.

## Subagent Lanes

For solo-engineering pair sessions, use these standard lane names when work is
split across bounded parallel tasks:

- `docs`
- `src`
- `test`
- `debug`

Plans, pair handoffs, and `SESSION.md` should use these names consistently.

### `review`

Use `review` to inspect the current patch before delivery.

This is where you check:
- scope drift
- missing docs or tests
- accidental behavior changes
- whether the slice should be split

### `propose`

Use `propose` to prepare the pull request proposal.

This is the step where the commit message, PR title, PR body, and
issue-closing line are drafted.

This is an approval checkpoint. The human should review and approve or edit the
proposed text before delivery continues.

### `deliver`

Use `deliver` when the staged patch is ready to become a reviewable PR.

This step covers:
- final staged-scope verification
- commit
- push
- PR creation

After the human approves the commit message and PR text, the AI may perform the
mechanical delivery commands.

### `merge`

Use `merge` when the PR is ready to be merged.

This is a separate step on purpose. Cleanup should not be confused with the
merge itself.

This is also an approval checkpoint. The AI should summarize merge readiness
and recommend the merge action. After explicit approval, the AI may perform the
merge command and continue to cleanup.

### `cleanup`

Use `cleanup` only after merge is already complete.

This step returns the local repository to a clean state and records the new
session state.

### `finish`

Use `finish` when stopping work for now.

This updates `SESSION.md` so the next session can restart cleanly.

## Step Handoffs

Workflow steps should not end with only a command or only a skill name.

They should end with an explicit handoff:
- `Next Skill: <name>`
- a short explanation of what that next skill will do

That preserves human ownership. It tells the human what is about to happen
without forcing the human to infer the workflow from tool names alone.

It also leaves room for the human to interrupt, redirect, or refine the next
slice before the AI continues.

At approval checkpoints, the handoff should identify:
- what approval is needed
- the AI's recommendation
- the exact text or command that will be used after approval

## How To Work With The AI

The AI is an execution and process partner, not the final authority.

Use the AI to:
- read repository state
- draft issues and PRs
- plan slices
- implement bounded changes
- generate validation ideas
- review patch scope and workflow consistency
- perform repetitive git and GitHub commands after explicit human approval

The human should retain authority over:
- what problem is worth solving
- whether the current slice is the right slice
- architecture and workflow decisions
- accepting tradeoffs
- approval of issue text, commit message, PR title/body, and merge actions

## If You Are Unsure What To Type

In most sessions:
1. start with `start`
2. follow the one next step it recommends
3. stay in the canonical short-name workflow

If you find yourself choosing among old long-form names, you are probably
looking at compatibility shims rather than the primary workflow.
