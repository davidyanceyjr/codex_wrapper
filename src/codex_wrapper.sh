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
  --profile NAME
                resolve a wrapper or native codex profile
  --agents      enable AGENTS.md.disabled and .agents.disabled entries under PWD
  --skills      enable .agents.disabled, .codex.disabled, skills.disabled, and SKILLS.disabled under PWD
  --skags       equivalent to --agents --skills
  --no-agents   disable AGENTS.md and .agents entries under PWD
  --no-skills   disable .agents, .codex, skills, and SKILLS under PWD
  --no-skags    equivalent to --no-agents --no-skills
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
      -c sandbox_workspace_write.network_access=<true|false>
      --cd <launch-directory>
  - wrapper --ro/--rw PATH and wrapper-managed --profile mounts apply only to the outer systemd sandbox
  - wrapper profiles:
      unprefixed names prefer wrapper profiles
      codex:NAME forces native codex passthrough
      wrapper:NAME requires a wrapper profile

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
		-- | --ro | --rw | --ro=* | --rw=* | --profile | --profile=* | --agents | --skills | --skags | --no-agents | --no-skills | --no-skags | --help | -h | --wrapper-help | --help-wrapper)
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
		--agents)
			enable_agents=1
			shift
			;;
		--skills)
			enable_skills=1
			shift
			;;
		--skags)
			enable_agents=1
			enable_skills=1
			shift
			;;
		--no-agents)
			disable_agents=1
			shift
			;;
		--no-skills)
			disable_skills=1
			shift
			;;
		--no-skags)
			disable_agents=1
			disable_skills=1
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
		--profile)
			(($# >= 2)) || {
				printf 'codex: missing argument for --profile\n' >&2
				return 2
			}
			__codex_wrapper_resolve_profile_arg "$2" || return
			shift 2
			;;
		--profile=*)
			[[ -n ${arg#--profile=} ]] || {
				printf 'codex: empty argument for --profile\n' >&2
				return 2
			}
			__codex_wrapper_resolve_profile_arg "${arg#--profile=}" || return
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

__codex_wrapper_validate_toggle_flags() {
	if ((enable_agents && disable_agents)); then
		printf 'codex: conflicting options: --agents and --no-agents\n' >&2
		return 2
	fi
	if ((enable_skills && disable_skills)); then
		printf 'codex: conflicting options: --skills and --no-skills\n' >&2
		return 2
	fi
}

__codex_wrapper_apply_default_enables() {
	if ((agents_disabled_detected && !disable_agents)); then
		enable_agents=1
	fi
	if ((skills_disabled_detected && !disable_skills)); then
		enable_skills=1
	fi
}

__codex_wrapper_find_targets() {
	local category=$1
	case "$category" in
	agents)
		find "$PWD" -depth \( -name 'AGENTS.md' -o -name '.agents' \) -print0
		;;
	skills)
		find "$PWD" -depth \( -name '.agents' -o -name 'skills' -o -name 'SKILLS' -o -name '.codex' \) -print0
		;;
	agents_disabled)
		find "$PWD" -depth \( -name 'AGENTS.md.disabled' -o -name '.agents.disabled' \) -print0
		;;
	skills_disabled)
		find "$PWD" -depth \( -name '.agents.disabled' -o -name 'skills.disabled' -o -name 'SKILLS.disabled' -o -name '.codex.disabled' \) -print0
		;;
	esac
}

