#!/usr/bin/env bash
# shellcheck shell=bash

__codex_wrapper_log() {
	[[ $debug == 1 ]] && printf 'codex-wrapper: %s\n' "$*" >&2
	return 0
}

__codex_wrapper_dump() {
	[[ $debug == 1 ]] || return 0
	local label=$1 arg
	shift
	printf 'codex-wrapper: %s:' "$label" >&2
	for arg in "$@"; do
		printf ' %q' "$arg" >&2
	done
	printf '\n' >&2
}

__codex_wrapper_help() {
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
  --ro PATH...  add one or more read-only binds for sandboxed run
  --ro=PATH     add one read-only bind for sandboxed run
  --rw PATH...  add one or more read-write binds for sandboxed run
  --rw=PATH     add one read-write bind for sandboxed run
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

__codex_wrapper_parse_collect_paths() {
	local mode=$1
	local added=0
	shift
	while (($#)); do
		case "$1" in
		-- | --ro | --rw | --ro=* | --rw=* | --help | -h | --wrapper-help | --help-wrapper)
			break
			;;
		esac
		if [[ $mode == ro ]]; then
			ro_paths+=("$1")
		else
			rw_paths+=("$1")
		fi
		added=1
		shift
	done
	((added)) || {
		printf 'codex: missing argument for --%s\n' "$mode" >&2
		return 2
	}
	remaining=$#
}

__codex_wrapper_parse() {
	local arg
	remaining=0
	while (($#)); do
		arg=$1
		case "$arg" in
		--help | -h | --wrapper-help | --help-wrapper)
			show_help=1
			shift
			;;
		--ro)
			shift
			__codex_wrapper_parse_collect_paths ro "$@" || return
			shift $(($# - remaining))
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
			shift
			__codex_wrapper_parse_collect_paths rw "$@" || return
			shift $(($# - remaining))
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

__codex_wrapper_exists() { [[ -e $1 || -S $1 ]]; }

__codex_wrapper_canon() { realpath -e -- "$1" 2>/dev/null; }

__codex_wrapper_normalize_paths() {
	local path resolved
	local -A seen_rw=() seen_ro=()
	local -a new_rw=() new_ro=()

	for path in "${rw_paths[@]}"; do
		resolved=$(__codex_wrapper_canon "$path") || {
			printf 'codex: rw path does not exist: %s\n' "$path" >&2
			return 2
		}
		[[ -n ${seen_rw["$resolved"]+x} ]] || {
			seen_rw["$resolved"]=1
			new_rw+=("$resolved")
		}
	done

	for path in "${ro_paths[@]}"; do
		resolved=$(__codex_wrapper_canon "$path") || {
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

__codex_wrapper_select_codex_prog() {
	codex_prog=("$real_codex")
	if [[ ! -t 0 || ! -t 1 ]]; then
		codex_prog+=(exec)
		__codex_wrapper_log "non-interactive I/O detected; using: ${codex_prog[*]}"
	else
		__codex_wrapper_log "interactive I/O detected; using: ${codex_prog[*]}"
	fi
}

__codex_wrapper_strip_policy_flags() {
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

__codex_wrapper_root_args() {
	local -a base=()
	mapfile -d '' -t base < <(__codex_wrapper_strip_policy_flags "$@")
	printf '%s\0' --dangerously-bypass-approvals-and-sandbox
	((${#base[@]})) && printf '%s\0' "${base[@]}"
	((${#passthrough_args[@]})) && printf '%s\0' "${passthrough_args[@]}"
}

__codex_wrapper_restrained_args() {
	local -a base=()
	mapfile -d '' -t base < <(__codex_wrapper_strip_policy_flags "$@")
	printf '%s\0' --ask-for-approval on-request
	printf '%s\0' --sandbox workspace-write
	printf '%s\0' -c sandbox_workspace_write.network_access=true
	printf '%s\0' --cd "$PWD"
	((${#base[@]})) && printf '%s\0' "${base[@]}"
	((${#passthrough_args[@]})) && printf '%s\0' "${passthrough_args[@]}"
}

__codex_wrapper_unit() {
	printf 'codex-%s-%s-%s' "$(id -u)" "$$" "$(date +%s%N)"
}

__codex_wrapper_run_prefix() {
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
		__codex_wrapper_exists "$path" && run+=(-p "BindReadOnlyPaths=$path")
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

__codex_wrapper_try_sandbox() {
	local unit=$1
	local -a prefix args cmd
	mapfile -d '' -t prefix < <(__codex_wrapper_run_prefix "$unit") || return
	mapfile -d '' -t args < <(__codex_wrapper_root_args "${app_args[@]}") || return
	cmd=("${prefix[@]}" -- "${codex_prog[@]}" "${args[@]}")
	__codex_wrapper_log "trying sandboxed run"
	__codex_wrapper_dump "sandbox argv" "${cmd[@]}"
	"${cmd[@]}"
}

__codex_wrapper_fallback() {
	local -a args cmd
	mapfile -d '' -t args < <(__codex_wrapper_restrained_args "${app_args[@]}") || return
	cmd=("$real_codex" "${args[@]}")
	__codex_wrapper_log "falling back to direct run"
	__codex_wrapper_dump "fallback argv" "${cmd[@]}"
	"${cmd[@]}"
}

__codex_wrapper_props() {
	systemctl --user show \
		-P Result \
		-P ExecMainCode \
		-P ExecMainStatus \
		-P ExecMainPID \
		"$1.service" 2>/dev/null
}

__codex_wrapper_cleanup() {
	systemctl --user reset-failed "$1.service" >/dev/null 2>&1 || true
}

__codex_wrapper_should_fallback() {
	local -a props=()
	mapfile -t props < <(__codex_wrapper_props "$1")
	__codex_wrapper_log "unit result=${props[0]:-} code=${props[1]:-} status=${props[2]:-} pid=${props[3]:-0}"
	[[ ${props[3]:-0} == 0 ]]
}

codex() {
	local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	local bus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${runtime_dir}/bus}"
	local real_codex="${CODEX_WRAPPER_REAL_CODEX:-/usr/bin/codex}"
	local debug="${CODEX_WRAPPER_DEBUG:-0}"
	local remaining=0

	local -a ro_paths=() rw_paths=() app_args=() passthrough_args=()
	local -a codex_prog=()
	local show_help=0

	__codex_wrapper_parse "$@" || return
	((show_help)) && {
		__codex_wrapper_help
		return 0
	}
	__codex_wrapper_normalize_paths || return
	__codex_wrapper_select_codex_prog

	local unit rc
	unit=$(__codex_wrapper_unit)
	__codex_wrapper_log "tty stdin=$([[ -t 0 ]] && echo 1 || echo 0) stdout=$([[ -t 1 ]] && echo 1 || echo 0) stderr=$([[ -t 2 ]] && echo 1 || echo 0)"
	__codex_wrapper_log "unit=$unit"

	__codex_wrapper_try_sandbox "$unit"
	rc=$?
	if ((rc == 0)); then
		__codex_wrapper_cleanup "$unit"
		return 0
	fi

	__codex_wrapper_log "sandbox rc=$rc"

	if __codex_wrapper_should_fallback "$unit"; then
		__codex_wrapper_log "sandbox did not start codex; using fallback"
		__codex_wrapper_cleanup "$unit"
		__codex_wrapper_fallback
		return $?
	fi

	__codex_wrapper_log "sandbox did start codex; not retrying"
	__codex_wrapper_cleanup "$unit"
	return "$rc"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	codex "$@"
fi
