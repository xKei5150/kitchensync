#!/usr/bin/env bash
#
# Reproducible driver for the iOS integration suite.
#
# The suite is not uniform: four of its targets need parameters or a companion
# process, and driving them without those looks exactly like a product defect.
# This script is the executable record of how each one must be driven.
#
#   scripts/run-integration.sh                     # every target
#   scripts/run-integration.sh shopping_mvp_emulator recipe_nav
#   scripts/run-integration.sh --list              # show target names
#
# See docs/integration-test-harness.md for the reasoning behind each rule.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# --- Alternate emulator stack -------------------------------------------------
# NEVER reuse the dev emulator ports (9099/8080/5001/9199/4000). A sweep that
# restarts the emulator between targets would wipe whatever the developer has
# running there.
readonly FIREBASE_CONFIG="firebase.reverify.json"
readonly FIREBASE_PROJECT="kitchensync-dev-da503"
readonly AUTH_PORT=19099
readonly FIRESTORE_PORT=18090
readonly FUNCTIONS_PORT=15001
readonly STORAGE_PORT=19198
readonly FORBIDDEN_PORTS=(9099 8080 5001 9199 4000)

# Port with nothing listening on it, for the unreachable-backend target.
readonly UNUSED_FUNCTIONS_PORT="${UNUSED_FUNCTIONS_PORT:-56551}"

readonly CAPTURE_SIGNAL_PORT="${CAPTURE_SIGNAL_PORT:-55401}"
readonly PLATFORM="${INTEGRATION_PLATFORM:-ios}"
case "$PLATFORM" in
ios)
  readonly DEFAULT_DEVICE="B1177420-2859-43F7-8E26-B3835A85C984"
  readonly CAPTURE_SIGNAL_HOST="127.0.0.1"
  ;;
android)
  # Android's emulator maps 10.0.2.2 to the host loopback interface. Bind the
  # capture handshake listener to every local interface so screenshot targets
  # can reach it as well as their iOS counterparts can reach 127.0.0.1.
  readonly DEFAULT_DEVICE="emulator-5554"
  readonly CAPTURE_SIGNAL_HOST="0.0.0.0"
  ;;
*)
  printf 'Unsupported INTEGRATION_PLATFORM: %s (expected ios or android)\n' "$PLATFORM" >&2
  exit 2
  ;;
esac
readonly DEVICE="${INTEGRATION_DEVICE:-$DEFAULT_DEVICE}"
if [ "$PLATFORM" = "android" ]; then
  if command -v adb >/dev/null 2>&1; then
    readonly ADB="$(command -v adb)"
  else
    readonly ADB="${INTEGRATION_ADB:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb}"
  fi
fi
readonly DRIVER="integration_test/test_driver/integration_test.dart"
readonly APP_PACKAGE="com.kitchensync.app"
readonly APP_ACTIVITY="$APP_PACKAGE/com.example.kitchensync.MainActivity"
readonly TARGET_TIMEOUT_SECONDS="${TARGET_TIMEOUT_SECONDS:-900}"
readonly EMULATOR_READY_TIMEOUT_SECONDS=180

LOG_DIR="${INTEGRATION_LOG_DIR:-$REPO_ROOT/.integration-logs}"
EMULATOR_PID=""
CAPTURE_PID=""
PASSED=()
FAILED=()

log() { printf '\n\033[1m[harness]\033[0m %s\n' "$*"; }
fail() { printf '\n\033[31m[harness] %s\033[0m\n' "$*" >&2; exit 1; }

# --- macOS has no `timeout`/`gtimeout`; watchdog inline -----------------------
# Without this a wedged simulator run blocks the whole sweep indefinitely.
run_with_watchdog() {
  local seconds="$1"; shift
  "$@" &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$seconds" ]; then
      kill -TERM "$pid" 2>/dev/null || true
      sleep 5
      kill -KILL "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

port_is_listening() { nc -z 127.0.0.1 "$1" >/dev/null 2>&1; }

# A listening port is NOT readiness. Firestore accepts connections before it can
# serve, and a target that starts in that window dies at its first read with
# `[cloud_firestore/unavailable] The service is currently unavailable` — which
# reads exactly like a product defect. Probe the same admin surface the tests
# use; 200 (found) and 404 (absent) both mean "serving".
firestore_is_serving() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' \
    -H 'Authorization: Bearer owner' \
    "http://127.0.0.1:$FIRESTORE_PORT/v1/projects/$FIREBASE_PROJECT/databases/(default)/documents/readiness/probe" \
    2>/dev/null)" || return 1
  [ "$code" = "200" ] || [ "$code" = "404" ]
}

