#!/usr/bin/env bash

setup_test_env() {
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d)"
  export TEST_HOME="$TEST_ROOT/home"
  export TEST_WORKDIR="$TEST_ROOT/work"
  export TEST_LOG_DIR="$TEST_ROOT/log"
  export TEST_PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export WRAPPER_PATH="$BATS_TEST_DIRNAME/../src/codex_wrapper.sh"
  export WRAPPER_RUNNER="$BATS_TEST_DIRNAME/helper/run_wrapper.sh"
  export STUB_SYSTEMD_RUN_EXIT=0
  export STUB_SYSTEMD_RUN_INVOKE_COMMAND=0
  export STUB_SYSTEMCTL_MODE="normal"
  export STUB_SYSTEMCTL_RESULT="exit-code"
  export STUB_SYSTEMCTL_EXEC_CODE="1"
  export STUB_SYSTEMCTL_EXEC_STATUS="1"
  export STUB_SYSTEMCTL_EXEC_PID="12345"
  export STUB_CODEX_EXIT=0
  export CODEX_WRAPPER_DEBUG=0

  mkdir -p \
    "$TEST_HOME/.config/gh" \
    "$TEST_HOME/.config/git" \
    "$TEST_HOME/.codex" \
    "$TEST_ROOT/runtime" \
    "$TEST_WORKDIR" \
    "$TEST_LOG_DIR"
  : > "$TEST_HOME/.gitconfig"
  : > "$TEST_WORKDIR/file.txt"
}

teardown_test_env() {
  if [[ -n ${TEST_SOCAT_PID:-} ]]; then
    kill "$TEST_SOCAT_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_ROOT"
}

run_wrapper() {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_PATH" \
    XDG_RUNTIME_DIR="$TEST_ROOT/runtime" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$TEST_ROOT/runtime/bus" \
    CODEX_WRAPPER_DEBUG="$CODEX_WRAPPER_DEBUG" \
    STUB_LOG_DIR="$TEST_LOG_DIR" \
    STUB_SYSTEMD_RUN_EXIT="$STUB_SYSTEMD_RUN_EXIT" \
    STUB_SYSTEMD_RUN_INVOKE_COMMAND="$STUB_SYSTEMD_RUN_INVOKE_COMMAND" \
    STUB_SYSTEMCTL_MODE="$STUB_SYSTEMCTL_MODE" \
    STUB_SYSTEMCTL_RESULT="$STUB_SYSTEMCTL_RESULT" \
    STUB_SYSTEMCTL_EXEC_CODE="$STUB_SYSTEMCTL_EXEC_CODE" \
    STUB_SYSTEMCTL_EXEC_STATUS="$STUB_SYSTEMCTL_EXEC_STATUS" \
    STUB_SYSTEMCTL_EXEC_PID="$STUB_SYSTEMCTL_EXEC_PID" \
    STUB_CODEX_EXIT="$STUB_CODEX_EXIT" \
    WRAPPER_TEST_WORKDIR="$TEST_WORKDIR" \
    WRAPPER_TEST_WRAPPER="$WRAPPER_PATH" \
    CODEX_WRAPPER_REAL_CODEX="$BATS_TEST_DIRNAME/stubs/codex" \
    "$WRAPPER_RUNNER" "$@"
}