__codex_wrapper_scan_disabled_state() {
	agents_disabled_detected=0
	skills_disabled_detected=0

	local -a matches=()
	mapfile -d '' -t matches < <(__codex_wrapper_find_targets agents_disabled)
	((${#matches[@]})) && agents_disabled_detected=1

	matches=()
	mapfile -d '' -t matches < <(__codex_wrapper_find_targets skills_disabled)
	((${#matches[@]})) && skills_disabled_detected=1
}

__codex_wrapper_apply_disable() {
	local category=$1 path
	local -a matches=()

	mapfile -d '' -t matches < <(__codex_wrapper_find_targets "$category")
	for path in "${matches[@]}"; do
		[[ -e $path && ! -e ${path}.disabled ]] || continue
		mv -- "$path" "${path}.disabled" || return
		case "$category" in
		agents) agents_disabled_detected=1 ;;
		skills) skills_disabled_detected=1 ;;
		esac
	done
}

__codex_wrapper_apply_enable() {
	local category=$1 path original
	local -a matches=()

	mapfile -d '' -t matches < <(__codex_wrapper_find_targets "${category}_disabled")
	for path in "${matches[@]}"; do
		original=${path%.disabled}
		[[ -e $path && ! -e $original ]] || continue
		mv -- "$path" "$original" || return
	done
}

__codex_wrapper_status_notice() {
	local label=
	if ((agents_disabled_detected && skills_disabled_detected)); then
		label='AGENTS and SKILLS'
	elif ((agents_disabled_detected)); then
		label='AGENTS'
	elif ((skills_disabled_detected)); then
		label='SKILLS'
	else
		return 0
	fi
	printf 'codex-wrapper: %s disabled under %s\n' "$label" "$PWD" >&2
}

__codex_wrapper_enable_notice() {
	local label=
	if ((enable_agents && enable_skills)); then
		label='AGENTS and SKILLS'
	elif ((enable_agents)); then
		label='AGENTS'
	elif ((enable_skills)); then
		label='SKILLS'
	else
		return 0
	fi
	((enable_agents || enable_skills)) || return 0
	printf 'codex-wrapper: %s enabled under %s\n' "$label" "$PWD" >&2
}

__codex_wrapper_exists() { [[ -e $1 || -S $1 ]]; }

__codex_wrapper_canon() { realpath -e -- "$1" 2>/dev/null; }

__codex_wrapper_builtin_profile_exists() {
	case "$1" in
	git | ssh | worktree | readonly | config | config-wide | host-context | offline | online | secrets-safe)
		return 0
		;;
	esac
	return 1
}

__codex_wrapper_profile_name_is_safe() {
	[[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

__codex_wrapper_user_profile_path() {
	local name=$1
	__codex_wrapper_profile_name_is_safe "$name" || return 1
	printf '%s/.codex/wrapper-profiles.d/%s.profile\n' "$HOME" "$name"
}

__codex_wrapper_user_profile_exists() {
	local path=
	path=$(__codex_wrapper_user_profile_path "$1") || return 1
	[[ -f $path ]]
}

__codex_wrapper_profile_exists() {
	__codex_wrapper_builtin_profile_exists "$1" || __codex_wrapper_user_profile_exists "$1"
}

__codex_wrapper_apply_profile_mounts() {
	local mode=$1
	shift
	case "$mode" in
	ro) profile_ro_paths+=("$@") ;;
	rw) profile_rw_paths+=("$@") ;;
	deny) deny_path_specs+=("$@") ;;
	esac
}

__codex_wrapper_apply_profile_network_policy() {
	case "$1" in
	default | on | off)
		network_policy=$1
		;;
	esac
}

__codex_wrapper_expand_user_profile_path() {
	local spec=$1
	case "$spec" in
	'~')
		printf '%s\n' "$HOME"
		;;
	'~/'*)
		printf '%s/%s\n' "$HOME" "${spec:2}"
		;;
	*)
		printf '%s\n' "$spec"
		;;
	esac
}