assert_dev_emulator_untouched() {
  local configured
  configured="$(python3 -c '
import json, sys
emulators = json.load(open(sys.argv[1]))["emulators"]
print(" ".join(str(v["port"]) for v in emulators.values() if isinstance(v, dict) and "port" in v))
' "$FIREBASE_CONFIG")"
  for port in $configured; do
    for forbidden in "${FORBIDDEN_PORTS[@]}"; do
      [ "$port" = "$forbidden" ] &&
        fail "$FIREBASE_CONFIG uses dev emulator port $port. Refusing to run."
    done
  done
  return 0
}

# --- Emulator lifecycle -------------------------------------------------------
stop_emulator() {
  [ -n "$EMULATOR_PID" ] || return 0
  kill -TERM "-$EMULATOR_PID" 2>/dev/null || kill -TERM "$EMULATOR_PID" 2>/dev/null || true
  local waited=0
  while kill -0 "$EMULATOR_PID" 2>/dev/null && [ "$waited" -lt 30 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  kill -KILL "-$EMULATOR_PID" 2>/dev/null || kill -KILL "$EMULATOR_PID" 2>/dev/null || true
  wait "$EMULATOR_PID" 2>/dev/null || true
  EMULATOR_PID=""
  # The ports must actually be released before the next target binds them.
  local released=0
  while [ "$released" -lt 30 ]; do
    port_is_listening "$FIRESTORE_PORT" || port_is_listening "$FUNCTIONS_PORT" || break
    sleep 1
    released=$((released + 1))
  done
}

start_emulator() {
  stop_emulator
  log "starting emulator stack (auth:$AUTH_PORT firestore:$FIRESTORE_PORT functions:$FUNCTIONS_PORT storage:$STORAGE_PORT)"
  set -m
  firebase emulators:start \
    --config "$FIREBASE_CONFIG" \
    --project "$FIREBASE_PROJECT" \
    --only auth,firestore,functions,storage \
    >"$LOG_DIR/emulator.log" 2>&1 &
  EMULATOR_PID=$!
  set +m

  local waited=0
  while [ "$waited" -lt "$EMULATOR_READY_TIMEOUT_SECONDS" ]; do
    if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
      tail -40 "$LOG_DIR/emulator.log" >&2
      fail "emulator exited during startup"
    fi
    if port_is_listening "$AUTH_PORT" && port_is_listening "$FIRESTORE_PORT" &&
      port_is_listening "$FUNCTIONS_PORT" && port_is_listening "$STORAGE_PORT" &&
      firestore_is_serving; then
      log "emulator ready after ${waited}s"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  tail -40 "$LOG_DIR/emulator.log" >&2
  fail "emulator did not become ready within ${EMULATOR_READY_TIMEOUT_SECONDS}s"
}

start_capture_listener() {
  stop_capture_listener
  python3 scripts/capture_signal_server.py "$CAPTURE_SIGNAL_PORT" \
    --host "$CAPTURE_SIGNAL_HOST" \
    >"$LOG_DIR/capture-signal.log" 2>&1 &
  CAPTURE_PID=$!
  local waited=0
  while [ "$waited" -lt 15 ]; do
    port_is_listening "$CAPTURE_SIGNAL_PORT" && return 0
    kill -0 "$CAPTURE_PID" 2>/dev/null || fail "capture-signal listener died on startup"
    sleep 1
    waited=$((waited + 1))
  done
  fail "capture-signal listener did not bind $CAPTURE_SIGNAL_PORT"
}

stop_capture_listener() {
  [ -n "$CAPTURE_PID" ] || return 0
  kill -TERM "$CAPTURE_PID" 2>/dev/null || true
  wait "$CAPTURE_PID" 2>/dev/null || true
  CAPTURE_PID=""
}

cleanup() {
  stop_capture_listener
  stop_emulator
}
trap cleanup EXIT INT TERM

# --- Target invocation --------------------------------------------------------
base_defines() {
  local functions_port="${1:-$FUNCTIONS_PORT}"
  printf '%s\n' \
    "--dart-define=ENV=dev" \
    "--dart-define=USE_EMULATOR=true" \
    "--dart-define=FIRESTORE_EMULATOR_PORT=$FIRESTORE_PORT" \
    "--dart-define=AUTH_EMULATOR_PORT=$AUTH_PORT" \
    "--dart-define=STORAGE_EMULATOR_PORT=$STORAGE_PORT" \
    "--dart-define=FUNCTIONS_EMULATOR_PORT=$functions_port"
}

drive() {
  local target="$1"; shift
  local -a defines=()
  while IFS= read -r line; do defines+=("$line"); done < <(base_defines)
  defines+=("$@")
  run_with_watchdog "$TARGET_TIMEOUT_SECONDS" \
    flutter drive \
    --driver="$DRIVER" \
    --target="integration_test/${target}_test.dart" \
    -d "$DEVICE" \
    "${defines[@]}"
}

drive_existing_app() {
  local target="$1"
  local vm_service_url="$2"
  run_with_watchdog "$TARGET_TIMEOUT_SECONDS" \
    flutter drive \
    --use-existing-app="$vm_service_url" \
    --driver="$DRIVER" \
    --target="integration_test/${target}_test.dart" \
    -d "$DEVICE"
}

android_package_state() {
  "$ADB" -s "$DEVICE" shell dumpsys package "$APP_PACKAGE" |
    rg 'firstInstallTime=|lastUpdateTime=|dataDir='
}

android_app_pid() {
  local pid
  for _ in $(seq 1 60); do
    pid="$("$ADB" -s "$DEVICE" shell pidof "$APP_PACKAGE" || true)"
    if [ -n "$pid" ]; then
      printf '%s\n' "$pid"
      return 0
    fi
    sleep 1
  done
  return 1
}

ANDROID_SESSION_FORWARD_PORT=""

android_session_vm_service_url() {
  local device_log
  local device_port
  local path
  local host_port

  for _ in $(seq 1 60); do
    device_log="$("$ADB" -s "$DEVICE" logcat -d -v brief)"
    if [[ "$device_log" =~ http://127\.0\.0\.1:([0-9]+)/([^[:space:]]+) ]]; then
      device_port="${BASH_REMATCH[1]}"
      path="${BASH_REMATCH[2]%/}"
      host_port="$("$ADB" -s "$DEVICE" forward tcp:0 "tcp:$device_port")"
      ANDROID_SESSION_FORWARD_PORT="$host_port"
      printf 'http://127.0.0.1:%s/%s\n' "$host_port" "$path"
      return 0
    fi
    sleep 1
  done

  fail 'Android session restore app did not expose a Dart VM service within 60s'
}

remove_android_session_forward() {
  [ -n "$ANDROID_SESSION_FORWARD_PORT" ] || return 0
  "$ADB" -s "$DEVICE" forward --remove "tcp:$ANDROID_SESSION_FORWARD_PORT" \
    >/dev/null 2>&1 || true
  ANDROID_SESSION_FORWARD_PORT=""
}

start_android_session_process() {
  local phase="$1"
  "$ADB" -s "$DEVICE" logcat -c
  "$ADB" -s "$DEVICE" shell am start \
    -n "$APP_ACTIVITY" --es session_restore_phase "$phase" >/dev/null
}

run_android_session_restore() {
  local target="email_auth_session_restore_emulator"
  local run_id="restore-$(date +%s)"
  local -a defines=()
  local create_package_state
  local restore_package_state
  local create_pid
  local restore_pid
  local vm_service_url

  while IFS= read -r line; do defines+=("$line"); done < <(base_defines)
  defines+=(
    "--dart-define=AUTH_SESSION_RUN_ID=$run_id"
    '--dart-define=AUTH_SESSION_ANDROID_INTENT_PHASE=true'
  )

  # Compile and install one binary before the first phase. The only package
  # clear is here, before create; phase two only force-stops and relaunches it.
  flutter build apk --debug --target="integration_test/${target}_test.dart" \
    "${defines[@]}"
  "$ADB" -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk \
    >/dev/null
  "$ADB" -s "$DEVICE" shell pm clear "$APP_PACKAGE" >/dev/null

  start_android_session_process create
  vm_service_url="$(android_session_vm_service_url)"
  drive_existing_app "$target" "$vm_service_url"
  remove_android_session_forward

  create_pid="$(android_app_pid)" ||
    fail 'Android create phase did not leave an app process to restart'
  create_package_state="$(android_package_state)"
  printf '[harness] Android create PID: %s\n%s\n' "$create_pid" "$create_package_state"

  "$ADB" -s "$DEVICE" shell am force-stop "$APP_PACKAGE"
  [ -z "$("$ADB" -s "$DEVICE" shell pidof "$APP_PACKAGE" || true)" ] ||
    fail 'Android session restore could not stop the create-phase process'

  start_android_session_process restore
  restore_pid="$(android_app_pid)" ||
    fail 'Android restore phase did not start an app process'
  [ "$create_pid" != "$restore_pid" ] ||
    fail 'Android restore phase reused the create-phase process'
  restore_package_state="$(android_package_state)"
  [ "$create_package_state" = "$restore_package_state" ] ||
    fail 'Android package metadata changed between create and restore phases'
  printf '[harness] Android restore PID: %s\n%s\n' "$restore_pid" "$restore_package_state"

  vm_service_url="$(android_session_vm_service_url)"
  local status=0
  drive_existing_app "$target" "$vm_service_url" || status=$?
  remove_android_session_forward
  return "$status"
}

prepare_android_device() {
  [ "$PLATFORM" = "android" ] || return 0

  # A sleeping AVD can launch Flutter with a 0x0 surface. The app then never
  # exposes its driver extension, leaving the target watchdog to report an
  # opaque timeout after the APK was successfully installed. Wake and keep the
  # dedicated verification AVD awake immediately before every driver launch.
  "$ADB" -s "$DEVICE" wait-for-device
  "$ADB" -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  "$ADB" -s "$DEVICE" shell wm dismiss-keyguard >/dev/null 2>&1 || true
  "$ADB" -s "$DEVICE" shell svc power stayon true >/dev/null 2>&1 || true
}

# Every target that needs more than the base defines. Anything absent from this
# case runs on the base defines against a freshly restarted emulator.
run_target() {
  local target="$1"
  case "$target" in
  functions_unused_port)
    # Functions must point at a port with NOTHING listening. Pointing it at the
    # live emulator makes the call succeed and the assertion fail spuriously.
    port_is_listening "$UNUSED_FUNCTIONS_PORT" &&
      fail "UNUSED_FUNCTIONS_PORT $UNUSED_FUNCTIONS_PORT has a listener; pick another"
    local -a defines=()
    while IFS= read -r line; do defines+=("$line"); done \
      < <(base_defines "$UNUSED_FUNCTIONS_PORT")
    defines+=("--dart-define=UNUSED_FUNCTIONS_PORT=$UNUSED_FUNCTIONS_PORT")
    run_with_watchdog "$TARGET_TIMEOUT_SECONDS" \
      flutter drive --driver="$DRIVER" \
      --target="integration_test/${target}_test.dart" -d "$DEVICE" "${defines[@]}"
    ;;
  shopping_mvp_emulator)
    start_capture_listener
    local status=0
    drive "$target" \
      "--dart-define=QA_CANONICAL_DATE=$(date +%Y-%m-%d)" \
      "--dart-define=FINAL_CAPTURE_SIGNAL_PORT=$CAPTURE_SIGNAL_PORT" || status=$?
    stop_capture_listener
    return "$status"
    ;;
  shopping_visual_state_matrix)
    start_capture_listener
    local status=0
    drive "$target" "--dart-define=VISUAL_CAPTURE_SIGNAL_PORT=$CAPTURE_SIGNAL_PORT" || status=$?
    stop_capture_listener
    return "$status"
    ;;
  email_auth_session_restore_emulator)
    # Two app processes, ONE emulator: phase `create` registers the account and
    # phase `restore` relaunches and proves the session survived. Restarting the
    # emulator between phases destroys the account, so both phases run here
    # against the single stack started by the caller.
    if [ "$PLATFORM" = "android" ]; then
      run_android_session_restore || return $?
    else
      local run_id="restore-$(date +%s)"
      drive "$target" \
        "--dart-define=AUTH_SESSION_PHASE=create" \
        "--dart-define=AUTH_SESSION_RUN_ID=$run_id" || return $?
      drive "$target" \
        "--dart-define=AUTH_SESSION_PHASE=restore" \
        "--dart-define=AUTH_SESSION_RUN_ID=$run_id" || return $?
    fi
    ;;
  *)
    drive "$target"
    ;;
  esac
}

