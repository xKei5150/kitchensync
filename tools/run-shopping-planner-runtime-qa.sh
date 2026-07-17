#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
evidence="$root/.omo/evidence/task-16-shopping-mvp-hardening"
port="${LOCAL_PLANNER_PORT:-18080}"
token="local-planner-runtime-qa-token"
firebase_config="${LOCAL_PLANNER_FIREBASE_CONFIG:-firebase.task16.json}"
mkdir -p "$evidence"
planner_log="$evidence/planner-runtime.log"
runtime_log="$evidence/planner-runtime-tests.log"

cleanup() {
  if [[ -n "${planner_pid:-}" ]] && kill -0 "$planner_pid" 2>/dev/null; then
    kill "$planner_pid"
    wait "$planner_pid" || true
  fi
}
trap cleanup EXIT INT TERM

bootstrap_dependencies() {
  (
    cd "$root"
    flutter pub get
  )
  (
    cd "$root/services/shopping_allocation_planner"
    flutter pub get
  )
}

if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "planner QA port is already in use: $port" >&2
  exit 1
fi

bootstrap_dependencies

(
  cd "$root/services/shopping_allocation_planner"
  PORT="$port" \
    LOCAL_PLANNER_INTEGRATION_TEST=true \
    FUNCTIONS_EMULATOR=true \
    LOCAL_PLANNER_OIDC_TOKEN="$token" \
    dart run bin/server.dart
) >"$planner_log" 2>&1 &
planner_pid=$!

for _ in $(seq 1 50); do
  if ! kill -0 "$planner_pid" 2>/dev/null; then
    cat "$planner_log" >&2
    exit 1
  fi
  if curl --silent --output /dev/null --write-out '%{http_code}' \
    --request POST "http://127.0.0.1:$port/internal/allocation-drafts" \
    --header "authorization: Bearer $token" \
    --header 'content-type: application/json' \
    --data '{"householdId":"startup-check","intent":{"kind":"shop_now","startDate":"2026-07-13","endDate":"2026-07-13"}}' \
    | grep -qx '200'; then
    break
  fi
  sleep 0.1
done

LOCAL_PLANNER_INTEGRATION_TEST=true \
  LOCAL_PLANNER_URL="http://127.0.0.1:$port" \
  LOCAL_PLANNER_AUDIENCE="local-planner-runtime-qa" \
  LOCAL_PLANNER_OIDC_TOKEN="$token" \
  "$root/tools/firebase-gates/firebase.sh" --config "$firebase_config" emulators:exec \
    --only auth,firestore,functions --project kitchensync-dev-da503 \
    "npm --prefix functions run test:emulator -- plannerRuntime.test.ts" \
    | tee "$runtime_log"

printf 'planner_pid_cleaned=true\nport=%s\n' "$port" >"$evidence/planner-runtime-summary.txt"
