# shellcheck shell=bash
codex() {
	local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	local bus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${runtime_dir}/bus}"
	local real_codex="/usr/bin/codex"
	local debug="${CODEX_WRAPPER_DEBUG:-0}"

	local -a ro_paths=() rw_paths=() app_args=() passthrough_args=()
	local -a codex_prog=()
	local show_help=0

	_log() { [[ $debug == 1 ]] && printf 'codex-wrapper: %s\n' "$*" >&2; }
	_dump() {
		[[ $debug == 1 ]] || return 0
		local label=$1 arg
		shift
		printf 'codex-wrapper: %s:' "$label" >&2
		for arg in "$@"; do
			printf ' %q' "$arg" >&2
		done
		printf '\n' >&2
	}

	_help() {
		cat <<EOF
codex (wrapper)

Wrapper around:
  $real_codex

This is wrapper help, not the real codex CLI help.

Quick help:
  codex --help          show this wrapper help
  codex -- --help       show real codex help
  $real_codex --help    run real codex directly

USAGE
  codex [wrapper options] [--] [codex arguments...]

WRAPPER OPTIONS
  --ro PATH     add read-only bind for sandboxed run
  --ro=PATH     same as --ro PATH
  --rw PATH     add read-write bind for sandboxed run
  --rw=PATH     same as --rw PATH
  --help, -h    show this help
  --            stop wrapper parsing; forward rest to codex

BEHAVIOR
  - interactive runs use codex normally
  - non-interactive runs use: codex exec
  - sandboxed run uses:
      --dangerously-bypass-approvals-and-sandbox
  - fallback run uses:
      --ask-for-approval on-request
      --sandbox workspace-write
      -c sandbox_workspace_write.network_access=true
      --cd <launch-directory>
  - wrapper --rw PATH applies only to the outer systemd sandbox

DEBUG
  CODEX_WRAPPER_DEBUG=1 codex
EOF
	}

	_parse() {
		local arg
		while (($#)); do
			arg=$1
			case "$arg" in
			--help | -h | --wrapper-help | --help-wrapper)
				show_help=1
				shift
				;;
			--ro)
				(($# >= 2)) || {
					printf 'codex: missing argument for --ro\n' >&2
					return 2
				}
				ro_paths+=("$2")
				shift 2
				;;
			--ro=*)
				[[ -n ${arg#--ro=} ]] || {
					printf 'codex: empty argument for --ro\n' >&2
					return 2
				}
				ro_paths+=("${arg#--ro=}")
				shift
				;;
			--rw)
				(($# >= 2)) || {
					printf 'codex: missing argument for --rw\n' >&2
					return 2
				}
				rw_paths+=("$2")
				shift 2
				;;
			--rw=*)
				[[ -n ${arg#--rw=} ]] || {
					printf 'codex: empty argument for --rw\n' >&2
					return 2
				}
				rw_paths+=("${arg#--rw=}")
				shift
				;;
			--)
				shift
				passthrough_args+=("$@")
				break
				;;
			*)
				app_args+=("$1")
				shift
				;;
			esac
		done
	}

	_exists() { [[ -e $1 || -S $1 ]]; }
	_canon() { realpath -e -- "$1" 2>/dev/null; }

	_normalize_paths() {
		local path resolved
		local -A seen_rw=() seen_ro=()
		local -a new_rw=() new_ro=()

		for path in "${rw_paths[@]}"; do
			resolved=$(_canon "$path") || {
				printf 'codex: rw path does not exist: %s\n' "$path" >&2
				return 2
			}
			[[ -n ${seen_rw["$resolved"]+x} ]] || {
				seen_rw["$resolved"]=1
				new_rw+=("$resolved")
			}
		done

		for path in "${ro_paths[@]}"; do
			resolved=$(_canon "$path") || {
				printf 'codex: ro path does not exist: %s\n' "$path" >&2
				return 2
			}
			[[ -n ${seen_rw["$resolved"]+x} ]] && continue
			[[ -n ${seen_ro["$resolved"]+x} ]] || {
				seen_ro["$resolved"]=1
				new_ro+=("$resolved")
			}
		done

		rw_paths=("${new_rw[@]}")
		ro_paths=("${new_ro[@]}")
	}

	_select_codex_prog() {
		codex_prog=("$real_codex")
		if [[ ! -t 0 || ! -t 1 ]]; then
			codex_prog+=(exec)
			_log "non-interactive I/O detected; using: ${codex_prog[*]}"
		else
			_log "interactive I/O detected; using: ${codex_prog[*]}"
		fi
	}

	_strip_policy_flags() {
		local arg skip=0
		for arg in "$@"; do
			if ((skip)); then
				skip=0
				continue
			fi
			case "$arg" in
			--dangerously-bypass-approvals-and-sandbox | --yolo | --full-auto) ;;
			--ask-for-approval | -a | --sandbox | -s | --add-dir | --cd | -c)
				skip=1
				;;
			--ask-for-approval=* | -a=* | --sandbox=* | -s=* | --add-dir=* | --cd=* | -c=*) ;;
			*)
				printf '%s\0' "$arg"
				;;
			esac
		done
	}

	_root_args() {
		local -a base=()
		mapfile -d '' -t base < <(_strip_policy_flags "$@")
		printf '%s\0' --dangerously-bypass-approvals-and-sandbox
		((${#base[@]})) && printf '%s\0' "${base[@]}"
		((${#passthrough_args[@]})) && printf '%s\0' "${passthrough_args[@]}"
	}

	_restrained_args() {
		local -a base=()
		mapfile -d '' -t base < <(_strip_policy_flags "$@")
		printf '%s\0' --ask-for-approval on-request
		printf '%s\0' --sandbox workspace-write
		printf '%s\0' -c sandbox_workspace_write.network_access=true
		printf '%s\0' --cd "$PWD"
		((${#base[@]})) && printf '%s\0' "${base[@]}"
		((${#passthrough_args[@]})) && printf '%s\0' "${passthrough_args[@]}"
	}

	_unit() {
		printf 'codex-%s-%s-%s' "$(id -u)" "$$" "$(date +%s%N)"
	}

	_run_prefix() {
		local unit=$1 path
		local -a run=(
			systemd-run
			--user
			--quiet
			"--unit=$unit"
			--same-dir
			--wait
			--pty
			--pipe
			--service-type=exec
			-E "HOME=$HOME"
			-E "PATH=$PATH"
			-E "TERM=$TERM"
			-E "XDG_RUNTIME_DIR=$runtime_dir"
			-E "DBUS_SESSION_BUS_ADDRESS=$bus_addr"
			-p "NoNewPrivileges=yes"
			-p "PrivateTmp=yes"
			-p "ProtectSystem=strict"
			-p "ProtectHome=tmpfs"
			-p "BindPaths=$PWD"
			-p "ReadWritePaths=$PWD"
			-p "BindPaths=$HOME/.codex"
			-p "ReadWritePaths=$HOME/.codex"
		)

		local -a default_ro=(
			"$HOME/.config/gh"
			"$HOME/.gitconfig"
			"$HOME/.config/git"
			"/etc/ssl"
			"/etc/hosts"
			"/etc/resolv.conf"
		)

		for path in "${default_ro[@]}"; do
			_exists "$path" && run+=(-p "BindReadOnlyPaths=$path")
		done
		for path in "${ro_paths[@]}"; do
			run+=(-p "BindReadOnlyPaths=$path")
		done
		for path in "${rw_paths[@]}"; do
			run+=(-p "BindPaths=$path" -p "ReadWritePaths=$path")
		done

		if [[ -n ${SSH_AUTH_SOCK:-} && -S ${SSH_AUTH_SOCK:-} ]]; then
			run+=(
				-E "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
				-p "BindReadOnlyPaths=$SSH_AUTH_SOCK"
			)
		fi

		printf '%s\0' "${run[@]}"
	}

	_try_sandbox() {
		local unit=$1
		local -a prefix args cmd
		mapfile -d '' -t prefix < <(_run_prefix "$unit") || return
		mapfile -d '' -t args < <(_root_args "${app_args[@]}") || return
		cmd=("${prefix[@]}" -- "${codex_prog[@]}" "${args[@]}")
		_log "trying sandboxed run"
		_dump "sandbox argv" "${cmd[@]}"
		"${cmd[@]}"
	}

	_fallback() {
		local -a args cmd
		mapfile -d '' -t args < <(_restrained_args "${app_args[@]}") || return
		cmd=("${codex_prog[@]}" "${args[@]}")
		_log "falling back to direct run"
		_dump "fallback argv" "${cmd[@]}"
		"${cmd[@]}"
	}

	_props() {
		systemctl --user show \
			-P Result \
			-P ExecMainCode \
			-P ExecMainStatus \
			-P ExecMainPID \
			"$1.service" 2>/dev/null
	}

	_cleanup() {
		systemctl --user reset-failed "$1.service" >/dev/null 2>&1 || true
	}

	_should_fallback() {
		local -a props=()
		mapfile -t props < <(_props "$1")
		_log "unit result=${props[0]:-} code=${props[1]:-} status=${props[2]:-} pid=${props[3]:-0}"
		[[ ${props[3]:-0} == 0 ]]
	}

	_parse "$@" || return
	((show_help)) && {
		_help
		return 0
	}
	_normalize_paths || return
	_select_codex_prog

	local unit rc
	unit=$(_unit)
	_log "tty stdin=$([[ -t 0 ]] && echo 1 || echo 0) stdout=$([[ -t 1 ]] && echo 1 || echo 0) stderr=$([[ -t 2 ]] && echo 1 || echo 0)"
	_log "unit=$unit"

	if _try_sandbox "$unit"; then
		_cleanup "$unit"
		return 0
	fi

	rc=$?
	_log "sandbox rc=$rc"

	if _should_fallback "$unit"; then
		_log "sandbox did not start codex; using fallback"
		_cleanup "$unit"
		_fallback
	fi

	_log "sandbox did start codex; not retrying"
	_cleanup "$unit"
	return "$rc"
}
