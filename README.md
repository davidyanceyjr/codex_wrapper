# codex-wrapper

A Bash wrapper for the `codex` CLI that runs it inside a **systemd sandbox** with optional, per-run filesystem access controls.

This wrapper is designed to keep Codex powerful **without letting it roam freely across your system**.

---

## Overview

`codex-wrapper` adds a controlled execution layer around:

```
/usr/bin/codex
```

It provides:

* systemd-based sandboxing
* explicit read/write path control
* wrapper-scoped profile resolution on the existing `--profile` flag
* state-setting enable/disable of repo `AGENTS.md` and skill sources
* automatic interactive vs non-interactive handling
* safe fallback when sandboxing fails
* early failure if the configured native Codex executable is missing or not executable

---

## Operating Modes

The wrapper has three practical modes of operation.

### 1. Primary Mode

This is the normal and preferred path.

The wrapper starts `codex` inside a `systemd-run --user` sandbox, then gives the native CLI:

```
--dangerously-bypass-approvals-and-sandbox
```

That is intentional. In this mode, the outer `systemd` sandbox is the main safety boundary, so Codex itself runs wide open inside that boundary.

Default access in primary mode:

* current `PWD` is mounted read-write
* `~/.codex` is mounted read-write
* Git / GitHub configuration is mounted read-only when present:
  * `~/.config/gh`
  * `~/.gitconfig`
  * `~/.config/git`
* selected host context is mounted read-only when present:
  * `/etc/ssl`
  * `/etc/hosts`
  * `/etc/resolv.conf`
* `SSH_AUTH_SOCK` is mounted read-only when an SSH agent is available
* network access is available

Wrapper profiles can override those defaults. For example, `--profile readonly`
exposes the workspace read-only and `--profile offline` disables network access.

Important: the wrapper does **not** automatically mount `~/.ssh`. If you need SSH config files inside the sandbox, either add them explicitly or use the `ssh` wrapper profile. The wrapper still does **not** auto-mount private keys.

```
codex --profile ssh
```

Use primary mode for normal repo work where you want Codex to move quickly but stay confined to the workspace and any paths you explicitly bind.

### 2. Fallback Mode

If `systemd-run` fails before Codex actually starts, the wrapper retries without the outer sandbox using a tighter native Codex configuration:

```
--ask-for-approval on-request
--sandbox workspace-write
-c sandbox_workspace_write.network_access=<true|false>
--cd <launch-directory>
```

This mode is more conservative:

* Codex is rooted at the launch directory
* native workspace-write restrictions apply
* approval is required when Codex decides it should escalate
* the wrapper does not carry wrapper `--ro` / `--rw` / profile mount rules into fallback
* `--profile offline` changes fallback network access to `false`

This is the recovery path when `systemd --user` is unavailable or fails to launch the service.

### 3. Custom Mode

Custom mode is active whenever you pass native Codex CLI arguments after `--`:

```
codex [wrapper options] -- [native codex args...]
```

Example:

```
codex --ro /some/reference/path -- --model gpt-5.4 --search
```

Use custom mode when you want the wrapper to manage the outer execution boundary while still forwarding native Codex features such as:

* model selection
* native Codex profiles
* web search
* structured output
* review subcommands
* ephemeral sessions

The wrapper still injects its own primary or fallback policy flags before the
forwarded native arguments. It also strips wrapper-managed policy flags that
appear before `--` and replaces them with wrapper policy. This includes:

* `--dangerously-bypass-approvals-and-sandbox`
* `--yolo`
* `--full-auto`
* `--ask-for-approval` / `-a`
* `--sandbox` / `-s`
* `--add-dir`
* `--cd`
* `-c`

Everything after `--` is then forwarded as native Codex arguments in order.

Examples:

```
codex -- --model gpt-5.4
```

```
codex -- --profile work
```

```
codex -- --search
```

```
codex -- --ephemeral --json
```

```
codex -- --output-last-message /tmp/codex.out
```

```
codex -- --help
```

Treat policy flags specially. The wrapper already manages sandbox and approval behavior in primary and fallback modes, so passthrough is most useful for native workflow flags rather than trying to redefine the wrapper's safety model.

