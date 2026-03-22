# codex-wrapper Behavioral Specification

This document defines the authoritative behavioral specification for `codex-wrapper`.

The wrapper implementation, test harness, and README must conform to this specification.
If implementation behavior differs from this specification, the implementation is wrong.
If tests encode behavior that differs from this specification, the tests are wrong.

This specification covers wrapper-owned behavior only. It does not redefine or guarantee the behavior of external dependencies such as:

* `systemd-run`
* `systemctl`
* `/usr/bin/codex`
* shell pipeline semantics

## 1. Scope

`codex-wrapper` is a shell function that:

* wraps the native `codex` CLI
* chooses an execution mode
* applies an outer `systemd-run` sandbox when available
* applies wrapper-controlled bind mounts
* falls back to a tighter native Codex mode if the outer sandbox does not launch Codex
* forwards native Codex arguments when requested

## 2. Invocation Model

The wrapper interface is:

```text
codex [wrapper options] [--] [codex arguments...]
```

Wrapper-owned options are:

* `--ro PATH...`
* `--ro=PATH`
* `--rw PATH...`
* `--rw=PATH`
* `--help`
* `-h`

Everything after `--` is passed through to the native Codex CLI without wrapper parsing.

## 3. Source of Authority

Behavioral priority is:

1. This specification
2. Tests that explicitly map to this specification
3. Wrapper implementation
4. README and example documentation

The README is descriptive, not authoritative.

## 4. Mode Model

The wrapper has three behavioral modes.

### SPEC-MODE-1: Primary Mode

Primary mode is the preferred execution path.

Primary mode is active when:

* wrapper argument parsing succeeds
* path normalization succeeds
* `systemd-run` is invoked

In primary mode:

* the wrapper launches Codex inside a `systemd-run --user` sandbox
* the native Codex invocation uses `--dangerously-bypass-approvals-and-sandbox`
* the outer `systemd` sandbox is the primary safety boundary

### SPEC-MODE-2: Fallback Mode

Fallback mode is active only if:

* the primary `systemd-run` attempt returns non-zero
* and service inspection indicates that Codex did not actually start

In fallback mode:

* the wrapper does not retry `systemd-run`
* the wrapper launches native Codex directly
* the wrapper applies tighter native Codex controls

Fallback mode is a recovery path, not the preferred path.

### SPEC-MODE-3: Custom Mode

Custom mode is active whenever arguments are passed through after `--`.

In custom mode:

* wrapper options before `--` are still honored by the wrapper
* native Codex arguments after `--` are forwarded without wrapper parsing
* forwarded arguments are appended after wrapper-managed policy arguments for the active mode

Custom mode modifies the native Codex invocation, but does not disable wrapper mode selection.

## 5. Interactive vs Non-Interactive Dispatch

### SPEC-DISPATCH-1

If stdin or stdout is not a TTY, the wrapper must invoke native Codex in non-interactive form by adding:

```text
exec
```

to the Codex command.

### SPEC-DISPATCH-2

If both stdin and stdout are TTYs, the wrapper must invoke native Codex without adding `exec`.

### SPEC-DISPATCH-3

The wrapper must not reinterpret stdin contents. Whatever the shell provides to stdin is what Codex receives.

## 6. Path Parsing and Normalization

### SPEC-PARSE-1

`--ro PATH...` consumes one or more following path arguments until the next wrapper control token or `--`.

### SPEC-PARSE-2

`--rw PATH...` consumes one or more following path arguments until the next wrapper control token or `--`.

### SPEC-PARSE-3

`--ro=PATH` and `--rw=PATH` each consume exactly one path.

### SPEC-PARSE-4

An empty value for `--ro=` or `--rw=` is an error.

### SPEC-PARSE-5

A missing path list after `--ro` or `--rw` is an error.

### SPEC-PARSE-6

All wrapper-provided paths must be canonicalized before use.

### SPEC-PARSE-7

If a wrapper-provided path does not exist, the wrapper must fail before sandbox launch.

### SPEC-PARSE-8

Duplicate `--rw` paths must be deduplicated after canonicalization.

### SPEC-PARSE-9

