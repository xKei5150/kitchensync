#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$ROOT_DIR/tools/rules_tests"
PROJECT_ID="${FIRESTORE_RULES_TEST_PROJECT:-kitchensync-rules-test}"
EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:18080}"
EMULATOR_HOSTNAME="${EMULATOR_HOST%:*}"
EMULATOR_PORT="${EMULATOR_HOST##*:}"
TMP_CONFIG="$(mktemp)"
EMULATOR_PID=""
EMULATOR_DESCENDANTS=()

if nc -z "$EMULATOR_HOSTNAME" "$EMULATOR_PORT" >/dev/null 2>&1; then
  echo "Port $EMULATOR_PORT is already in use at $EMULATOR_HOSTNAME; set FIRESTORE_EMULATOR_HOST to a free host:port." >&2
  exit 1
fi

node -e "
const fs = require('node:fs');
const config = JSON.parse(fs.readFileSync('$ROOT_DIR/firebase.json', 'utf8'));
config.emulators = config.emulators || {};
config.emulators.firestore = { ...(config.emulators.firestore || {}), host: '$EMULATOR_HOSTNAME', port: Number('$EMULATOR_PORT') };
fs.writeFileSync('$TMP_CONFIG', JSON.stringify(config));
"

# Give the Firebase CLI its own process group. The Firestore Java emulator
# creates another group, so cleanup also records and terminates descendants.
set -m
firebase emulators:start --only firestore --project="$PROJECT_ID" \
  --config "$TMP_CONFIG" \
  >/tmp/kitchensync-firestore-emulator.log 2>&1 &
EMULATOR_PID=$!

collect_descendants() {
  local parent_pid="$1"
  local child_pid

  while IFS= read -r child_pid; do
    [[ -n "$child_pid" ]] || continue
    collect_descendants "$child_pid"
    printf '%s\n' "$child_pid"
  done < <(pgrep -P "$parent_pid" 2>/dev/null || true)
}

has_live_emulator_processes() {
  local pid

  for pid in "$EMULATOR_PID" "${EMULATOR_DESCENDANTS[@]}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}

terminate_emulator_processes() {
  local signal="$1"
  local pid

  kill -"$signal" -- "-$EMULATOR_PID" >/dev/null 2>&1 || true
  for pid in "${EMULATOR_DESCENDANTS[@]}"; do
    kill -"$signal" "$pid" >/dev/null 2>&1 || true
  done
}

cleanup() {
  local status=$?
  local cleanup_status=0

  trap - EXIT HUP INT TERM

  if [[ -n "$EMULATOR_PID" ]]; then
    while IFS= read -r descendant_pid; do
      [[ -n "$descendant_pid" ]] || continue
      EMULATOR_DESCENDANTS+=("$descendant_pid")
    done < <(collect_descendants "$EMULATOR_PID")
    terminate_emulator_processes TERM

    for _ in {1..20}; do
      if ! has_live_emulator_processes && ! nc -z "$EMULATOR_HOSTNAME" "$EMULATOR_PORT" >/dev/null 2>&1; then
        break
      fi
      sleep 0.25
    done

    if has_live_emulator_processes || nc -z "$EMULATOR_HOSTNAME" "$EMULATOR_PORT" >/dev/null 2>&1; then
      terminate_emulator_processes KILL
    fi

    wait "$EMULATOR_PID" >/dev/null 2>&1 || true
  fi

  rm -f "$TMP_CONFIG"

  if nc -z "$EMULATOR_HOSTNAME" "$EMULATOR_PORT" >/dev/null 2>&1; then
    echo "Firestore emulator cleanup left $EMULATOR_HOST bound" >&2
    cleanup_status=1
  fi

  if has_live_emulator_processes; then
    echo "Firestore emulator cleanup left a recorded process running" >&2
    cleanup_status=1
  fi

  if [[ "$cleanup_status" -ne 0 ]]; then
    return "$cleanup_status"
  fi

  return "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

for _ in {1..60}; do
  if nc -z "$EMULATOR_HOSTNAME" "$EMULATOR_PORT" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

if ! nc -z "$EMULATOR_HOSTNAME" "$EMULATOR_PORT" >/dev/null 2>&1; then
  cat /tmp/kitchensync-firestore-emulator.log >&2
  echo "Firestore emulator did not start on $EMULATOR_HOST" >&2
  exit 1
fi

cd "$TEST_DIR"
GCLOUD_PROJECT="$PROJECT_ID" FIRESTORE_EMULATOR_HOST="$EMULATOR_HOST" node ./node_modules/vitest/vitest.mjs run "$@"
