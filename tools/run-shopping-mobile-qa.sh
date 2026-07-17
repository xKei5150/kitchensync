#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODE=${1:-}
EVIDENCE="$ROOT/.omo/evidence/shopping-mvp-hardening-mobile"
SCREENSHOTS="$ROOT/screenshots"
PROJECT=kitchensync-dev-da503
IOS_DEVICE=DEB9A2C3-0482-49DA-8DFD-C816D1F26DDE
ANDROID_PACKAGE=com.kitchensync.app
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
FIREBASE_PID=
ANDROID_LAUNCHED=0
IOS_LAUNCHED=0
ANDROID_DEVICE=
IOS_FINAL_SIGNAL_PID=
IOS_FINAL_CAPTURE_PID=
IOS_FINAL_SIGNAL_FILE=
IOS_FINAL_CAPTURE_DONE_FILE=
IOS_VISUAL_CAPTURE_PID=
IOS_VISUAL_CAPTURE_FILE=
ANDROID_FINAL_SIGNAL_PID=
ANDROID_FINAL_CAPTURE_PID=
ANDROID_FINAL_SIGNAL_FILE=
ANDROID_FINAL_CAPTURE_DONE_FILE=
ANDROID_VISUAL_CAPTURE_PID=
ANDROID_VISUAL_CAPTURE_FILE=
RUNNER_CONSOLE_TMP=
RUNNER_STATUS_TMP=
QA_CANONICAL_DATE=

fail() { printf '%s\n' "shopping mobile QA: $*" >&2; exit 1; }

write_fingerprints() {
  [ "$1" -eq 0 ] || return 1
  [ -n "$QA_CANONICAL_DATE" ] || return 1
  (
    cd "$ROOT"
    shasum -a 256 \
      tools/run-shopping-mobile-qa.sh \
      integration_test/shopping_mvp_emulator_test.dart \
      integration_test/shopping_visual_state_matrix_test.dart \
      test/features/shopping/shopping_list_screen_test.dart \
      lib/app/app.dart \
      lib/app/router_core.dart \
      lib/app/router_shell_routes.dart \
      lib/core/widgets/ks_nav.dart \
      lib/features/shopping/presentation/screens/shopping_list_screen.dart \
      lib/features/shopping/presentation/screens/shopping_list_body.dart \
      lib/features/shopping/presentation/screens/shopping_list_checklist_row.dart \
      lib/features/shopping/presentation/screens/shopping_list_mutation_actions.dart \
      lib/features/shopping/presentation/screens/shopping_list_substitution_sheet.dart \
      lib/features/shopping/presentation/screens/shopping_list_view_helpers.dart \
      lib/features/shopping/presentation/screens/shopping_home_shop_now.dart \
      functions/src/shopping/controlledEmulatorPlanner.ts \
      pubspec.yaml \
      pubspec.lock \
      firebase.dev.json
  ) >"$EVIDENCE/source.sha256.tmp.$$" || return 1
  (
    cd "$EVIDENCE"
    find . -maxdepth 1 -type f ! -name 'manifest.sha256' ! -name 'source.sha256' \
      ! -name '*.tmp.*' ! -name '*-fingerprint-trace.txt' -print | LC_ALL=C sort | while IFS= read -r file; do
      shasum -a 256 "$file"
    done
  ) >"$EVIDENCE/manifest.sha256.tmp.$$" || return 1
  [ -s "$EVIDENCE/source.sha256.tmp.$$" ] || return 1
  [ -s "$EVIDENCE/manifest.sha256.tmp.$$" ] || return 1
  mv -f "$EVIDENCE/source.sha256.tmp.$$" "$EVIDENCE/source.sha256"
  mv -f "$EVIDENCE/manifest.sha256.tmp.$$" "$EVIDENCE/manifest.sha256"
  (cd "$ROOT" && shasum -a 256 -c "$EVIDENCE/source.sha256" >/dev/null 2>&1) || return 1
  (cd "$EVIDENCE" && shasum -a 256 -c manifest.sha256 >/dev/null 2>&1) || return 1
}

