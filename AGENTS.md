# AGENTS.md

Repository-level guidance for agents working in this project.

This file applies repository-wide unless a deeper `AGENTS.md` in a subdirectory
overrides or extends it for files under that subtree.

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

## Subagent Lanes

When a slice benefits from parallel bounded work, use these standard subagent
lanes:

- `docs`: human-facing documentation, examples, templates, and workflow text
- `src`: implementation behavior under `src/`
- `test`: validation assets and harness changes under `test/`
- `debug`: reproduction, triage, instrumentation, and root-cause isolation

Use these lane names consistently in plans, pair handoffs, and session state.

Only split work across lanes when:

- ownership is clear
- file scope is disjoint or coordination is explicit
- the human-approved slice is still bounded
- no uncontrolled architectural or workflow decision is being delegated

When a lane is active, route it by content first:

- `docs` follows `docs/AGENTS.md` when work lands under `docs/`
- `src` follows `src/AGENTS.md` and `SPEC.md`
- `test` follows `test/AGENTS.md`
- `debug` follows this file plus the relevant `.codex/debug/**/SKILL.md`

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
- docs-only workflow-policy maintenance may be implemented, committed, and pushed on `main` when the change does not affect runtime behavior
- treat `SKILL.md` content as the operational source for each step

## Subtree Routing

When work is concentrated in a specific subtree, prefer the nearest
`AGENTS.md` for local operating rules while still honoring this top-level file
for repository-wide workflow behavior.

Route work by the context of the content first, then by directory:

- implementation code or runtime behavior: follow `src/AGENTS.md` and `SPEC.md`
- help, reference, examples, or operator-facing walkthroughs: follow `docs/AGENTS.md`
- validation assets and harness behavior: follow `test/AGENTS.md`
- workflow policy, collaboration rules, and session mechanics: follow this file plus `.codex/**` sources of truth
- mixed changes: apply the stricter rule set for each touched artifact and stop in `spec` if the content categories conflict

Current subtree-specific guidance files:

- `docs/AGENTS.md`
- `src/AGENTS.md`
- `test/AGENTS.md`

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
