#!/usr/bin/env bats

load helper/common.bash

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "non-interactive mode uses codex exec inside primary sandbox" {
  run_wrapper

  local actual expected input_value actual_value
  actual="$(extract_command_tail "$TEST_LOG_DIR/systemd-run.args")"
  expected="$BATS_TEST_DIRNAME/stubs/codex
exec
--dangerously-bypass-approvals-and-sandbox"
  input_value="argv: codex
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(printf 'status=%s\ncommand_tail=\n%s' "$status" "$actual")"

  assert_equal_report \
    "non-interactive mode uses codex exec inside primary sandbox" \
    "wrapper invocation" \
    "$input_value" \
    "command tail prefix" \
    "$(printf 'status=0\ncommand_tail=\n%s' "$expected")" \
    "command tail prefix" \
    "$(printf 'status=%s\ncommand_tail=\n%s' "$status" "$(printf '%s' "$actual" | sed -n '1,3p')")"
}

@test "interactive tty mode uses codex without exec" {
  run_wrapper_tty

  local actual expected input_value actual_value
  actual="$(extract_command_tail "$TEST_LOG_DIR/systemd-run.args")"
  expected="$BATS_TEST_DIRNAME/stubs/codex
--dangerously-bypass-approvals-and-sandbox"
  input_value="argv: codex
stdin_type: tty
stdin_value: <empty>"
  actual_value="$(printf 'status=%s\ncommand_tail=\n%s' "$status" "$(printf '%s' "$actual" | sed -n '1,2p')")"

  assert_equal_report \
    "interactive tty mode uses codex without exec" \
    "wrapper invocation" \
    "$input_value" \
    "command tail prefix" \
    "$(printf 'status=0\ncommand_tail=\n%s' "$expected")" \
    "command tail prefix" \
    "$actual_value"
}