capture_ios_settled_video_frame() {
  signal_port=$1
  expected_signals=$2
  output_prefix=$3
  receipt=$4
  done_file=${5:-}
  python3 -c '
import pathlib
import signal
import socket
import subprocess
import sys
import time

port, expected, udid, prefix, receipt, done_file = sys.argv[1:]
expected = int(expected)
prefix_path = pathlib.Path(prefix)
receipt_path = pathlib.Path(receipt)
for capture_number in range(1, expected + 1):
    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", int(port)))
    listener.listen(1)
    connection, _ = listener.accept()
    if not connection.recv(1):
        raise RuntimeError("empty settled-frame acknowledgement")
    video = prefix_path.with_name(f"{prefix_path.name}-{capture_number}.mov")
    frame = prefix_path.with_name(f"{prefix_path.name}-{capture_number}.png")
    process = subprocess.Popen(
        ["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264", "--display=internal", "--force", str(video)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        line = process.stderr.readline()
        if "Recording started" in line:
            break
        if process.poll() is not None:
            raise RuntimeError(f"recordVideo exited before starting: {line}")
    else:
        process.send_signal(signal.SIGINT)
        raise RuntimeError("recordVideo did not acknowledge its first frame")
    connection.sendall(b"1")
    connection.close()
    listener.close()
    time.sleep(0.5)
    process.send_signal(signal.SIGINT)
    process.communicate(timeout=20)
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(video), "-frames:v", "1", "-c:v", "png", str(frame)],
        check=True,
    )
    if not frame.is_file() or frame.stat().st_size == 0:
        raise RuntimeError(f"missing decoded settled frame: {frame}")
receipt_path.write_text(
    "transport=simctl-recordVideo\n"
    "codec=h264\n"
    "display=internal\n"
    "frame=first-post-acknowledgement-frame\n"
    f"captures={expected}\n"
)
if done_file:
    pathlib.Path(done_file).touch()
' "$signal_port" "$expected_signals" "$IOS_DEVICE" "$output_prefix" "$receipt" "$done_file"
}

cleanup() {
  status=$?
  trap - EXIT INT TERM
  if [ -n "$ANDROID_FINAL_SIGNAL_PID" ] && kill -0 "$ANDROID_FINAL_SIGNAL_PID" 2>/dev/null; then
    kill "$ANDROID_FINAL_SIGNAL_PID" 2>/dev/null || true
    wait "$ANDROID_FINAL_SIGNAL_PID" 2>/dev/null || true
  fi
  if [ -n "$ANDROID_FINAL_CAPTURE_PID" ] && kill -0 "$ANDROID_FINAL_CAPTURE_PID" 2>/dev/null; then
    kill "$ANDROID_FINAL_CAPTURE_PID" 2>/dev/null || true
    wait "$ANDROID_FINAL_CAPTURE_PID" 2>/dev/null || true
  fi
  if [ -n "$ANDROID_FINAL_SIGNAL_FILE" ]; then
    rm -f "$ANDROID_FINAL_SIGNAL_FILE"
  fi
  if [ -n "$ANDROID_FINAL_CAPTURE_DONE_FILE" ]; then
    rm -f "$ANDROID_FINAL_CAPTURE_DONE_FILE"
  fi
  if [ -n "$IOS_FINAL_SIGNAL_PID" ] && kill -0 "$IOS_FINAL_SIGNAL_PID" 2>/dev/null; then
    kill "$IOS_FINAL_SIGNAL_PID" 2>/dev/null || true
    wait "$IOS_FINAL_SIGNAL_PID" 2>/dev/null || true
  fi
  if [ -n "$IOS_FINAL_CAPTURE_PID" ] && kill -0 "$IOS_FINAL_CAPTURE_PID" 2>/dev/null; then
    kill "$IOS_FINAL_CAPTURE_PID" 2>/dev/null || true
    wait "$IOS_FINAL_CAPTURE_PID" 2>/dev/null || true
  fi
  if [ -n "$IOS_FINAL_SIGNAL_FILE" ]; then
    rm -f "$IOS_FINAL_SIGNAL_FILE"
  fi
  if [ -n "$IOS_FINAL_CAPTURE_DONE_FILE" ]; then
    rm -f "$IOS_FINAL_CAPTURE_DONE_FILE"
  fi
  if [ -n "$FIREBASE_PID" ] && kill -0 "$FIREBASE_PID" 2>/dev/null; then
    kill "$FIREBASE_PID" 2>/dev/null || true
    wait "$FIREBASE_PID" 2>/dev/null || true
  fi
  if [ "$ANDROID_LAUNCHED" -eq 1 ] && [ -n "$ANDROID_DEVICE" ]; then
    "$ADB" -s "$ANDROID_DEVICE" emu kill >/dev/null 2>&1 || true
  fi
  if [ "$ANDROID_LAUNCHED" -eq 1 ] && [ -z "$ANDROID_DEVICE" ]; then
    "$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1 }' | while IFS= read -r serial; do
      "$ADB" -s "$serial" emu kill >/dev/null 2>&1 || true
    done
  fi
  if [ "$IOS_LAUNCHED" -eq 1 ]; then
    xcrun simctl shutdown "$IOS_DEVICE" >/dev/null 2>&1 || true
  fi
  if [ -n "$RUNNER_CONSOLE_TMP" ]; then
    if [ -f "$RUNNER_CONSOLE_TMP" ]; then
      mv -f "$RUNNER_CONSOLE_TMP" "$EVIDENCE/${MODE}-runner-console.txt"
    else
      status=1
      printf '%s\n' 'shopping mobile QA: runner transcript was not retained' \
        >"$EVIDENCE/${MODE}-runner-console.txt"
    fi
    printf '%s\n' "$status" >"$RUNNER_STATUS_TMP"
    mv -f "$RUNNER_STATUS_TMP" "$EVIDENCE/${MODE}-runner-status.txt"
    if [ "$status" -eq 0 ]; then
      if ! (set -x; write_fingerprints "$status") \
        2>"$EVIDENCE/${MODE}-fingerprint-trace.txt"; then
        status=1
        rm -f "$EVIDENCE/manifest.sha256" "$EVIDENCE/source.sha256"
      fi
    else
      rm -f "$EVIDENCE/manifest.sha256" "$EVIDENCE/source.sha256"
    fi
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

case "$MODE" in
  android|ios) ;;
  *) fail "usage: tools/run-shopping-mobile-qa.sh {android|ios}" ;;
