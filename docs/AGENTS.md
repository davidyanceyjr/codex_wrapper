# AGENTS.md

Directory-specific guidance for agents working in `docs/`.

## Scope

This file applies to documentation content under `docs/`.

Use it together with the repository-level `AGENTS.md`. If guidance conflicts,
this file controls for files inside `docs/`.

## Purpose

The `docs/` tree holds human-facing operational and reference material.

Changes here should clarify workflow, usage, examples, or handoff mechanics
without silently redefining implementation behavior.

## Content Routing

Treat files in `docs/` according to the kind of help they provide:

- help or reference content: optimize for accuracy, fast lookup, and consistency with actual behavior
- how-to or task walkthrough content: optimize for step order, prerequisites, and operator decision points
- templates or handoff scaffolding: keep structure stable, concise, and easy to reuse in live sessions

Current contents imply these local norms:

- `docs/sample_session_template.md` is a structured operational template, not prose documentation
- enumerated status and workflow values in templates are part of the workflow contract and should only change when the workflow contract changes
- field order and section names in session templates should remain stable unless there is a clear workflow reason to restructure them

## Documentation Expectations

When editing files in `docs/`:

- preserve alignment with `SPEC.md`, `README.md`, and the canonical workflow in `.codex/INDEX.md`
- prefer tightening wording, examples, and operator guidance over broad rewrites
- call out unresolved behavior mismatches instead of inventing undocumented behavior
- keep examples concrete and runnable when possible
- keep session and workflow templates concise and operational
- label assumptions and prerequisites clearly in how-to content
- avoid burying warnings or approval checkpoints inside long prose
- preserve copy-pasteable template structure for session records and handoffs
- keep placeholder text explicit enough that an operator can fill each field without guessing
- when editing templates, verify that every field still maps cleanly to `SESSION.md` usage in this repo

## Workflow Notes

- documentation-only slices may use review-based validation when executable tests are not relevant
- if a docs change implies a behavior or workflow contract change, update the controlling source first or stop and escalate in `spec`
- when adding new workflow-facing docs, use the canonical short workflow names unless a compatibility shim is explicitly required
