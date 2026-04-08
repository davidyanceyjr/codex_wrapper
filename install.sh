#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_wrapper="$script_dir/src/codex_wrapper.sh"

bin_dir="${HOME}/.local/bin"
target_path="$bin_dir/codex"
install_root="${HOME}/.local/share/codex-wrapper"
uninstall_path="${install_root}/uninstall.sh"
backup_path="${install_root}/original-codex"
state_path="${install_root}/install-state"
bashrc_path="${HOME}/.bashrc"
zshrc_path="${HOME}/.zshrc"
profile_path="${HOME}/.profile"
bash_profile_path="${HOME}/.bash_profile"
zprofile_path="${HOME}/.zprofile"
managed_start="# >>> codex-wrapper managed block >>>"
managed_end="# <<< codex-wrapper managed block <<<"

assume_yes=0
install_bashrc_mode=ask

usage() {
	cat <<'EOF'
Usage: ./install.sh [--yes] [--bashrc yes|no]

Options:
  --yes           assume yes for install confirmation prompts
  --bashrc MODE   choose whether to install managed shell startup blocks
                  MODE must be "yes" or "no"
  --help, -h      show this help
EOF
}

log() {
	printf '%s\n' "$*"
}

warn() {
	printf 'warning: %s\n' "$*" >&2
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

confirm() {
	local prompt=${1:?prompt required}
	local default=${2:-yes}
	local reply=

	if ((assume_yes)); then
		return 0
	fi

	if [[ ! -t 0 ]]; then
		[[ $default == yes ]] && return 0
		return 1
	fi

	case "$default" in
	yes)
		read -r -p "$prompt [Y/n] " reply || return 1
		[[ -z $reply || $reply =~ ^[Yy]([Ee][Ss])?$ ]]
		;;
	no)
		read -r -p "$prompt [y/N] " reply || return 1
		[[ $reply =~ ^[Yy]([Ee][Ss])?$ ]]
		;;
	*)
		die "invalid confirmation default: $default"
		;;
	esac
}

parse_args() {
	while (($#)); do
		case "$1" in
		--yes)
			assume_yes=1
			;;
		--bashrc)
			shift
			(($#)) || die "missing value for --bashrc"
			case "$1" in
			yes | no)
				install_bashrc_mode=$1
				;;
			*)
				die "invalid value for --bashrc: $1"
				;;
			esac
			;;
		--bashrc=*)
			case "${1#--bashrc=}" in
			yes | no)
				install_bashrc_mode=${1#--bashrc=}
				;;
			*)
				die "invalid value for --bashrc: ${1#--bashrc=}"
				;;
			esac
			;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			die "unknown argument: $1"
			;;
		esac
		shift
	done
}

path_entry_index() {
	local needle=$1
	local old_ifs=$IFS
	local index=0 entry
	IFS=:
	for entry in $PATH; do
		if [[ $entry == "$needle" ]]; then
			IFS=$old_ifs
			printf '%s\n' "$index"
			return 0
		fi
		index=$((index + 1))
	done
	IFS=$old_ifs
	return 1
}