esac

[ -x "$ADB" ] || fail "required adb missing at $ADB"
mkdir -p "$EVIDENCE"
rm -f "$EVIDENCE/manifest.sha256" "$EVIDENCE/source.sha256"
QA_CANONICAL_DATE=$(TZ=Asia/Manila date '+%Y-%m-%d')
case "$QA_CANONICAL_DATE" in
  ????-??-??) ;;
  *) fail "could not derive canonical local QA date" ;;
esac
RUNNER_CONSOLE_TMP="$EVIDENCE/${MODE}-runner-console.tmp.$$"
RUNNER_STATUS_TMP="$EVIDENCE/${MODE}-runner-status.tmp.$$"
exec >"$RUNNER_CONSOLE_TMP" 2>&1
rm -f "$EVIDENCE"/"$MODE"-*.png
rm -f "$EVIDENCE/${MODE}-fingerprint-error.txt"
rm -f "$EVIDENCE/${MODE}-fingerprint-trace.txt"
rm -rf "$SCREENSHOTS"
mkdir -p "$SCREENSHOTS"

cd "$ROOT"
for port in 9099 8080 5001 9199; do
  nc -z 127.0.0.1 "$port" >/dev/null 2>&1 &&
    fail "Firebase emulator port $port is already in use"
done
USE_CONTROLLED_EMULATOR_PLANNER=true tools/firebase-gates/firebase.sh --config firebase.dev.json emulators:start \
  --only auth,firestore,functions,storage --project "$PROJECT" \
  >"$EVIDENCE/${MODE}-firebase.log" 2>&1 &
FIREBASE_PID=$!

ready=0
attempt=0
while [ "$attempt" -lt 90 ]; do
  if ! kill -0 "$FIREBASE_PID" 2>/dev/null; then
    fail "Firebase emulator exited before becoming ready"
  fi
  all_ready=1
  for port in 9099 8080 5001 9199; do
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1 || all_ready=0
  done
  if [ "$all_ready" -eq 1 ]; then ready=1; break; fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$ready" -eq 1 ] || fail "Firebase emulator ports did not become ready"
sleep 2
kill -0 "$FIREBASE_PID" 2>/dev/null || fail "Firebase emulator exited after readiness"
for port in 9099 8080 5001 9199; do
  nc -z 127.0.0.1 "$port" >/dev/null 2>&1 ||
    fail "Firebase emulator port $port closed after readiness"
done

