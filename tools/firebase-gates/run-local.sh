#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$REPO_ROOT"

node tools/verify-firebase-gates.mjs
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions run build
npm --prefix functions test
npm --prefix tools/rules_tests ci
npm --prefix tools/rules_tests test
tools/firebase-gates/firebase.sh --config firebase.dev.json emulators:exec \
  --only auth,firestore,functions,storage \
  --project kitchensync-dev-da503 \
  "npm --prefix functions run test:emulator"
