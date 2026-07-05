#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$ROOT_DIR/tools/rules_tests"
PROJECT_ID="${FIRESTORE_RULES_TEST_PROJECT:-kitchensync-rules-test}"
EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:18080}"
EMULATOR_HOSTNAME="${EMULATOR_HOST%:*}"
EMULATOR_PORT="${EMULATOR_HOST##*:}"
TMP_CONFIG="$(mktemp)"

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

firebase emulators:start --only firestore --project="$PROJECT_ID" \
  --config "$TMP_CONFIG" \
  >/tmp/kitchensync-firestore-emulator.log 2>&1 &
EMULATOR_PID=$!

cleanup() {
  kill "$EMULATOR_PID" >/dev/null 2>&1 || true
  wait "$EMULATOR_PID" >/dev/null 2>&1 || true
  rm -f "$TMP_CONFIG"
}
trap cleanup EXIT

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
GCLOUD_PROJECT="$PROJECT_ID" FIRESTORE_EMULATOR_HOST="$EMULATOR_HOST" node ./node_modules/vitest/vitest.mjs run
