#!/bin/sh
set -eu

PROD_PROJECT="kitchensync-prod-8d6fd"
REPO_ROOT="${FIREBASE_GATE_REPO_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
FIREBASE_BIN="${FIREBASE_BIN:-$REPO_ROOT/tools/firebase-gates/firebase.sh}"

cd "$REPO_ROOT"

fail() {
  printf 'Firebase prod rollout blocked: %s\n' "$1" >&2
  exit 1
}

# Production is a high-blast-radius target. Require an explicit confirmation flag
# so an accidental `make firebase-rollout-prod` can never deploy.
if [ "$#" -ne 1 ] || [ "$1" != "--confirm-prod" ]; then
  fail "pass --confirm-prod to confirm an explicit production rollout"
fi

command -v "$FIREBASE_BIN" >/dev/null 2>&1 || fail "Firebase CLI is unavailable"
command -v jq >/dev/null 2>&1 || fail "jq is unavailable"

prod_alias=$(jq -r '.projects.prod // empty' .firebaserc)
[ "$prod_alias" = "$PROD_PROJECT" ] || fail ".firebaserc prod must be $PROD_PROJECT"

login_json=$("$FIREBASE_BIN" login:list --json) || fail "Firebase credentials are unavailable"
login_count=$(printf '%s' "$login_json" | jq -er '
  select(.status == "success" and (.result | type == "array")) | .result | length
') || fail "Firebase credential output is malformed"
[ "$login_count" -gt 0 ] || fail "Firebase login has no authenticated account"
active_project=$("$FIREBASE_BIN" use --json | jq -er '
  select(.status == "success" and (.result | type == "string")) | .result
') || fail "Firebase project lookup failed"
[ "$active_project" = "$PROD_PROJECT" ] || fail "active Firebase project is not $PROD_PROJECT"

# Production deploys always use the production Firebase config so the admin
# Hosting CSP and Rules sources are guaranteed to be the production ones.
# Order is deliberate: Rules/Indexes/Storage first, then Functions, then the SPA.
echo "==> [1/5] Deploying Firestore Rules to $PROD_PROJECT"
"$FIREBASE_BIN" deploy --config firebase.prod.json --project "$PROD_PROJECT" --only firestore:rules --force
echo "    OK Firestore Rules"

echo "==> [2/5] Deploying Firestore Indexes to $PROD_PROJECT"
"$FIREBASE_BIN" deploy --config firebase.prod.json --project "$PROD_PROJECT" --only firestore:indexes --force
echo "    OK Firestore Indexes"

echo "==> [3/5] Deploying Storage Rules to $PROD_PROJECT"
"$FIREBASE_BIN" deploy --config firebase.prod.json --project "$PROD_PROJECT" --only storage --force
echo "    OK Storage Rules"

echo "==> [4/5] Deploying Functions to $PROD_PROJECT"
"$FIREBASE_BIN" deploy --config firebase.prod.json --project "$PROD_PROJECT" --only functions --force
echo "    OK Functions"

echo "==> [5/5] Deploying admin Hosting target to $PROD_PROJECT"
"$FIREBASE_BIN" deploy --config firebase.prod.json --project "$PROD_PROJECT" --only hosting:admin --force
echo "    OK admin Hosting"

printf 'Firebase prod rollout completed for %s\n' "$PROD_PROJECT"