---

## Key Features

### 1. Systemd Sandbox Execution

Codex is launched via:

```
systemd-run --user
```

With protections such as:

* `ProtectSystem=strict`
* `ProtectHome=tmpfs`
* `NoNewPrivileges=yes`
* isolated `/tmp`

This restricts filesystem access by default.

---

### 2. Runtime Filesystem Permissions

You grant access explicitly per run:

#### Read-only access

```
codex --ro /path/to/dir /another/path
```

Explicit CLI paths passed to `--ro` must already exist or the wrapper fails
before launch. Optional read-only paths contributed by built-in or user wrapper
profiles may be skipped when they are absent.

#### Read-write access

```
codex --rw /path/to/dir /another/path
```

Explicit CLI paths passed to `--rw` must already exist or the wrapper fails
before launch. Optional profile defaults may be skipped when absent unless a
profile explicitly requires them.

These are translated into systemd bind mounts.

#### Wrapper-scoped profiles on `--profile`

The wrapper also consumes the existing `--profile` flag before `--`.

Resolution rules:

* repeated `--profile NAME` values are resolved left-to-right
* `--profile=NAME` is supported and resolves the same way as `--profile NAME`
* unprefixed names prefer wrapper-scoped built-ins
* unknown unprefixed names pass through to native Codex unchanged
* `codex:NAME` forces native passthrough as `--profile NAME`
* `wrapper:NAME` requires a wrapper profile named `NAME` and fails before launch if missing
* native Codex profiles keep their original relative order among native profiles

Built-in wrapper profiles:

* `git`
* `ssh`
* `worktree`
* `readonly`
* `config`
* `config-wide`
* `host-context`
* `offline`
* `online`
* `secrets-safe`

User-defined wrapper profiles:

* live at `~/.codex/wrapper-profiles.d/NAME.profile`
* are consulted after built-ins, so built-in names still win
* support line-based `ro PATH`, `rw PATH`, `deny PATH_OR_GLOB`, and `network on|off|default`
* ignore blank lines and `#` comments
* do not support env passthrough directives in this slice

Profile composition rules:

* profiles are composable and apply left-to-right
* mount rules accumulate
* later scalar settings override earlier scalar settings
* deny rules override both read-only and read-write rules
* explicit `--ro` / `--rw` override profile defaults unless blocked by `secrets-safe`
* explicit `--rw` overrides explicit `--ro` for the same canonical path unless blocked by `secrets-safe`

Selected built-in behavior:

* `git` gives the workspace read-write access plus read-only Git and SSH client config
* `ssh` mounts SSH config and known-hosts and may pass through `SSH_AUTH_SOCK` and `GIT_SSH_COMMAND`
* `readonly` makes the workspace read-only and turns network off
* `offline` turns network off
* `online` turns network on
* `secrets-safe` denies common credential locations even if a broader parent mount remains visible

Security warning: `ssh` does not automatically mount private keys such as `~/.ssh/id_ed25519`.

Examples:

```
codex --profile git
```

```
codex --profile=git
```

```
codex --profile git --profile reviewer
```

```
codex --profile codex:git
```

```
codex --profile config-wide --profile secrets-safe
```

```
codex --profile readonly --profile online
```

#### Toggle repo guidance state

```
codex --agents-off
codex --skills-off
codex --skags-off
```

These flags hide workflow sources for the launched Codex session only.

`--agents-off` hides `AGENTS.md` and `.agents` under the current `PWD`
subtree for that run.

`--skills-off` hides `.agents`, `.codex`, `skills`, and `SKILLS` under the
current `PWD` subtree for that run.

`--skags-off` applies both categories for the same run.

`.agents` belongs to both categories because it can carry AGENTS-style
guidance and skill-routing metadata.

These flags do not rename files or directories, do not use `*.disabled`
entries, and leave on-disk names unchanged after the run, including if Codex
exits, fails, or the wrapper falls back.

If `systemd-run` cannot launch and one or more off-flags were requested, the
wrapper prompts `Continue without <flag>? [Y/n]`; accepting reruns without the
offending flag or flags, and declining exits without running Codex.