@test "primary mode mounts workspace defaults and optional ssh agent socket" {
  make_ssh_agent_socket
  run_wrapper --ro "$TEST_HOME/.config"

  local args_file actual_value input_value passed
  args_file="$TEST_LOG_DIR/systemd-run.args"
  input_value="argv: codex --ro $TEST_HOME/.config
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(cat <<EOF
BindPaths workdir count: $(extract_option_values "BindPaths=$TEST_WORKDIR" "$args_file" | wc -l)
ReadWritePaths workdir count: $(extract_option_values "ReadWritePaths=$TEST_WORKDIR" "$args_file" | wc -l)
BindPaths codex home count: $(extract_option_values "BindPaths=$TEST_HOME/.codex" "$args_file" | wc -l)
ReadWritePaths codex home count: $(extract_option_values "ReadWritePaths=$TEST_HOME/.codex" "$args_file" | wc -l)
BindReadOnlyPaths gh count: $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.config/gh" "$args_file" | wc -l)
BindReadOnlyPaths gitconfig count: $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.gitconfig" "$args_file" | wc -l)
BindReadOnlyPaths git dir count: $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.config/git" "$args_file" | wc -l)
BindReadOnlyPaths custom ro count: $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.config" "$args_file" | wc -l)
BindReadOnlyPaths ssh socket count: $(extract_option_values "BindReadOnlyPaths=$SSH_AUTH_SOCK" "$args_file" | wc -l)
EOF
)"

  passed=0
  if [[ $(extract_option_values "BindPaths=$TEST_WORKDIR" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "ReadWritePaths=$TEST_WORKDIR" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "BindPaths=$TEST_HOME/.codex" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "ReadWritePaths=$TEST_HOME/.codex" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.config/gh" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.gitconfig" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.config/git" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "BindReadOnlyPaths=$TEST_HOME/.config" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "BindReadOnlyPaths=$SSH_AUTH_SOCK" "$args_file" | wc -l) == 1 ]]; then
    passed=1
  fi

  assert_true_report \
    "primary mode mounts workspace defaults and optional ssh agent socket" \
    "wrapper invocation" \
    "$input_value" \
    "mount count record" \
    "each listed mount count equals 1" \
    "mount count record" \
    "$actual_value" \
    "$passed"
}

@test "custom mode forwards native codex flags after double dash" {
  mkdir -p "$TEST_ROOT/reference"
  run_wrapper --ro "$TEST_ROOT/reference" -- --model gpt-5.4 --search --profile work

  local actual_tail input_value actual_value passed
  actual_tail="$(extract_command_tail "$TEST_LOG_DIR/systemd-run.args")"
  input_value="argv: codex --ro $TEST_ROOT/reference -- --model gpt-5.4 --search --profile work
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(cat <<EOF
command_tail:
$actual_tail
custom_ro_mount_count: $(extract_option_values "BindReadOnlyPaths=$TEST_ROOT/reference" "$TEST_LOG_DIR/systemd-run.args" | wc -l)
EOF
)"

  passed=0
  if printf '%s\n' "$actual_tail" | grep -Fx -- "--dangerously-bypass-approvals-and-sandbox" >/dev/null &&
     printf '%s\n' "$actual_tail" | grep -Fx -- "--model" >/dev/null &&
     printf '%s\n' "$actual_tail" | grep -Fx -- "gpt-5.4" >/dev/null &&
     printf '%s\n' "$actual_tail" | grep -Fx -- "--search" >/dev/null &&
     printf '%s\n' "$actual_tail" | grep -Fx -- "--profile" >/dev/null &&
     printf '%s\n' "$actual_tail" | grep -Fx -- "work" >/dev/null &&
     [[ $(extract_option_values "BindReadOnlyPaths=$TEST_ROOT/reference" "$TEST_LOG_DIR/systemd-run.args" | wc -l) == 1 ]]; then
    passed=1
  fi

  assert_true_report \
    "custom mode forwards native codex flags after double dash" \
    "wrapper invocation" \
    "$input_value" \
    "conditions" \
    "dangerous bypass flag present; model/search/profile passthrough present; custom ro mount count equals 1" \
    "record" \
    "$actual_value" \
    "$passed"
}

@test "path normalization deduplicates rw and suppresses duplicate ro when same path is rw" {
  mkdir -p "$TEST_ROOT/alpha" "$TEST_ROOT/beta"
  run_wrapper --rw "$TEST_ROOT/alpha" "$TEST_ROOT/alpha" --ro "$TEST_ROOT/alpha" "$TEST_ROOT/beta"

  local args_file input_value actual_value passed
  args_file="$TEST_LOG_DIR/systemd-run.args"
  input_value="argv: codex --rw $TEST_ROOT/alpha $TEST_ROOT/alpha --ro $TEST_ROOT/alpha $TEST_ROOT/beta
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(cat <<EOF
rw alpha BindPaths count: $(extract_option_values "BindPaths=$TEST_ROOT/alpha" "$args_file" | wc -l)
rw alpha ReadWritePaths count: $(extract_option_values "ReadWritePaths=$TEST_ROOT/alpha" "$args_file" | wc -l)
ro alpha count: $(extract_option_values "BindReadOnlyPaths=$TEST_ROOT/alpha" "$args_file" | wc -l)
ro beta count: $(extract_option_values "BindReadOnlyPaths=$TEST_ROOT/beta" "$args_file" | wc -l)
EOF
)"

  passed=0
  if [[ $(extract_option_values "BindPaths=$TEST_ROOT/alpha" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "ReadWritePaths=$TEST_ROOT/alpha" "$args_file" | wc -l) == 1 ]] &&
     [[ $(extract_option_values "BindReadOnlyPaths=$TEST_ROOT/alpha" "$args_file" | wc -l) == 0 ]] &&
     [[ $(extract_option_values "BindReadOnlyPaths=$TEST_ROOT/beta" "$args_file" | wc -l) == 1 ]]; then
    passed=1
  fi

  assert_true_report \
    "path normalization deduplicates rw and suppresses duplicate ro when same path is rw" \
    "wrapper invocation" \
    "$input_value" \
    "mount count record" \
    "rw alpha bind counts equal 1; ro alpha count equals 0; ro beta count equals 1" \
    "mount count record" \
    "$actual_value" \
    "$passed"
}

@test "missing rw path returns error before any sandbox launch" {
  run_wrapper --rw "$TEST_ROOT/does-not-exist"

  local args_file actual_value input_value
  args_file="$TEST_LOG_DIR/systemd-run.args"
  input_value="argv: codex --rw $TEST_ROOT/does-not-exist
stdin_type: non-tty
stdin_value: <empty>"
  actual_value="$(printf 'status=%s\noutput=\n%s\nsystemd_run_log_exists=%s' \
    "$status" \
    "$output" \
    "$([[ -f $args_file ]] && printf yes || printf no)")"

  assert_equal_report \
    "missing rw path returns error before any sandbox launch" \
    "wrapper invocation" \
    "$input_value" \
    "status and output record" \
    "$(printf 'status=2\noutput=\n%s\nsystemd_run_log_exists=no' "codex: rw path does not exist: $TEST_ROOT/does-not-exist")" \
    "status and output record" \
    "$actual_value"
}

@test "fallback mode constructs native workspace-write argv when systemd-run fails before launch" {
  export STUB_SYSTEMD_RUN_EXIT=1
  export STUB_SYSTEMCTL_EXEC_PID=0
  export CODEX_WRAPPER_DEBUG=1
  run_wrapper -- --help

  local input_value actual_value passed
  input_value="argv: codex -- --help
stdin_type: non-tty
stdin_value: <empty>
stubbed_systemd_run_exit: 1
stubbed_exec_pid: 0"
  actual_value="$(printf 'status=%s\noutput=\n%s' \
    "$status" \
    "$output")"

  passed=0
  if [[ $status == 0 ]] &&
     [[ $output == *"falling back to direct run"* ]] &&
     [[ $output == *"fallback argv: $BATS_TEST_DIRNAME/stubs/codex"* ]] &&
     [[ $output == *"--ask-for-approval"* ]] &&
     [[ $output == *"workspace-write"* ]] &&
     [[ $output == *"--cd"* ]] &&
     [[ -f $TEST_LOG_DIR/codex.args ]] &&
     [[ $(head -n 1 "$TEST_LOG_DIR/codex.args") == "--ask-for-approval" ]]; then
    passed=1
  fi

  assert_true_report \
    "fallback mode constructs native workspace-write argv when systemd-run fails before launch" \
    "wrapper invocation with stubbed launch failure" \
    "$input_value" \
    "conditions" \
    "status equals 0; output contains debug fallback argv with on-request/workspace-write and --cd; stub codex receives native fallback flags" \
    "record" \
    "$actual_value" \
    "$passed"
}