needs_precedence_warning() {
	local codex_path codex_dir local_index codex_index

	path_entry_index "$bin_dir" >/dev/null || return 0

	codex_path="$(command -v codex 2>/dev/null || true)"
	[[ -n $codex_path ]] || return 1
	[[ $codex_path == "$target_path" ]] && return 1
	[[ $codex_path == /* ]] || return 0

	codex_dir="$(dirname "$codex_path")"
	local_index="$(path_entry_index "$bin_dir" 2>/dev/null || true)"
	codex_index="$(path_entry_index "$codex_dir" 2>/dev/null || true)"

	[[ -n $local_index && -n $codex_index ]] || return 0
	((local_index < codex_index)) && return 1
	return 0
}

ensure_parent_dirs() {
	mkdir -p "$bin_dir" "$install_root"
}

is_installed_wrapper() {
	[[ -f $target_path ]] || return 1
	cmp -s "$source_wrapper" "$target_path"
}

preserve_existing_target() {
	if [[ ! -e $target_path ]]; then
		printf 'replaced_existing_target=0\n' >"$state_path"
		return 0
	fi

	if is_installed_wrapper; then
		printf 'replaced_existing_target=0\n' >"$state_path"
		return 0
	fi

	cp -f "$target_path" "$backup_path"
	printf 'replaced_existing_target=1\n' >"$state_path"
}

install_wrapper() {
	preserve_existing_target
	install -m 0755 "$source_wrapper" "$target_path"
}

write_uninstall_script() {
	cat >"$uninstall_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

target_path="\${HOME}/.local/bin/codex"
install_root="\${HOME}/.local/share/codex-wrapper"
uninstall_path="\${install_root}/uninstall.sh"
backup_path="\${install_root}/original-codex"
state_path="\${install_root}/install-state"
bashrc_path="\${HOME}/.bashrc"
zshrc_path="\${HOME}/.zshrc"
profile_path="\${HOME}/.profile"
bash_profile_path="\${HOME}/.bash_profile"
zprofile_path="\${HOME}/.zprofile"
managed_start="# >>> codex-wrapper managed block >>>"
managed_end="# <<< codex-wrapper managed block <<<"

remove_managed_block() {
	local target_rc=\$1
	[[ -f \$target_rc ]] || return 0

	awk -v start="\$managed_start" -v end="\$managed_end" '
		\$0 == start { skip = 1; next }
		\$0 == end { skip = 0; next }
		!skip { print }
	' "\$target_rc" >"\${target_rc}.codex-wrapper.tmp"
	mv "\${target_rc}.codex-wrapper.tmp" "\$target_rc"
}

remove_managed_blocks() {
	remove_managed_block "\$bashrc_path"
	remove_managed_block "\$zshrc_path"
	remove_managed_block "\$profile_path"
	remove_managed_block "\$bash_profile_path"
	remove_managed_block "\$zprofile_path"
}

restore_previous_target() {
	local replaced_existing_target=0

	if [[ -f \$state_path ]]; then
		# shellcheck disable=SC1090
		source "\$state_path"
	fi

	if [[ \${replaced_existing_target:-0} -eq 1 && -f \$backup_path ]]; then
		install -m 0755 "\$backup_path" "\$target_path"
	else
		rm -f "\$target_path"
	fi
}

main() {
	remove_managed_blocks
	restore_previous_target
	rm -f "\$backup_path"
	rm -f "\$state_path"
	rm -f "\$uninstall_path"
	rmdir "\$install_root" 2>/dev/null || true
	log_root="\${HOME}/.local/share"
	rmdir "\$log_root" 2>/dev/null || true
	printf 'Removed codex-wrapper install from %s\n' "\$HOME"
}

main "\$@"
EOF
	chmod 0755 "$uninstall_path"
}

managed_path_block() {
	local block

	block=$(cat <<EOF
$managed_start
case ":\$PATH:" in
	*":\$HOME/.local/bin:"*) ;;
	*) PATH="\$HOME/.local/bin:\$PATH" ;;
esac
export PATH
$managed_end
EOF
)
	printf '%s\n' "$block"
}

append_managed_block() {
	local target_rc=$1
	local block

	block="$(managed_path_block)"

	if [[ -f $target_rc ]]; then
		awk -v start="$managed_start" -v end="$managed_end" '
			$0 == start { skip = 1; next }
			$0 == end { skip = 0; next }
			!skip { print }
		' "$target_rc" >"${target_rc}.codex-wrapper.tmp"
		mv "${target_rc}.codex-wrapper.tmp" "$target_rc"
	fi

	if [[ -f $target_rc && -s $target_rc ]]; then
		printf '\n' >>"$target_rc"
	fi
	printf '%s\n' "$block" >>"$target_rc"
}

append_managed_blocks() {
	append_managed_block "$bashrc_path"
	append_managed_block "$zshrc_path"
	append_managed_block "$profile_path"
	append_managed_block "$bash_profile_path"
	append_managed_block "$zprofile_path"
}

maybe_install_bashrc_block() {
	case "$install_bashrc_mode" in
	yes)
		append_managed_blocks
		log "Installed managed PATH blocks in ~/.bashrc, ~/.zshrc, ~/.profile, ~/.bash_profile, and ~/.zprofile"
		;;
	no)
		return 0
		;;
	ask)
		if confirm "Append managed PATH blocks to your shell startup files?" no; then
			append_managed_blocks
			log "Installed managed PATH blocks in ~/.bashrc, ~/.zshrc, ~/.profile, ~/.bash_profile, and ~/.zprofile"
		else
			log "Skipped shell startup file changes"
		fi
		;;
	esac
}

main() {
	parse_args "$@"
	[[ -f $source_wrapper ]] || die "wrapper source not found: $source_wrapper"

	if needs_precedence_warning; then
		warn "$bin_dir is not currently positioned to override the existing codex command."
		warn "You can still install now and optionally add managed PATH blocks to your shell startup files."
		confirm "Proceed with install?" yes || die "install aborted"
	fi

	ensure_parent_dirs
	install_wrapper
	write_uninstall_script
	maybe_install_bashrc_block

	log "Installed wrapper to $target_path"
	log "Installed uninstall script to $uninstall_path"
	log "Open a new shell after install for shell startup file changes to take effect."
}

main "$@"