---

### 3. Automatic Mode Selection

The wrapper detects how it is being used:

| Scenario               | Behavior     |
| ---------------------- | ------------ |
| Terminal (interactive) | `codex`      |
| Pipe / script / CI     | `codex exec` |

Example:

```
codex
```

→ interactive session

```
echo "fix this code" | codex
```

→ runs `codex exec`

In non-interactive mode, Codex reads a single prompt from `stdin` exactly as the shell constructs it. The wrapper does not reinterpret or merge separate shell inputs for you.

Piped mode works best when your script already knows the full prompt to send, such as:

* a one-shot instruction generated by another command
* logs, diffs, or tool output that should be analyzed once
* a prompt assembled from multiple sources before invoking `codex`
* CI or automation where no interactive session is expected

Prefer interactive `codex` when you want back-and-forth exploration, follow-up questions, or iterative edits driven by conversation.

---

### 4. Dual Sandbox Model

#### Primary (preferred)

Runs inside systemd sandbox:

```
codex --dangerously-bypass-approvals-and-sandbox
```

This disables Codex’s internal sandbox because **systemd is already enforcing isolation**.

---

#### Fallback (safe mode)

If systemd fails:

```
codex --ask-for-approval on-request --sandbox workspace-write
```

Additionally:

```
--cd <launch-directory>
```

and:

```
-c sandbox_workspace_write.network_access=true
```

are applied automatically.

---

## Installation

Clone the repository:

```
git clone <repo-url>
```

Run the installer:

```
cd codex-wrapper
./install.sh
```

The installer:

* installs the wrapper as `~/.local/bin/codex`
* writes uninstall support under `~/.local/share/codex-wrapper/`
* warns if `~/.local/bin` is not currently positioned to override the existing `codex`
* can, with your permission, append managed `PATH` blocks to `~/.bashrc`, `~/.zshrc`, `~/.profile`, `~/.bash_profile`, and `~/.zprofile` so interactive Bash, interactive Zsh, and login shells resolve `codex` from `~/.local/bin`

If you prefer a non-interactive install:

```
./install.sh --yes --bashrc yes
```

Run the wrapper directly:

```
codex [wrapper options] [--] [codex arguments...]
```

Uninstall with:

```
~/.local/share/codex-wrapper/uninstall.sh
```

---

## Usage

```
codex [wrapper options] [--] [codex arguments...]
```

---

## Wrapper Options

### `--ro PATH...`

Mount one or more paths read-only inside the sandbox.

```
codex --ro ~/.ssh ~/.config/git
```

---

### `--rw PATH...`

Mount one or more paths read-write inside the sandbox.

```
codex --rw ~/.local ~/src
```

---

### `--agents-off`

Hide `AGENTS.md` and `.agents` under the current `PWD` subtree for the launched
Codex session only.

```
codex --agents-off
```

---

### `--skills-off`

Hide `.agents`, `.codex`, `skills`, and `SKILLS` under the current `PWD`
subtree for the launched Codex session only.

```
codex --skills-off
```

---

### `--skags-off`

Equivalent to passing both `--agents-off` and `--skills-off`.

```
codex --skags-off
```

---

### `--`

Stops wrapper parsing.

Everything after is forwarded to native Codex in order. Wrapper-managed policy
flags before `--` are stripped and replaced by the wrapper's primary or
fallback policy flags.

```
codex --rw ~/.local -- --model gpt-5-codex
```

You can also pass multiple paths after a single flag:

```
codex --rw ~/.local ~/src ~/worktrees
codex --ro ~/.ssh ~/.config/git
```

---

### `--help`

Shows wrapper help (this document summary).

Alias forms:

* `-h`
* `--wrapper-help`
* `--help-wrapper`

---

## Accessing Real Codex Help

The wrapper intercepts `--help`.

To access the real CLI:

```
codex -- --help
```

or:

```
/usr/bin/codex --help
```

---

## Examples

### Default run

```
codex
```

---

### Allow local package writes

