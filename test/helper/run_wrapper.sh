#!/usr/bin/env bash
set -uo pipefail

cd "$WRAPPER_TEST_WORKDIR"
source "$WRAPPER_TEST_WRAPPER"
codex "$@"