__codex_wrapper_apply_builtin_profile() {
	case "$1" in
	worktree)
		__codex_wrapper_apply_profile_mounts rw "$PWD"
		__codex_wrapper_apply_profile_mounts ro \
			"$HOME/.gitconfig" \
			"$HOME/.config/git" \
			"/etc/gitconfig" \
			"/etc/ssl" \
			"/etc/pki" \
			"/usr/share/ca-certificates"
		__codex_wrapper_apply_profile_network_policy on
		;;
	readonly)
		__codex_wrapper_apply_profile_mounts ro "$PWD"
		__codex_wrapper_apply_profile_network_policy off
		;;
	git)
		__codex_wrapper_apply_profile_mounts rw "$PWD"
		__codex_wrapper_apply_profile_mounts ro \
			"$HOME/.gitconfig" \
			"$HOME/.config/git" \
			"/etc/gitconfig" \
			"/etc/ssl" \
			"/etc/pki" \
			"/usr/share/ca-certificates" \
			"$HOME/.ssh/config" \
			"$HOME/.ssh/known_hosts" \
			"$HOME/.ssh/known_hosts2" \
			"/etc/ssh/ssh_config"
		__codex_wrapper_apply_profile_network_policy on
		;;
	ssh)
		__codex_wrapper_apply_profile_mounts ro \
			"$HOME/.ssh/config" \
			"$HOME/.ssh/known_hosts" \
			"$HOME/.ssh/known_hosts2" \
			"/etc/ssh" \
			"/etc/ssl" \
			"/etc/pki" \
			"/usr/share/ca-certificates"
		profile_env_passthroughs+=(SSH_AUTH_SOCK GIT_SSH_COMMAND)
		__codex_wrapper_apply_profile_network_policy on
		;;
	config)
		__codex_wrapper_apply_profile_mounts ro \
			"$HOME/.config" \
			"$HOME/.local/share" \
			"/etc/os-release" \
			"/etc/lsb-release" \
			"/etc/hosts" \
			"/etc/resolv.conf" \
			"/etc/nsswitch.conf" \
			"/etc/ssl" \
			"/etc/pki"
		;;
	config-wide)
		__codex_wrapper_apply_profile_mounts ro \
			"/etc" \
			"/usr/share" \
			"/usr/local/share" \
			"$HOME/.config" \
			"$HOME/.local/share"
		;;
	host-context)
		__codex_wrapper_apply_profile_mounts ro \
			"/etc/os-release" \
			"/etc/hostname" \
			"/etc/hosts" \
			"/etc/resolv.conf" \
			"/etc/nsswitch.conf" \
			"/proc/cpuinfo" \
			"/proc/meminfo"
		;;
	offline)
		__codex_wrapper_apply_profile_network_policy off
		;;
	online)
		__codex_wrapper_apply_profile_network_policy on
		;;
	secrets-safe)
		__codex_wrapper_apply_profile_mounts deny \
			"$HOME/.ssh/id_*" \
			"$HOME/.ssh/*_rsa" \
			"$HOME/.ssh/*_ed25519" \
			"$HOME/.ssh/*_ecdsa" \
			"$HOME/.gnupg" \
			"$HOME/.aws" \
			"$HOME/.azure" \
			"$HOME/.config/gcloud" \
			"$HOME/.docker/config.json" \
			"$HOME/.kube" \
			"$HOME/.netrc" \
			"$HOME/.npmrc" \
			"$HOME/.pypirc" \
			"$HOME/.cargo/credentials" \
			"$HOME/.cargo/credentials.toml"
		;;
	esac
}

__codex_wrapper_load_user_profile() {
	local name=$1 path= line= lineno=0 directive= value= spec=
	path=$(__codex_wrapper_user_profile_path "$name") || return 1
	[[ -f $path ]] || return 1

	while IFS= read -r line || [[ -n $line ]]; do
		lineno=$((lineno + 1))
		line=${line%$'\r'}
		line=${line#"${line%%[![:space:]]*}"}
		line=${line%"${line##*[![:space:]]}"}
		[[ -n $line && ${line:0:1} != "#" ]] || continue

		directive=${line%%[[:space:]]*}
		value=${line#"$directive"}
		value=${value#"${value%%[![:space:]]*}"}

		case "$directive" in
		ro | rw | deny)
			[[ -n $value ]] || {
				printf 'codex: invalid wrapper profile %s:%s: missing value for %s\n' "$name" "$lineno" "$directive" >&2
				return 2
			}
			spec=$(__codex_wrapper_expand_user_profile_path "$value")
			__codex_wrapper_apply_profile_mounts "$directive" "$spec"
			;;
		network)
			case "$value" in
			default | on | off)
				__codex_wrapper_apply_profile_network_policy "$value"
				;;
			*)
				printf 'codex: invalid wrapper profile %s:%s: invalid network mode: %s\n' "$name" "$lineno" "$value" >&2
				return 2
				;;
			esac
			;;
		*)
			printf 'codex: invalid wrapper profile %s:%s: unknown directive: %s\n' "$name" "$lineno" "$directive" >&2
			return 2
			;;
		esac
	done < "$path"
}

