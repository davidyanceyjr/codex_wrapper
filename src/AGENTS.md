# AGENTS.md

Directory-specific guidance for agents working in `src/`.

## Scope

This file applies to implementation files under `src/`.

Use it together with the repository-level `AGENTS.md`. If guidance conflicts,
this file controls for files inside `src/`.

## Purpose

The `src/` tree contains the wrapper implementation. Treat behavior in this
tree as specification-driven, not example-driven.

## Content Routing

Treat files in `src/` as implementation artifacts:

- executable logic: preserve the controlled behavior defined by `SPEC.md`
- shell helpers or support functions: optimize for readability, reviewability, and narrow scope
- user-visible behavior changes: require corresponding validation and documentation alignment

Current contents imply these local norms:

- `src/codex_wrapper.sh` is Bash, structured around small `__codex_wrapper_*` helper functions
- command construction should use Bash arrays and null-safe argument flows rather than string-built shell commands
- parsing, path normalization, mode selection, sandbox launch, and fallback behavior are intentionally separated into distinct helpers
- logging and debug output are optional and gated rather than mixed into normal control flow

## Implementation Expectations

When editing files in `src/`:

- treat `SPEC.md` as the authoritative behavior contract
- preserve fail-closed behavior when the specification is ambiguous; stop and escalate instead of guessing
- keep changes narrowly scoped to the active issue and workflow slice
- prefer small shell changes that are easy to validate and review
- maintain compatibility with the existing test harness under `test/`
- preserve the existing helper-oriented function layout unless there is a strong reason to refactor it
- prefer array-based command assembly, quoted expansions, and explicit return paths
- avoid `eval`, implicit word-splitting patterns, or string-concatenated command execution
- keep wrapper help text aligned with actual parser and runtime behavior

## Validation Notes

- add or update tests when implementation behavior changes
- keep README and docs consistent with implementation changes, but do not let documentation override `SPEC.md`
- do not broaden sandbox, approval, or filesystem exposure semantics without an explicit spec update first
- for parser or argv changes, verify both interactive and non-interactive paths when relevant
- for sandbox or fallback changes, verify that primary and fallback mode boundaries still match `SPEC.md`
