# AGENTS.md

Repository-level guidance for agents working in this project.

## Purpose

This file is a top-level entrypoint, not the full workflow definition.

Use it to discover:

- the canonical workflow vocabulary
- where the source-of-truth skill instructions live
- which human-facing workflow documents explain the collaboration model

Do not treat this file as a replacement for the skill library under `.codex/`.

## Canonical Workflow

Use the canonical short names from `.codex/INDEX.md`:

`start -> spec -> issue -> branch -> plan -> pair -> test -> review -> propose -> deliver -> merge -> cleanup -> finish`

Prefer these short names over compatibility shims unless a file explicitly says otherwise.

## Source Of Truth

For workflow naming and routing:

- `.codex/INDEX.md`

For human-facing workflow explanation:

- `.codex/docs/HUMAN_WORKFLOW.md`
- `.codex/docs/PAIR_WORKFLOW.md`

For step-specific operational behavior:

- the relevant `.codex/**/SKILL.md` file for the active workflow step

Step-level procedures should be maintained in the skill files, not duplicated here.

For live session handoff state:

- `SESSION.md`
- `.codex/docs/session_template.md`

`SESSION.md` should be kept short and operational. It is the persistent handoff
record for the current repository state, active slice, open decisions, and next
workflow step. It should not become a long narrative log.

Use `.codex/docs/session_template.md` as the reusable template when initializing or
restructuring the live session file.

## Agent Expectations

When operating in this repository:

- use the canonical workflow sequence unless the human explicitly redirects
- prefer the canonical short skill names in user-facing handoffs
- restore context from `SESSION.md` at session start and update it when ending or pausing work
- end workflow steps with an explicit next-step handoff when applicable:
  - `Next Skill: <name>`
  - a short explanation of what that next skill will do
- treat human operators as owners of problem framing, scope approval, and final uncontrolled decisions
- treat approval checkpoints as the main human pause points; after explicit approval, repetitive git and GitHub commands may be AI-executed
- stop and escalate instead of guessing when a choice affects architecture, interfaces, workflow, compatibility, security, persistence, performance, or maintenance shape
- keep implementation work on issue-mapped branches rather than `main`
- treat `SKILL.md` content as the operational source for each step

## Human And AI Split

Summarized from `.codex/docs/PAIR_WORKFLOW.md`:

- the human owns direction, scope approval, and final decisions on uncontrolled changes
- the human also owns approval of issue text, commit message, PR title/body, and merge actions
- the AI owns bounded execution, status reporting, drafting support, validation guidance, explicit escalation, and repetitive git/GitHub command execution after approval

If a workflow or skill file conflicts with this summary, follow the more specific source document.

## Maintenance Rule

If the workflow changes:

1. update the relevant `SKILL.md` files
2. update `.codex/INDEX.md` if canonical names or routing changed
3. update `.codex/docs/` if the human collaboration model changed
4. update this file only if the top-level entrypoint guidance changed
