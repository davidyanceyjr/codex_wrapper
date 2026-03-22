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

### `branch`

Use `branch` to move the work onto an issue-mapped branch.

Do not do implementation work on `main`.

### `plan`

Use `plan` to break the issue into the smallest meaningful slice.

This step decides:
- what will be changed now
- what files are in scope
- what validation closes the slice
- whether any human decision is still needed

### `pair`

Use `pair` when the human and AI are actively working the implementation
slice together.

This is the main collaboration step.

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

### `review`

Use `review` to inspect the current patch before delivery.

This is where you check:
- scope drift
- missing docs or tests
- accidental behavior changes
- whether the slice should be split

### `propose`

Use `propose` to prepare the pull request proposal.

This is the step where the PR title, body, and issue-closing line are drafted.

### `deliver`

Use `deliver` when the staged patch is ready to become a reviewable PR.

This step covers:
- final staged-scope verification
- commit
- push
- PR creation

### `merge`

Use `merge` when the PR is ready to be merged.

This is a separate step on purpose. Cleanup should not be confused with the
merge itself.

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

## How To Work With The AI

The AI is an execution and process partner, not the final authority.

Use the AI to:
- read repository state
- draft issues and PRs
- plan slices
- implement bounded changes
- generate validation ideas
- review patch scope and workflow consistency

The human should retain authority over:
- what problem is worth solving
- whether the current slice is the right slice
- architecture and workflow decisions
- accepting tradeoffs
- merging and cleanup decisions when judgment is needed

## If You Are Unsure What To Type

In most sessions:
1. start with `start`
2. follow the one next step it recommends
3. stay in the canonical short-name workflow

If you find yourself choosing among old long-form names, you are probably
looking at compatibility shims rather than the primary workflow.
