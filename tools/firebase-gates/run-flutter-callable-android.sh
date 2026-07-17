#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
DEVICE_ID=${1:-${ANDROID_DEVICE_ID:-}}

fail() {
  printf 'Android callable gate blocked: %s\n' "$1" >&2
  exit 1
}

[ -n "$DEVICE_ID" ] || fail "pass an explicit Android device ID"
case "$DEVICE_ID" in
  *[!A-Za-z0-9._:-]*) fail "invalid Android device ID: $DEVICE_ID" ;;
esac
ADB_BIN=$(command -v adb 2>/dev/null || true)
if [ -z "$ADB_BIN" ]; then
  ANDROID_SDK=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
  [ -n "$ANDROID_SDK" ] || fail "adb is unavailable"
  ADB_BIN=$ANDROID_SDK/platform-tools/adb
fi
[ -x "$ADB_BIN" ] || fail "adb is unavailable: $ADB_BIN"
"$ADB_BIN" devices | awk -v device="$DEVICE_ID" '
  $1 == device && $2 == "device" { found = 1 }
  END { exit found ? 0 : 1 }
' || fail "device is not connected and ready: $DEVICE_ID"

cd "$REPO_ROOT"
tools/firebase-gates/firebase.sh \
  --config firebase.dev.json \
  emulators:exec \
  --only auth,firestore,functions,storage \
  --project kitchensync-dev-da503 \
  "flutter drive --device-id=$DEVICE_ID --driver=integration_test/test_driver/integration_test.dart --target=integration_test/functions_signed_in_happy_path_test.dart --dart-define=USE_EMULATOR=true --dart-define=ENV=dev --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2"