run_wrapper_tty() {
  local cmd=
  cmd="$(quote_cmd env \
    HOME="$TEST_HOME" \
    PATH="$TEST_PATH" \
    XDG_RUNTIME_DIR="$TEST_ROOT/runtime" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$TEST_ROOT/runtime/bus" \
    CODEX_WRAPPER_DEBUG="$CODEX_WRAPPER_DEBUG" \
    STUB_LOG_DIR="$TEST_LOG_DIR" \
    STUB_SYSTEMD_RUN_EXIT="$STUB_SYSTEMD_RUN_EXIT" \
    STUB_SYSTEMD_RUN_INVOKE_COMMAND="$STUB_SYSTEMD_RUN_INVOKE_COMMAND" \
    STUB_SYSTEMCTL_MODE="$STUB_SYSTEMCTL_MODE" \
    STUB_SYSTEMCTL_RESULT="$STUB_SYSTEMCTL_RESULT" \
    STUB_SYSTEMCTL_EXEC_CODE="$STUB_SYSTEMCTL_EXEC_CODE" \
    STUB_SYSTEMCTL_EXEC_STATUS="$STUB_SYSTEMCTL_EXEC_STATUS" \
    STUB_SYSTEMCTL_EXEC_PID="$STUB_SYSTEMCTL_EXEC_PID" \
    STUB_CODEX_EXIT="$STUB_CODEX_EXIT" \
    WRAPPER_TEST_WORKDIR="$TEST_WORKDIR" \
    WRAPPER_TEST_WRAPPER="$WRAPPER_PATH" \
    CODEX_WRAPPER_REAL_CODEX="$BATS_TEST_DIRNAME/stubs/codex" \
    "$WRAPPER_RUNNER" "$@")"
  run script -qefc "$cmd" /dev/null
}

quote_cmd() {
  local out="" arg
  for arg in "$@"; do
    printf -v out '%s%q ' "$out" "$arg"
  done
  printf '%s' "${out% }"
}

read_log_file() {
  local file=$1
  [[ -f $file ]] || {
    printf '<missing>'
    return 0
  }
  cat "$file"
}

log_file_exists() {
  local file=$1
  [[ -f $file ]] && printf yes || printf no
}

extract_command_tail() {
  local file=$1
  awk '
    found { print; next }
    $0 == "--" { found = 1 }
  ' "$file"
}

extract_option_values() {
  local option=$1 file=$2
  awk -v opt="$option" '
    prev == "-p" && $0 == opt { print; prev = ""; next }
    { prev = $0 }
  ' "$file"
}

count_lines_matching() {
  local pattern=$1 file=$2
  grep -c -- "$pattern" "$file" 2>/dev/null || true
}

make_ssh_agent_socket() {
  export SSH_AUTH_SOCK="$TEST_ROOT/agent.sock"
  socat UNIX-LISTEN:"$SSH_AUTH_SOCK",fork EXEC:/bin/cat >/dev/null 2>&1 &
  export TEST_SOCAT_PID=$!
}

emit_report() {
  local test_name=$1
  local input_type=$2
  local input_value=$3
  local expected_type=$4
  local expected_value=$5
  local actual_type=$6
  local actual_value=$7
  local result=$8

  cat <<EOF
NAME OF THIS TEST: $test_name
VALUE AND TYPE OF INPUT:
TYPE: $input_type
VALUE:
$input_value
VALUE AND TYPE OF EXPECTED OUTPUT:
TYPE: $expected_type
VALUE:
$expected_value
VALUE AND TYPE OF ACTUAL OUTPUT:
TYPE: $actual_type
VALUE:
$actual_value
VALUE OF RESULT: $result
EOF
}

assert_equal_report() {
  local test_name=$1
  local input_type=$2
  local input_value=$3
  local expected_type=$4
  local expected_value=$5
  local actual_type=$6
  local actual_value=$7
  local result=FAIL

  if [[ "$expected_value" == "$actual_value" ]]; then
    result=PASS
  fi

  emit_report \
    "$test_name" \
    "$input_type" \
    "$input_value" \
    "$expected_type" \
    "$expected_value" \
    "$actual_type" \
    "$actual_value" \
    "$result"

  [[ $result == PASS ]]
}

assert_true_report() {
  local test_name=$1
  local input_type=$2
  local input_value=$3
  local expected_type=$4
  local expected_value=$5
  local actual_type=$6
  local actual_value=$7
  local passed=$8
  local result=FAIL

  if [[ $passed == 1 ]]; then
    result=PASS
  fi

  emit_report \
    "$test_name" \
    "$input_type" \
    "$input_value" \
    "$expected_type" \
    "$expected_value" \
    "$actual_type" \
    "$actual_value" \
    "$result"

  [[ $result == PASS ]]
}
