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
* automatic interactive vs non-interactive handling
* safe fallback when sandboxing fails

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
codex --ro /path/to/dir
```

#### Read-write access

```
codex --rw /path/to/dir
```

These are translated into systemd bind mounts.

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
--add-dir <rw-path>
```

is applied automatically.

---

## Installation

Clone the repository:

```
git clone <repo-url>
```

Source the wrapper:

```
source /path/to/codex-wrapper/src/codex_wrapper.sh
```

Or add to your shell config:

```
echo 'source ~/path/to/codex-wrapper/src/codex_wrapper.sh' >> ~/.bashrc
```

---

## Usage

```
codex [wrapper options] [--] [codex arguments...]
```

---

## Wrapper Options

### `--ro PATH`

Mount a path read-only inside the sandbox.

```
codex --ro ~/.ssh
```

---

### `--rw PATH`

Mount a path read-write inside the sandbox.

```
codex --rw ~/.local
```

---

### `--`

Stops wrapper parsing.

Everything after is passed directly to Codex without wrapper filtering.

```
codex --rw ~/.local -- --model gpt-5-codex
```

---

### `--help`

Shows wrapper help (this document summary).

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

### Combine wrapper + codex args

```
codex --rw ~/.local -- --model gpt-5-codex
```

---

### Script / pipeline usage

```
echo "refactor this function" | codex
```

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

| Layer       | Responsibility               |
| ----------- | ---------------------------- |
| systemd     | filesystem isolation         |
| codex flags | execution / approval control |
| wrapper     | orchestration                |

---

## Limitations

* Requires `systemd --user`
* Not a container (no network isolation by default)
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

## Attribution

If you use this wrapper, retain attribution to:

```
codex-wrapper by David
```

---

## License

MIT (Attribution Required)

See LICENSE file for details.