Duplicate `--ro` paths must be deduplicated after canonicalization.

### SPEC-PARSE-10

If the same canonical path appears in both `--rw` and `--ro`, the `--rw` entry wins and the `--ro` entry must be suppressed.

## 7. Primary Mode Sandbox Construction

### SPEC-PRIMARY-1

Primary mode must launch with:

```text
systemd-run --user
```

### SPEC-PRIMARY-2

Primary mode must bind the current `PWD` as read-write in the outer sandbox.

### SPEC-PRIMARY-3

Primary mode must bind `~/.codex` as read-write in the outer sandbox.

### SPEC-PRIMARY-4

If present, the following paths must be bound read-only in primary mode:

* `~/.config/gh`
* `~/.gitconfig`
* `~/.config/git`
* `/etc/ssl`
* `/etc/hosts`
* `/etc/resolv.conf`

### SPEC-PRIMARY-5

Each canonical `--ro` path must be bound read-only in primary mode.

### SPEC-PRIMARY-6

Each canonical `--rw` path must be bound read-write in primary mode.

### SPEC-PRIMARY-7

If `SSH_AUTH_SOCK` is set and points to a socket, that socket must be exposed read-only and exported into the sandbox environment.

### SPEC-PRIMARY-8

Primary mode does not automatically expose `~/.ssh`.

### SPEC-PRIMARY-9

Primary mode must pass `--dangerously-bypass-approvals-and-sandbox` to the native Codex CLI.

## 8. Fallback Mode Construction

### SPEC-FALLBACK-1

Fallback mode must launch native Codex directly, without the outer `systemd-run` wrapper.

### SPEC-FALLBACK-2

Fallback mode must apply:

```text
--ask-for-approval on-request
--sandbox workspace-write
-c sandbox_workspace_write.network_access=true
--cd <launch-directory>
```

### SPEC-FALLBACK-3

Fallback mode must be rooted at the original launch directory by passing `--cd <launch-directory>`.

### SPEC-FALLBACK-4

Fallback mode must not pass wrapper `--ro` or `--rw` paths through as native Codex `--add-dir` arguments unless this specification is revised to require it.

### SPEC-FALLBACK-5

Fallback mode exists to constrain Codex more tightly than primary mode when the outer sandbox is unavailable.

## 9. Argument Forwarding Rules

### SPEC-FWD-1

Arguments after `--` must be forwarded in order.

### SPEC-FWD-2

Wrapper-owned policy flags must be stripped from pre-`--` native arguments before the wrapper injects its own active-mode policy flags.

### SPEC-FWD-3

In primary mode, forwarded native arguments must appear after `--dangerously-bypass-approvals-and-sandbox`.

### SPEC-FWD-4

In fallback mode, forwarded native arguments must appear after fallback policy arguments.

## 10. Failure Semantics

### SPEC-FAIL-1

If parsing fails, the wrapper must exit non-zero and must not invoke `systemd-run` or native Codex.

### SPEC-FAIL-2

If path normalization fails, the wrapper must exit non-zero and must not invoke `systemd-run` or native Codex.

### SPEC-FAIL-3

If primary mode fails after Codex actually started inside `systemd-run`, the wrapper must not invoke fallback mode.

### SPEC-FAIL-4

If primary mode fails before Codex started, the wrapper may invoke fallback mode once.

## 11. Security Intent

This specification encodes the intended security model:

* primary mode trusts the outer `systemd` sandbox
* fallback mode trusts native Codex approval and workspace sandbox controls
* wrapper `--ro` and `--rw` affect the outer sandbox only
* default exposure must remain narrow and explicit

This specification does not claim that external tools are bug-free. It defines what the wrapper must request and how it must behave.

## 12. Testing Requirements

Tests derived from this specification must:

* identify which SPEC rule or rules they verify
* report human-readable inputs, expected outputs, actual outputs, and PASS/FAIL
* fail when implementation behavior diverges from the specification

Tests must not be weakened solely to match accidental implementation behavior.

## 13. Documentation Requirements

The README must remain consistent with this specification, but may simplify language for readability.

If README text and this specification differ, this specification wins.
