#!/usr/bin/env bats

load helper/common.bash

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "installer installs wrapper, uninstall script, and managed shell startup blocks" {
  run_installer --yes --bashrc yes

  local target uninstall_path resolved_bash resolved_login
  target="$TEST_HOME/.local/bin/codex"
  uninstall_path="$TEST_HOME/.local/share/codex-wrapper/uninstall.sh"
  resolved_bash="$(
    env HOME="$TEST_HOME" PATH="/usr/bin:/bin" \
      bash --rcfile "$TEST_HOME/.bashrc" -ic 'command -v codex' 2>/dev/null | tail -n 1
  )"
  resolved_login="$(
    env HOME="$TEST_HOME" PATH="/usr/bin:/bin" \
      bash --login -c 'command -v codex' 2>/dev/null | tail -n 1
  )"
  input_value="argv: ./install.sh --yes --bashrc yes
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(cat <<EOF
status=$status
target_exists=$(log_file_exists "$target")
target_executable=$([[ -x $target ]] && printf yes || printf no)
uninstall_exists=$(log_file_exists "$uninstall_path")
bashrc_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.bashrc")
zshrc_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.zshrc")
profile_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.profile")
bash_profile_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.bash_profile")
zprofile_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.zprofile")
resolved_bash=$resolved_bash
resolved_login=$resolved_login
EOF
)"

  assert_equal_report \
    "installer installs wrapper, uninstall script, and managed bashrc block" \
    "installer invocation" \
    "$input_value" \
    "status and install record" \
    "$(cat <<EOF
status=0
target_exists=yes
target_executable=yes
uninstall_exists=yes
bashrc_block_count=2
zshrc_block_count=2
profile_block_count=2
bash_profile_block_count=2
zprofile_block_count=2
resolved_bash=$TEST_HOME/.local/bin/codex
resolved_login=$TEST_HOME/.local/bin/codex
EOF
)" \
    "status and install record" \
    "$actual_value"
}

@test "installer preserves an existing user codex and uninstall restores it" {
  mkdir -p "$TEST_HOME/.local/bin"
  cat >"$TEST_HOME/.local/bin/codex" <<'EOF'
#!/usr/bin/env bash
printf 'existing-user-codex\n'
EOF
  chmod 0755 "$TEST_HOME/.local/bin/codex"

  run_installer --yes --bashrc no
  [[ $status -eq 0 ]]

  run_uninstall

  local input_value actual_value
  input_value="argv: existing ~/.local/bin/codex, then install and uninstall
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(cat <<EOF
status=$status
target_exists=$(log_file_exists "$TEST_HOME/.local/bin/codex")
restored_output=$("$TEST_HOME/.local/bin/codex")
backup_exists=$(log_file_exists "$TEST_HOME/.local/share/codex-wrapper/original-codex")
EOF
)"

  assert_equal_report \
    "installer preserves an existing user codex and uninstall restores it" \
    "install and uninstall sequence" \
    "$input_value" \
    "status and restore record" \
"$(cat <<EOF
status=0
target_exists=yes
restored_output=existing-user-codex
backup_exists=no
EOF
)" \
    "status and restore record" \
    "$actual_value"
}

@test "installer warns and aborts when precedence is wrong and user declines" {
  run_installer_with_input $'n\n' --bashrc no

  local input_value actual_value
  input_value="argv: ./install.sh --bashrc no
stdin_type: tty
stdin_value: n"
  actual_value="$(cat <<EOF
status=$status
target_exists=$(log_file_exists "$TEST_HOME/.local/bin/codex")
output_has_warning=$(printf '%s' "$output" | grep -F "warning: $TEST_HOME/.local/bin is not currently positioned" >/dev/null && printf yes || printf no)
output_has_abort=$(printf '%s' "$output" | grep -F "error: install aborted" >/dev/null && printf yes || printf no)
EOF
)"

  assert_equal_report \
    "installer warns and aborts when precedence is wrong and user declines" \
    "installer invocation" \
    "$input_value" \
    "status and warning record" \
    "$(cat <<EOF
status=1
target_exists=no
output_has_warning=yes
output_has_abort=yes
EOF
)" \
    "status and warning record" \
    "$actual_value"
}