if [ "$MODE" = android ]; then
  preexisting=$(
    "$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1 }'
  )
  preexisting_matches=$(printf '%s\n' "$preexisting" | while IFS= read -r serial; do
    [ -z "$serial" ] && continue
    if "$ADB" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | grep -qx 'Medium_Phone_API_36.1'; then
      printf '%s\n' "$serial"
    fi
  done)
  printf 'preexisting_android=%s\n' "$preexisting_matches" >"$EVIDENCE/android-device-state.txt"
  if [ -z "$preexisting_matches" ]; then
    flutter emulators --launch Medium_Phone_API_36.1
    ANDROID_LAUNCHED=1
  fi
  attempts=0
  while [ "$attempts" -lt 90 ]; do
    matches=$(
      "$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1 }' | while IFS= read -r serial; do
        [ -z "$serial" ] && continue
        if "$ADB" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | grep -qx 'Medium_Phone_API_36.1'; then
          printf '%s\n' "$serial"
        fi
      done
    )
    count=$(printf '%s\n' "$matches" | awk 'NF { count++ } END { print count + 0 }')
    if [ "$count" -eq 1 ]; then
      ANDROID_DEVICE=$(printf '%s\n' "$matches" | awk 'NF { print; exit }')
      break
    fi
    [ "$count" -gt 1 ] && fail "multiple online Medium_Phone_API_36.1 devices"
    attempts=$((attempts + 1))
    sleep 1
  done
  [ -n "$ANDROID_DEVICE" ] || fail "no online Medium_Phone_API_36.1 device after bounded wait"
  boot_attempts=0
  while [ "$boot_attempts" -lt 90 ]; do
    if [ "$("$ADB" -s "$ANDROID_DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && "$ADB" -s "$ANDROID_DEVICE" shell cmd package path android >/dev/null 2>&1 && "$ADB" -s "$ANDROID_DEVICE" shell cmd activity get-current-user >/dev/null 2>&1; then
      break
    fi
    boot_attempts=$((boot_attempts + 1))
    sleep 1
  done
  [ "$boot_attempts" -lt 90 ] || fail "Medium_Phone_API_36.1 did not complete Android boot"
  if printf '%s\n' "$preexisting" | grep -qx "$ANDROID_DEVICE"; then ANDROID_LAUNCHED=0; fi
  ANDROID_FINAL_SIGNAL_FILE="$EVIDENCE/android-final-signal"
  ANDROID_FINAL_CAPTURE_DONE_FILE="$EVIDENCE/android-final-capture-done"
  ANDROID_FINAL_SIGNAL_PORT=$((52000 + ($$ % 1000)))
  rm -f "$ANDROID_FINAL_SIGNAL_FILE" "$ANDROID_FINAL_CAPTURE_DONE_FILE"
  (python3 -c 'import socket, subprocess, sys; listener = socket.socket(); listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); listener.bind(("127.0.0.1", int(sys.argv[1]))); listener.listen(1); connection, _ = listener.accept(); assert connection.recv(1); open(sys.argv[2], "xb").close(); capture = open(sys.argv[3], "wb"); subprocess.run([sys.argv[4], "-s", sys.argv[5], "exec-out", "screencap", "-p"], stdout=capture, check=True); capture.close(); open(sys.argv[6], "xb").close(); connection.sendall(b"1"); connection.close(); listener.close()' "$ANDROID_FINAL_SIGNAL_PORT" "$ANDROID_FINAL_SIGNAL_FILE" "$EVIDENCE/android-final.png" "$ADB" "$ANDROID_DEVICE" "$ANDROID_FINAL_CAPTURE_DONE_FILE") &
  ANDROID_FINAL_SIGNAL_PID=$!
  sleep 1
  kill -0 "$ANDROID_FINAL_SIGNAL_PID" 2>/dev/null ||
    fail "Android final capture listener did not start"
  flutter drive --driver=integration_test/test_driver/integration_test.dart \
    --target=integration_test/functions_signed_in_happy_path_test.dart -d "$ANDROID_DEVICE" \
    --dart-define=ENV=dev --dart-define=USE_EMULATOR=true \
    --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 \
    --dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2 \
    --dart-define=AUTH_EMULATOR_HOST=10.0.2.2 \
    --dart-define=FUNCTIONS_EMULATOR_HOST=10.0.2.2 \
    --dart-define=STORAGE_EMULATOR_HOST=10.0.2.2
  ANDROID_VISUAL_CAPTURE_FILE="$EVIDENCE/android-matrix-in-app.png"
  ANDROID_VISUAL_CAPTURE_PORT=$((54000 + ($$ % 1000)))
  rm -f "$ANDROID_VISUAL_CAPTURE_FILE"
  (python3 -c 'import socket, subprocess, sys; listener = socket.socket(); listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); listener.bind(("127.0.0.1", int(sys.argv[1]))); listener.listen(1); connection, _ = listener.accept(); assert connection.recv(1); capture = open(sys.argv[2], "wb"); subprocess.run([sys.argv[3], "-s", sys.argv[4], "exec-out", "screencap", "-p"], stdout=capture, check=True); capture.close(); connection.sendall(b"1"); connection.close(); listener.close()' "$ANDROID_VISUAL_CAPTURE_PORT" "$ANDROID_VISUAL_CAPTURE_FILE" "$ADB" "$ANDROID_DEVICE") &
  ANDROID_VISUAL_CAPTURE_PID=$!
  flutter drive --driver=integration_test/test_driver/integration_test.dart \
    --target=integration_test/shopping_visual_state_matrix_test.dart -d "$ANDROID_DEVICE" \
    --dart-define=ENV=dev --dart-define=USE_EMULATOR=true \
    --dart-define=VISUAL_CAPTURE_SIGNAL_PORT="$ANDROID_VISUAL_CAPTURE_PORT"
  wait "$ANDROID_VISUAL_CAPTURE_PID" || fail "Android in-app matrix capture failed"
  ANDROID_VISUAL_CAPTURE_PID=
  [ -s "$ANDROID_VISUAL_CAPTURE_FILE" ] || fail "missing Android in-app matrix capture"
  flutter drive --driver=integration_test/test_driver/integration_test.dart \
    --target=integration_test/shopping_mvp_emulator_test.dart -d "$ANDROID_DEVICE" \
    --dart-define=ENV=dev --dart-define=USE_EMULATOR=true \
    --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 \
    --dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2 \
    --dart-define=AUTH_EMULATOR_HOST=10.0.2.2 \
    --dart-define=FUNCTIONS_EMULATOR_HOST=10.0.2.2 \
    --dart-define=STORAGE_EMULATOR_HOST=10.0.2.2 \
    --dart-define=QA_CANONICAL_DATE="$QA_CANONICAL_DATE" \
    --dart-define=FINAL_CAPTURE_SIGNAL_PORT="$ANDROID_FINAL_SIGNAL_PORT"
  wait "$ANDROID_FINAL_SIGNAL_PID" || fail "Android final capture signal listener failed"
  ANDROID_FINAL_SIGNAL_PID=
  [ -f "$ANDROID_FINAL_CAPTURE_DONE_FILE" ] || fail "Android final capture completion receipt missing"
  rm -f "$ANDROID_FINAL_SIGNAL_FILE"
  rm -f "$ANDROID_FINAL_CAPTURE_DONE_FILE"
  for screenshot in "$SCREENSHOTS"/android-*.png; do
    [ -f "$screenshot" ] || continue
    case "$screenshot" in *-warmup.png) continue ;; esac
    cp "$screenshot" "$EVIDENCE/"
  done
  [ -s "$EVIDENCE/android-final.png" ] || fail "missing Android device final screenshot"
  "$ADB" -s "$ANDROID_DEVICE" logcat -d -v threadtime >"$EVIDENCE/android-logcat.txt"