all_targets() {
  for path in integration_test/*_test.dart; do
    basename "$path" _test.dart
  done
}

# --- Entry point --------------------------------------------------------------
if [ "${1:-}" = "--list" ]; then
  all_targets
  exit 0
fi

command -v firebase >/dev/null || fail "firebase CLI not found"
command -v python3 >/dev/null || fail "python3 not found"
assert_dev_emulator_untouched

# Xcode's SPM resolution is shared per project directory: running
# `flutter analyze` or `flutter test` while a target is driving corrupts it and
# produces a bogus ~6s failure that looks like a real defect. Refuse to start
# rather than produce a result nobody can trust.
mkdir -p "$LOG_DIR"
if pgrep -f "flutter_tools.snapshot (analyze|test|drive)" >/dev/null 2>&1; then
  fail "another flutter analyze/test/drive is running; it corrupts Xcode SPM resolution"
fi

if [ "$PLATFORM" = "ios" ]; then
  xcrun simctl list devices | grep -q "$DEVICE" || fail "simulator $DEVICE not found"
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
else
  [ -x "$ADB" ] || fail "adb not found at $ADB"
  # Do not pipe human-readable `flutter devices` to `grep -q`: grep exits as
  # soon as it sees the device, causing Flutter to report a broken stdout pipe
  # and making a present Android emulator look absent. The JSON consumer reads
  # the complete response before deciding.
  flutter devices --machine | python3 -c '
import json, sys
device_id = sys.argv[1]
devices = json.load(sys.stdin)
sys.exit(0 if any(device.get("id") == device_id for device in devices) else 1)
' "$DEVICE" || fail "Android device $DEVICE not found"
fi

declare -a TARGETS
if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  while IFS= read -r name; do TARGETS+=("$name"); done < <(all_targets)
fi

log "running ${#TARGETS[@]} target(s) on $DEVICE"
for target in "${TARGETS[@]}"; do
  [ -f "integration_test/${target}_test.dart" ] || fail "unknown target: $target"
done

for target in "${TARGETS[@]}"; do
  # Several targets write at deterministic document ids and only pass against a
  # freshly restarted emulator, so every target gets a clean stack.
  start_emulator
  prepare_android_device
  log "=== $target ==="
  status=0
  run_target "$target" >"$LOG_DIR/$target.log" 2>&1 || status=$?
  if [ "$status" -eq 0 ]; then
    log "PASS $target"
    PASSED+=("$target")
  elif [ "$status" -eq 124 ]; then
    log "FAIL $target (watchdog timeout after ${TARGET_TIMEOUT_SECONDS}s)"
    FAILED+=("$target (timeout)")
  else
    log "FAIL $target (exit $status)"
    tail -30 "$LOG_DIR/$target.log" >&2
    FAILED+=("$target")
  fi
done

stop_emulator

printf '\n===== integration summary =====\n'
printf 'passed: %d\n' "${#PASSED[@]}"
printf 'failed: %d\n' "${#FAILED[@]}"
for target in "${FAILED[@]+"${FAILED[@]}"}"; do printf '  FAIL %s\n' "$target"; done
printf 'logs: %s\n' "$LOG_DIR"
[ "${#FAILED[@]}" -eq 0 ]
