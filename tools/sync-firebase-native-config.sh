#!/usr/bin/env bash
# Download the ignored native Firebase configuration for the selected runtime.
# Run immediately before an Android/iOS build so a prod artifact cannot retain
# the developer's dev google-services.json or GoogleService-Info.plist.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <dev|prod>\n' "$0" >&2
  exit 2
fi

case "$1" in
  dev)
    project='kitchensync-dev-da503'
    android_app='1:733234753301:android:d390bfa8a5323514f7c31c'
    ios_app='1:733234753301:ios:1f199b96cc47aca1f7c31c'
    ;;
  prod)
    project='kitchensync-prod-8d6fd'
    android_app='1:310529205684:android:070ee629e4a4a4c0763ee1'
    ios_app='1:310529205684:ios:757151f2ae7fa03c763ee1'
    ;;
  *)
    printf 'Unknown environment %q; expected dev or prod.\n' "$1" >&2
    exit 2
    ;;
esac

android_target='android/app/google-services.json'
ios_target='ios/Runner/GoogleService-Info.plist'
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/kitchensync-native-config.XXXXXX")"
android_tmp="$tmp_dir/google-services.json"
ios_tmp="$tmp_dir/GoogleService-Info.plist"
trap 'rm -rf "$tmp_dir"' EXIT

firebase --project "$project" apps:sdkconfig ANDROID "$android_app" --out "$android_tmp"
firebase --project "$project" apps:sdkconfig IOS "$ios_app" --out "$ios_tmp"
mv "$android_tmp" "$android_target"
mv "$ios_tmp" "$ios_target"
trap - EXIT
rmdir "$tmp_dir"

printf 'Synced native Firebase configuration for %s (%s).\n' "$1" "$project"