```
codex --rw ~/.local
```

---

### Neovim config workflow

```
cd ~/.config/nvim
codex --rw ~/.local
```

---

### Read-only SSH config

```
codex --ro ~/.ssh
```

---

### Hide AGENTS for one session

```
codex --agents-off
```

---

### Hide skill sources for one session

```
codex --skills-off
```

---

### Hide both AGENTS and skill sources for one session

```
codex --skags-off
```

---

### Combine wrapper + codex args

```
codex --rw ~/.local -- --model gpt-5-codex
```

---

### Script / pipeline usage

```
echo "refactor this function" | codex
```

Piped mode is best when you want to hand Codex one complete prompt and exit.

Common patterns:

```
git diff | codex
```

```
journalctl -u my-service -n 200 | codex
```

```
printf 'Summarize the failure in this log and suggest the next diagnostic step.\n\n' \
  | cat - build.log \
  | codex
```

```
{ printf 'Review this patch for risk and likely regressions.\n\n'; git diff; } | codex
```

Guidelines:

* Build the exact prompt you want before `codex` in the pipeline.
* Use `{ ...; } | codex` or `cat - file` when combining instructions with file contents.
* Treat piped mode as a one-shot request/response interface.
* Use interactive mode instead if the task depends on clarification or multi-step collaboration.

Avoid patterns where an intermediate command consumes or replaces upstream `stdin` unexpectedly. For example, `cat file` reads only the file; `cat - file` reads both `stdin` and the file.

---

### Daily repo work in primary mode

```
codex
```

Best for normal development inside the current repository. Codex can read, edit, run commands, use Git metadata, and reach the network, but only within the outer `systemd` sandbox.

### Daily repo work with SSH config available

```
codex --ro ~/.ssh
```

Use this when the agent needs actual SSH configuration or key material in addition to the default forwarded SSH agent socket.

### Review the current diff non-interactively

```
{ printf 'Review this patch for bugs, risks, and missing tests.\n\n'; git diff; } | codex
```

Good for a one-shot review prompt in CI, pre-commit workflows, or local shell pipelines.

### Use native web search without changing wrapper behavior

```
codex -- --search
```

Useful when the task needs current documentation or release information and you still want the wrapper deciding how Codex runs.

### Emit structured output for automation

```
codex -- --ephemeral --json "Summarize the repository state"
```

Useful for scripts that consume Codex output programmatically.

### Save the final answer to a file

```
codex -- --output-last-message /tmp/codex-last.txt "Write release notes for the staged changes"
```

Useful when another tool needs the final message as an artifact.

### Use a different model or profile

```
codex -- --model gpt-5.4
```

```
codex -- --profile work
```

Useful when you want repo-local wrapper behavior but need different native Codex defaults.

### Run the native review workflow through the wrapper

```
codex -- review
```

Useful when you want Codex's non-interactive review command while still keeping the wrapper in front.

### Add extra read-only reference material

```
codex --ro ~/docs ~/design-notes
```

Useful when the agent should consult external reference material without being allowed to modify it.

### Add an extra writable workspace

```
codex --rw ~/scratch
```

Useful when the task needs a secondary writable area in the outer `systemd` sandbox, for example to stage generated artifacts or compare outputs.

---

## Debugging

Enable debug output:

```
CODEX_WRAPPER_DEBUG=1 codex
```

This prints:

* systemd-run command
* selected execution mode
* argument forwarding
* sandbox vs fallback decision

---

## Security Model

| Layer       | Responsibility                                                |
| ----------- | ------------------------------------------------------------- |
| systemd     | primary filesystem boundary in normal operation               |
| codex flags | native approval / sandbox behavior when fallback is in effect |
| wrapper     | mode selection, path binding, and argument forwarding         |

---

## Limitations

* Requires `systemd --user`
* Not a container (network isolation is opt-in with `--profile offline`)
* Sandbox depends on systemd behavior
* Fallback mode is less secure

---

## Design Philosophy

* explicit over implicit
* minimal surface area
* safe defaults
* flexible overrides
* no hidden state

---

## License

MIT

See LICENSE.md for details.