__codex_wrapper_apply_wrapper_profile() {
	local name=$1
	if __codex_wrapper_builtin_profile_exists "$name"; then
		__codex_wrapper_apply_builtin_profile "$name"
		return
	fi
	__codex_wrapper_load_user_profile "$name"
}

__codex_wrapper_resolve_profile_arg() {
	local raw=$1 name=
	case "$raw" in
	codex:*)
		name=${raw#codex:}
		[[ -n $name ]] || {
			printf 'codex: invalid profile prefix, expected codex:NAME\n' >&2
			return 2
		}
		app_args+=(--profile "$name")
		;;
	wrapper:*)
		name=${raw#wrapper:}
		[[ -n $name ]] || {
			printf 'codex: invalid profile prefix, expected wrapper:NAME\n' >&2
			return 2
		}
		__codex_wrapper_profile_exists "$name" || {
			printf 'codex: unknown wrapper profile: %s\n' "$name" >&2
			return 2
		}
		__codex_wrapper_apply_wrapper_profile "$name"
		;;
	*)
		if __codex_wrapper_profile_exists "$raw"; then
			__codex_wrapper_apply_wrapper_profile "$raw"
		else
			app_args+=(--profile "$raw")
		fi
		;;
	esac
}

__codex_wrapper_normalize_mounts() {
	local -n rw_input=$1
	local -n ro_input=$2
	local -n rw_output=$3
	local -n ro_output=$4
	local label=$5
	local strict_missing=$6
	local path resolved
	local -A seen_rw=() seen_ro=()

	rw_output=()
	ro_output=()

	for path in "${rw_input[@]}"; do
		resolved=$(__codex_wrapper_canon "$path") || {
			if [[ $strict_missing == 1 ]]; then
				if [[ $label == cli ]]; then
					printf 'codex: rw path does not exist: %s\n' "$path" >&2
				else
					printf 'codex: %s rw path does not exist: %s\n' "$label" "$path" >&2
				fi
				return 2
			fi
			continue
		}
		[[ -n ${seen_rw["$resolved"]+x} ]] || {
			seen_rw["$resolved"]=1
			rw_output+=("$resolved")
		}
	done

	for path in "${ro_input[@]}"; do
		resolved=$(__codex_wrapper_canon "$path") || {
			if [[ $strict_missing == 1 ]]; then
				if [[ $label == cli ]]; then
					printf 'codex: ro path does not exist: %s\n' "$path" >&2
				else
					printf 'codex: %s ro path does not exist: %s\n' "$label" "$path" >&2
				fi
				return 2
			fi
			continue
		}
		[[ -n ${seen_rw["$resolved"]+x} ]] && continue
		[[ -n ${seen_ro["$resolved"]+x} ]] || {
			seen_ro["$resolved"]=1
			ro_output+=("$resolved")
		}
	done
}

