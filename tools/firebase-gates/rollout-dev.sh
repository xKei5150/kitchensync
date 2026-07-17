#!/bin/sh
set -eu

DEV_PROJECT="kitchensync-dev-da503"
REPO_ROOT="${FIREBASE_GATE_REPO_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
FIREBASE_BIN="${FIREBASE_BIN:-$REPO_ROOT/tools/firebase-gates/firebase.sh}"
SMOKE_COMMAND="${FIREBASE_SEMANTIC_SMOKE_COMMAND:-$REPO_ROOT/tools/firebase-gates/smoke-dev.mjs}"
WAIT_ATTEMPTS="${FIREBASE_GATE_WAIT_ATTEMPTS:-30}"
WAIT_SECONDS="${FIREBASE_GATE_WAIT_SECONDS:-10}"

cd "$REPO_ROOT"

fail() {
  printf 'Firebase rollout blocked: %s\n' "$1" >&2
  exit 1
}

command -v "$FIREBASE_BIN" >/dev/null 2>&1 || fail "Firebase CLI is unavailable"
command -v jq >/dev/null 2>&1 || fail "jq is unavailable"
[ -x "$SMOKE_COMMAND" ] || fail "semantic smoke command is not executable: $SMOKE_COMMAND"

default_project=$(jq -r '.projects.default // empty' .firebaserc)
dev_alias=$(jq -r '.projects.dev // empty' .firebaserc)
[ "$default_project" = "$DEV_PROJECT" ] || fail ".firebaserc default must be $DEV_PROJECT"
[ "$dev_alias" = "$DEV_PROJECT" ] || fail ".firebaserc dev must be $DEV_PROJECT"

login_json=$("$FIREBASE_BIN" login:list --json) || fail "Firebase credentials are unavailable"
login_count=$(printf '%s' "$login_json" | jq -er '
  select(.status == "success" and (.result | type == "array")) | .result | length
') || fail "Firebase credential output is malformed"
[ "$login_count" -gt 0 ] || fail "Firebase login has no authenticated account"
active_project=$("$FIREBASE_BIN" use --json | jq -er '
  select(.status == "success" and (.result | type == "string")) | .result
') || fail "Firebase project lookup failed"
[ "$active_project" = "$DEV_PROJECT" ] || fail "active Firebase project is not $DEV_PROJECT"

expected_functions='["shoppingSmoke","completeShoppingList","deleteShoppingList","planShoppingAllocation","mutateShoppingListItem"]'
expected_indexes=$(jq -cer '
  select((.indexes | type) == "array" and (.indexes | length > 0)) |
  select(all(.indexes[];
    (.collectionGroup | type) == "string" and .queryScope == "COLLECTION" and
    (.fields | type) == "array" and (.fields | length > 0) and
    all(.fields[]; (.fieldPath | type) == "string" and .fieldPath != "__name__" and
      (((.order // .arrayConfig) | type) == "string")))) |
  [.indexes[] |
    .collectionGroup + "|" +
      ([.fields[] | .fieldPath + ":" + (.order // .arrayConfig)] | join(","))
  ]
' firestore.indexes.json) || fail "firestore.indexes.json is malformed or declares explicit __name__"

"$FIREBASE_BIN" deploy --project "$DEV_PROJECT" --only functions,firestore:indexes --force

attempt=1
while [ "$attempt" -le "$WAIT_ATTEMPTS" ]; do
  functions_json=$("$FIREBASE_BIN" functions:list --project "$DEV_PROJECT" --json) || {
    [ "$attempt" -lt "$WAIT_ATTEMPTS" ] || fail "deployed Functions are unreachable"
    sleep "$WAIT_SECONDS"
    attempt=$((attempt + 1))
    continue
  }
  indexes_text=$("$FIREBASE_BIN" firestore:indexes --project "$DEV_PROJECT" --database '(default)' --pretty) || {
    [ "$attempt" -lt "$WAIT_ATTEMPTS" ] || fail "deployed indexes are unreachable"
    sleep "$WAIT_SECONDS"
    attempt=$((attempt + 1))
    continue
  }
  functions_ready=$(printf '%s' "$functions_json" | jq -er --argjson expected "$expected_functions" '
    select(.status == "success" and (.result | type == "array")) |
    select(all(.result[]; type == "object" and
      (.id | type) == "string" and (.region | type) == "string" and
      (.platform | type) == "string" and (.runtime | type) == "string" and
      (.state | type) == "string")) |
    [.result[] |
      select(.id as $id | $expected | index($id))
    ] as $required |
    select(($required | length) == ($expected | length)) |
    select(($required | map(.id) | unique | length) == ($expected | length)) |
    select(all($required[]; .region == "us-central1" and .platform == "gcfv2" and
      .runtime == "nodejs22" and .state == "ACTIVE")) | true
  ') || functions_ready=false
  ready_indexes=$(printf '%s\n' "$indexes_text" | awk '
    /^\[READY\] \([^()]+\) -- \([^()]+,[^()]+\)( \([^()]+,[^()]+\))*([[:space:]]+-- Density:(DENSITY_UNSPECIFIED|SPARSE_ALL|SPARSE_ANY|DENSE)[[:space:]]*)?$/ {
      line=$0
      sub(/^\[READY\] \(/, "", line)
      split(line, parts, /\) -- /)
      collection=parts[1]
      fields=parts[2]
      sub(/[[:space:]]+-- Density:(DENSITY_UNSPECIFIED|SPARSE_ALL|SPARSE_ANY|DENSE)[[:space:]]*$/, "", fields)
      gsub(/\) \(/, "\034", fields)
      gsub(/[()]/, "", fields)
      gsub(/,/, ":", fields)
      gsub(/\034/, ",", fields)
      print collection "|" fields
    }
  ' | jq -Rsc 'split("\n") | map(select(length > 0)) | unique') || ready_indexes='[]'
  indexes_ready=$(jq -ner --argjson expected "$expected_indexes" --argjson ready "$ready_indexes" '
    select(all($expected[]; . as $index | $ready | index($index))) | true
  ') || indexes_ready=false
  if [ "$functions_ready" = true ] && [ "$indexes_ready" = true ]; then
    break
  fi
  [ "$attempt" -lt "$WAIT_ATTEMPTS" ] || fail "required Functions metadata or configured indexes are not READY"
  sleep "$WAIT_SECONDS"
  attempt=$((attempt + 1))
done

"$SMOKE_COMMAND" before-rules
"$FIREBASE_BIN" deploy --project "$DEV_PROJECT" --only firestore:rules
"$SMOKE_COMMAND" after-rules

printf 'Firebase dev rollout completed safely for %s\n' "$DEV_PROJECT"