else
  IOS_FINAL_SIGNAL_FILE="$EVIDENCE/ios-final-signal"
  IOS_FINAL_CAPTURE_DONE_FILE="$EVIDENCE/ios-final-capture-done"
  IOS_FINAL_SIGNAL_PORT=$((53000 + ($$ % 1000)))
  rm -f "$IOS_FINAL_SIGNAL_FILE" "$IOS_FINAL_CAPTURE_DONE_FILE"
  if xcrun simctl list devices booted | grep -q "$IOS_DEVICE"; then
    printf 'preexisting_ios=true\n' >"$EVIDENCE/ios-device-state.txt"
  else
    printf 'preexisting_ios=false\n' >"$EVIDENCE/ios-device-state.txt"
    IOS_LAUNCHED=1
  fi
  xcrun simctl boot "$IOS_DEVICE" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$IOS_DEVICE" -b
  capture_ios_settled_video_frame "$IOS_FINAL_SIGNAL_PORT" 1 "$EVIDENCE/ios-final" "$EVIDENCE/ios-final-capture-transport.txt" "$IOS_FINAL_CAPTURE_DONE_FILE" &
  IOS_FINAL_SIGNAL_PID=$!
  sleep 1
  kill -0 "$IOS_FINAL_SIGNAL_PID" 2>/dev/null ||
    fail "iOS final capture listener did not start"
  flutter drive --driver=integration_test/test_driver/integration_test.dart \
    --target=integration_test/functions_signed_in_happy_path_test.dart -d "$IOS_DEVICE" \
    --dart-define=ENV=dev --dart-define=USE_EMULATOR=true \
    --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 \
    --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1 \
    --dart-define=AUTH_EMULATOR_HOST=127.0.0.1 \
    --dart-define=FUNCTIONS_EMULATOR_HOST=127.0.0.1 \
    --dart-define=STORAGE_EMULATOR_HOST=127.0.0.1
  IOS_VISUAL_CAPTURE_PORT=$((55000 + ($$ % 1000)))
  rm -f "$EVIDENCE"/ios-matrix-in-app-*.png \
    "$EVIDENCE/ios-tablet-schedule-native.png" \
    "$EVIDENCE/ios-chinese-matrix-native.png" \
    "$EVIDENCE/ios-hangul-matrix-native.png"
  capture_ios_settled_video_frame "$IOS_VISUAL_CAPTURE_PORT" 3 "$EVIDENCE/ios-matrix-in-app" "$EVIDENCE/ios-matrix-capture-transport.txt" &
  IOS_VISUAL_CAPTURE_PID=$!
  flutter drive --driver=integration_test/test_driver/integration_test.dart \
    --target=integration_test/shopping_visual_state_matrix_test.dart -d "$IOS_DEVICE" \
    --dart-define=ENV=dev --dart-define=USE_EMULATOR=true \
    --dart-define=VISUAL_NATIVE_TABLET_CAPTURE=true \
    --dart-define=VISUAL_CAPTURE_SIGNAL_PORT="$IOS_VISUAL_CAPTURE_PORT"
  wait "$IOS_VISUAL_CAPTURE_PID" || fail "iOS in-app matrix capture failed"
  IOS_VISUAL_CAPTURE_PID=
  [ -s "$EVIDENCE/ios-matrix-in-app-1.png" ] || fail "missing iOS tablet in-app matrix capture"
  [ -s "$EVIDENCE/ios-matrix-in-app-2.png" ] || fail "missing iOS Chinese in-app matrix capture"
  [ -s "$EVIDENCE/ios-matrix-in-app-3.png" ] || fail "missing iOS Hangul in-app matrix capture"
  mv "$EVIDENCE/ios-matrix-in-app-1.png" "$EVIDENCE/ios-tablet-schedule-native.png"
  mv "$EVIDENCE/ios-matrix-in-app-2.png" "$EVIDENCE/ios-chinese-matrix-native.png"
  mv "$EVIDENCE/ios-matrix-in-app-3.png" "$EVIDENCE/ios-hangul-matrix-native.png"
  flutter drive --driver=integration_test/test_driver/integration_test.dart \
    --target=integration_test/shopping_mvp_emulator_test.dart -d "$IOS_DEVICE" \
    --dart-define=ENV=dev --dart-define=USE_EMULATOR=true \
    --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 \
    --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1 \
    --dart-define=AUTH_EMULATOR_HOST=127.0.0.1 \
    --dart-define=FUNCTIONS_EMULATOR_HOST=127.0.0.1 \
    --dart-define=STORAGE_EMULATOR_HOST=127.0.0.1 \
    --dart-define=QA_CANONICAL_DATE="$QA_CANONICAL_DATE" \
    --dart-define=FINAL_CAPTURE_SIGNAL_PORT="$IOS_FINAL_SIGNAL_PORT"
  wait "$IOS_FINAL_SIGNAL_PID" || fail "iOS final capture signal listener failed"
  IOS_FINAL_SIGNAL_PID=
  [ -s "$EVIDENCE/ios-final-1.png" ] || fail "missing iOS video-decoded final screenshot"
  mv "$EVIDENCE/ios-final-1.png" "$EVIDENCE/ios-final.png"
  [ -f "$IOS_FINAL_CAPTURE_DONE_FILE" ] || fail "iOS final capture completion receipt missing"
  rm -f "$IOS_FINAL_SIGNAL_FILE"
  rm -f "$IOS_FINAL_CAPTURE_DONE_FILE"
  for screenshot in "$SCREENSHOTS"/ios-*.png; do
    [ -f "$screenshot" ] || continue
    case "$screenshot" in *-warmup.png) continue ;; esac
    cp "$screenshot" "$EVIDENCE/"
  done
  [ -s "$EVIDENCE/ios-final.png" ] || fail "missing iOS device final screenshot"
  xcrun simctl spawn "$IOS_DEVICE" log show --style compact --last 15m \
    --predicate 'process == "Runner"' >"$EVIDENCE/ios-runner.log" || \
    printf '%s\n' 'iOS Runner log export unavailable after successful drive.' \
      >>"$EVIDENCE/ios-runner.log"
fi
