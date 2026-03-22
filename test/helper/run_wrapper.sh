#!/usr/bin/env bash
set -uo pipefail

cd "$WRAPPER_TEST_WORKDIR"
exec "$WRAPPER_TEST_WRAPPER" "$@"