__codex_wrapper_expand_deny_paths() {
	local spec path resolved nullglob_was_set=0
	local -A seen=()
	denied_paths=()

	if shopt -q nullglob; then
		nullglob_was_set=1
	fi
	shopt -s nullglob
	for spec in "${deny_path_specs[@]}"; do
		if [[ $spec == *[\*\?\[]* ]]; then
			while IFS= read -r path; do
				[[ -n $path ]] || continue
				resolved=$(__codex_wrapper_canon "$path") || continue
				[[ -n ${seen["$resolved"]+x} ]] || {
					seen["$resolved"]=1
					denied_paths+=("$resolved")
				}
			done < <(compgen -G "$spec")
			continue
		fi
		__codex_wrapper_exists "$spec" || continue
		resolved=$(__codex_wrapper_canon "$spec") || continue
		[[ -n ${seen["$resolved"]+x} ]] || {
			seen["$resolved"]=1
			denied_paths+=("$resolved")
		}
	done
	if ((nullglob_was_set)); then
		shopt -s nullglob
	else
		shopt -u nullglob
	fi
}

__codex_wrapper_path_is_denied() {
	local path=$1 denied=
	for denied in "${denied_paths[@]}"; do
		if [[ $path == "$denied" || $path == "$denied"/* ]]; then
			return 0
		fi
	done
	return 1
}

__codex_wrapper_filter_denied_paths() {
	local path=
	local -a filtered_rw=() filtered_ro=()

	for path in "${rw_paths[@]}"; do
		__codex_wrapper_path_is_denied "$path" || filtered_rw+=("$path")
	done
	for path in "${ro_paths[@]}"; do
		__codex_wrapper_path_is_denied "$path" || filtered_ro+=("$path")
	done

	rw_paths=("${filtered_rw[@]}")
	ro_paths=("${filtered_ro[@]}")
}

__codex_wrapper_normalize_paths() {
	local -a normalized_profile_rw=() normalized_profile_ro=()
	local -a normalized_cli_rw=() normalized_cli_ro=()
	local path=
	local -A cli_ro_set=() final_rw_set=() final_ro_set=()

	__codex_wrapper_normalize_mounts profile_rw_paths profile_ro_paths normalized_profile_rw normalized_profile_ro "profile" 0 || return
	__codex_wrapper_normalize_mounts rw_paths ro_paths normalized_cli_rw normalized_cli_ro "cli" 1 || return
	__codex_wrapper_expand_deny_paths

	rw_paths=("${normalized_profile_rw[@]}")
	ro_paths=("${normalized_profile_ro[@]}")

	for path in "${normalized_cli_ro[@]}"; do
		cli_ro_set["$path"]=1
	done

	for path in "${rw_paths[@]}"; do
		[[ -n ${cli_ro_set["$path"]+x} ]] || final_rw_set["$path"]=1
	done
	for path in "${ro_paths[@]}"; do
		[[ -n ${final_rw_set["$path"]+x} ]] || final_ro_set["$path"]=1
	done
	for path in "${normalized_cli_ro[@]}"; do
		unset "final_rw_set[$path]"
		final_ro_set["$path"]=1
	done
	for path in "${normalized_cli_rw[@]}"; do
		unset "final_ro_set[$path]"
		final_rw_set["$path"]=1
	done

	rw_paths=()
	ro_paths=()
	for path in "${normalized_profile_rw[@]}"; do
		[[ -n ${final_rw_set["$path"]+x} ]] && {
			rw_paths+=("$path")
			unset "final_rw_set[$path]"
		}
	done
	for path in "${normalized_profile_ro[@]}"; do
		[[ -n ${final_ro_set["$path"]+x} ]] && {
			ro_paths+=("$path")
			unset "final_ro_set[$path]"
		}
	done
	for path in "${normalized_cli_ro[@]}"; do
		[[ -n ${final_ro_set["$path"]+x} ]] && {
			ro_paths+=("$path")
			unset "final_ro_set[$path]"
		}
	done
	for path in "${normalized_cli_rw[@]}"; do
		[[ -n ${final_rw_set["$path"]+x} ]] && {
			rw_paths+=("$path")
			unset "final_rw_set[$path]"
		}
	done

	__codex_wrapper_filter_denied_paths
}

__codex_wrapper_require_real_codex() {
	if [[ ! -e $real_codex ]]; then
		printf 'codex: native codex executable not found: %s\n' "$real_codex" >&2
		return 2
	fi
	if [[ ! -f $real_codex || ! -x $real_codex ]]; then
		printf 'codex: native codex executable is not executable: %s\n' "$real_codex" >&2
		return 2
	fi
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
	if [[ $network_policy == off ]]; then
		printf '%s\0' -c sandbox_workspace_write.network_access=false
	else
		printf '%s\0' -c sandbox_workspace_write.network_access=true
	fi
	printf '%s\0' --cd "$PWD"
	((${#base[@]})) && printf '%s\0' "${base[@]}"
	((${#passthrough_args[@]})) && printf '%s\0' "${passthrough_args[@]}"
}

__codex_wrapper_unit() {
	printf 'codex-%s-%s-%s' "$(id -u)" "$$" "$(date +%s%N)"
}

__codex_wrapper_run_prefix() {
	local unit=$1 path
	local pwd_canon default_pwd_mode=rw
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
		-p "BindPaths=$HOME/.codex"
		-p "ReadWritePaths=$HOME/.codex"
	)
	pwd_canon=$(__codex_wrapper_canon "$PWD") || return

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
	for path in "${rw_paths[@]}"; do
		if [[ $path == "$pwd_canon" ]]; then
			default_pwd_mode=explicit
			break
		fi
	done
	if [[ $default_pwd_mode != explicit ]]; then
		for path in "${ro_paths[@]}"; do
			if [[ $path == "$pwd_canon" ]]; then
				default_pwd_mode=ro
				break
			fi
		done
	fi
	case "$default_pwd_mode" in
	rw)
		run+=(-p "BindPaths=$pwd_canon" -p "ReadWritePaths=$pwd_canon")
		;;
	ro)
		run+=(-p "BindReadOnlyPaths=$pwd_canon")
		;;
	esac
	for path in "${denied_paths[@]}"; do
		run+=(-p "InaccessiblePaths=$path")
	done

	if [[ $network_policy == off ]]; then
		run+=(-p "IPAddressDeny=any")
	fi

	if [[ -n ${SSH_AUTH_SOCK:-} && -S ${SSH_AUTH_SOCK:-} ]]; then
		run+=(
			-E "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
			-p "BindReadOnlyPaths=$SSH_AUTH_SOCK"
		)
	fi
	if [[ " ${profile_env_passthroughs[*]} " == *" GIT_SSH_COMMAND "* && -n ${GIT_SSH_COMMAND:-} ]]; then
		run+=(-E "GIT_SSH_COMMAND=$GIT_SSH_COMMAND")
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
	local output
	local -a props=()

	output=$(__codex_wrapper_props "$1") || {
		__codex_wrapper_log "unit inspection failed; not falling back"
		return 1
	}

	mapfile -t props <<<"$output"
	if ((${#props[@]} < 4)); then
		__codex_wrapper_log "unit inspection incomplete; not falling back"
		return 1
	fi
	if [[ ! ${props[3]} =~ ^[0-9]+$ ]]; then
		__codex_wrapper_log "unit inspection returned invalid pid=${props[3]@Q}; not falling back"
		return 1
	fi

	__codex_wrapper_log "unit result=${props[0]} code=${props[1]} status=${props[2]} pid=${props[3]}"
	[[ ${props[3]} == 0 ]]
}

codex() {
	local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	local bus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${runtime_dir}/bus}"
	local real_codex="${CODEX_WRAPPER_REAL_CODEX:-/usr/bin/codex}"
	local debug="${CODEX_WRAPPER_DEBUG:-0}"
	local remaining=0
	local enable_agents=0
	local enable_skills=0
	local disable_agents=0
	local disable_skills=0
	local agents_disabled_detected=0
	local skills_disabled_detected=0

	local -a ro_paths=() rw_paths=() app_args=() passthrough_args=()
	local -a profile_ro_paths=() profile_rw_paths=() deny_path_specs=() denied_paths=() profile_env_passthroughs=()
	local -a codex_prog=()
	local network_policy=default
	local show_help=0

	__codex_wrapper_parse "$@" || return
	((show_help)) && {
		__codex_wrapper_help
		return 0
	}
	__codex_wrapper_normalize_paths || return
	__codex_wrapper_validate_toggle_flags || return
	__codex_wrapper_require_real_codex || return
	__codex_wrapper_select_codex_prog
	__codex_wrapper_scan_disabled_state
	__codex_wrapper_apply_default_enables
	if ((enable_agents)); then
		__codex_wrapper_apply_enable agents || return
	fi
	if ((enable_skills)); then
		__codex_wrapper_apply_enable skills || return
	fi
	if ((disable_agents)); then
		__codex_wrapper_apply_disable agents || return
	fi
	if ((disable_skills)); then
		__codex_wrapper_apply_disable skills || return
	fi
	__codex_wrapper_scan_disabled_state
	__codex_wrapper_enable_notice
	__codex_wrapper_status_notice

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
