# AGENTS.md

Directory-specific guidance for agents working in `test/`.

## Scope

This file applies to validation content under `test/`.

Use it together with the repository-level `AGENTS.md`. If guidance conflicts,
this file controls for files inside `test/`.

## Purpose

The `test/` tree holds executable validation for the wrapper.

Changes here should strengthen confidence in controlled behavior without
quietly redefining the specification.

## Content Routing

Treat files in `test/` according to the validation role they serve:

- regression coverage: lock behavior already required by `SPEC.md`
- harness support: keep helpers readable, deterministic, and narrowly scoped
- failure-path coverage: verify rejected or fallback behavior without weakening fail-closed expectations

Current contents imply these local norms:

- the suite is Bats-based and should stay easy to run from the repo root
- `test/helper/` and `test/stubs/` are support layers, not behavior specs by themselves
- tests should describe externally visible behavior rather than helper implementation details when possible

## Validation Expectations

When editing files in `test/`:

- treat `SPEC.md` and the approved slice as the behavior source of truth
- prefer the smallest test change that proves the intended behavior or regression boundary
- add nominal and failure coverage when behavior changes cross parser, sandbox, or fallback boundaries
- keep fixtures and stubs explicit enough that failures are diagnosable from test output
- avoid brittle assertions on incidental formatting unless that formatting is part of the contract
- keep runtime and setup cost modest so the suite stays usable during `pair` and `test`

## Workflow Notes

- `test` lane work may proceed in parallel with `docs` or `src` only when ownership is clear
- if a test exposes an uncontrolled behavior question, stop and escalate in `spec` or `pair` instead of encoding a guess
- when debug instrumentation is temporary, keep it out of committed tests unless the instrumentation itself is part of the contract
