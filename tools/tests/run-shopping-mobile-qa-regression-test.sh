#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
RUNNER="$ROOT/tools/run-shopping-mobile-qa.sh"

cleanup_line=$(rg -n '^cleanup\(\) \{' "$RUNNER" | cut -d: -f1)
disarm_line=$(rg -n '^  trap - EXIT INT TERM$' "$RUNNER" | cut -d: -f1)
exit_line=$(rg -n '^  exit "\$status"$' "$RUNNER" | cut -d: -f1)

[ -n "$cleanup_line" ] || {
  printf '%s\n' 'missing cleanup function' >&2
  exit 1
}
[ -n "$disarm_line" ] || {
  printf '%s\n' 'cleanup must disarm EXIT/INT/TERM before it moves the transcript' >&2
  exit 1
}
[ -n "$exit_line" ] || {
  printf '%s\n' 'cleanup must preserve the original runner exit status' >&2
  exit 1
}
[ "$cleanup_line" -lt "$disarm_line" ] && [ "$disarm_line" -lt "$exit_line" ] || {
  printf '%s\n' 'cleanup trap disarm must precede its final exit' >&2
  exit 1
}

rg -F 'await socket.first.timeout' "$ROOT/integration_test/shopping_visual_state_matrix_test.dart" \
  >/dev/null || {
  printf '%s\n' 'in-app matrix capture signal must await the host acknowledgement' >&2
  exit 1
}
rg -F 'await socket.first.timeout' "$ROOT/integration_test/shopping_mvp_emulator_test.dart" \
  >/dev/null || {
  printf '%s\n' 'final capture signal must await the host acknowledgement before teardown' >&2
  exit 1
}
rg -F 'python3 -c' "$RUNNER" >/dev/null || {
  printf '%s\n' 'final capture listener must acknowledge the mobile signal' >&2
  exit 1
}
rg -F 'subprocess.run' "$RUNNER" >/dev/null || {
  printf '%s\n' 'final capture listener must take the native screenshot before acknowledging the test' >&2
  exit 1
}
rg -F 'connection.sendall(b"1")' "$RUNNER" >/dev/null || {
  printf '%s\n' 'final capture listener must acknowledge only after native capture completes' >&2
  exit 1
}
rg -F 'FINAL_CAPTURE_DONE_FILE' "$RUNNER" >/dev/null || {
  printf '%s\n' 'final capture listener must wait for the device screenshot completion receipt' >&2
  exit 1
}
printf '%s\n' 'PASS: cleanup is one-shot and retains the first runner transcript'