@test "installer can continue after warning without bashrc changes" {
  run_installer_with_input $'y\n' --bashrc no

  local input_value actual_value
  input_value="argv: ./install.sh --bashrc no
stdin_type: tty
stdin_value: y"
  actual_value="$(cat <<EOF
status=$status
target_exists=$(log_file_exists "$TEST_HOME/.local/bin/codex")
bashrc_exists=$(log_file_exists "$TEST_HOME/.bashrc")
output_has_warning=$(printf '%s' "$output" | grep -F "warning: $TEST_HOME/.local/bin is not currently positioned" >/dev/null && printf yes || printf no)
EOF
)"

  assert_equal_report \
    "installer can continue after warning without bashrc changes" \
    "installer invocation" \
    "$input_value" \
    "status and continue record" \
    "$(cat <<EOF
status=0
target_exists=yes
bashrc_exists=no
output_has_warning=yes
EOF
)" \
    "status and continue record" \
    "$actual_value"
}

@test "uninstall removes installed files and managed shell startup blocks" {
  run_installer --yes --bashrc yes
  [[ $status -eq 0 ]]

  run_uninstall

  local input_value actual_value
  input_value="argv: ~/.local/share/codex-wrapper/uninstall.sh
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(cat <<EOF
status=$status
target_exists=$(log_file_exists "$TEST_HOME/.local/bin/codex")
uninstall_exists=$(log_file_exists "$TEST_HOME/.local/share/codex-wrapper/uninstall.sh")
bashrc_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.bashrc")
zshrc_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.zshrc")
profile_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.profile")
bash_profile_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.bash_profile")
zprofile_block_count=$(count_lines_matching "codex-wrapper managed block" "$TEST_HOME/.zprofile")
EOF
)"

  assert_equal_report \
    "uninstall removes installed files and managed bashrc block" \
    "uninstall invocation" \
    "$input_value" \
    "status and cleanup record" \
    "$(cat <<EOF
status=0
target_exists=no
uninstall_exists=no
bashrc_block_count=0
zshrc_block_count=0
profile_block_count=0
bash_profile_block_count=0
zprofile_block_count=0
EOF
)" \
    "status and cleanup record" \
    "$actual_value"
}

@test "installer rewrites existing managed shell startup blocks on reinstall" {
  mkdir -p "$TEST_HOME"
  cat >"$TEST_HOME/.bashrc" <<'EOF'
# user config
# >>> codex-wrapper managed block >>>
export PATH="/tmp/old/bin:$PATH"
# <<< codex-wrapper managed block <<<
EOF
  cat >"$TEST_HOME/.zshrc" <<'EOF'
# user config
# >>> codex-wrapper managed block >>>
export PATH="/tmp/old/bin:$PATH"
# <<< codex-wrapper managed block <<<
EOF
  cat >"$TEST_HOME/.bash_profile" <<'EOF'
# user config
# >>> codex-wrapper managed block >>>
export PATH="/tmp/old/bin:$PATH"
# <<< codex-wrapper managed block <<<
EOF

  run_installer --yes --bashrc yes

  local input_value actual_value
  input_value="argv: ./install.sh --yes --bashrc yes with stale managed block
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(cat <<EOF
status=$status
managed_start_count=$(count_lines_matching "^# >>> codex-wrapper managed block >>>$" "$TEST_HOME/.bashrc")
zsh_managed_start_count=$(count_lines_matching "^# >>> codex-wrapper managed block >>>$" "$TEST_HOME/.zshrc")
bash_profile_managed_start_count=$(count_lines_matching "^# >>> codex-wrapper managed block >>>$" "$TEST_HOME/.bash_profile")
new_target_count=$(grep -F 'PATH="$HOME/.local/bin:$PATH"' "$TEST_HOME/.bashrc" | wc -l)
old_target_count=$(( \
  $(count_lines_matching '/tmp/old/bin' "$TEST_HOME/.bashrc") + \
  $(count_lines_matching '/tmp/old/bin' "$TEST_HOME/.zshrc") + \
  $(count_lines_matching '/tmp/old/bin' "$TEST_HOME/.bash_profile") \
))
EOF
)"

  assert_equal_report \
    "installer rewrites an existing managed bashrc block on reinstall" \
    "installer invocation" \
    "$input_value" \
    "status and rewrite record" \
    "$(cat <<EOF
status=0
managed_start_count=1
zsh_managed_start_count=1
bash_profile_managed_start_count=1
new_target_count=1
old_target_count=0
EOF
)" \
    "status and rewrite record" \
    "$actual_value"
}
