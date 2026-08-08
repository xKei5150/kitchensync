#!/usr/bin/env bash

set -euo pipefail
set +x
umask 077

usage() {
  printf 'Usage: %s <flutter-only|android-integration>\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

mode=$1

case "$mode" in
  flutter-only)
    required_secrets=(
      KITCHENSYNC_CI_FIREBASE_OPTIONS_DEV
      KITCHENSYNC_CI_FIREBASE_OPTIONS_PROD
    )
    ;;
  android-integration)
    required_secrets=(
      KITCHENSYNC_CI_FIREBASE_OPTIONS_DEV
      KITCHENSYNC_CI_FIREBASE_OPTIONS_PROD
      KITCHENSYNC_CI_GOOGLE_SERVICES_JSON_DEV
    )
    ;;
  *)
    printf 'Unknown mode: %s\n' "$mode" >&2
    usage
    exit 2
    ;;
esac

missing_secrets=()
for secret_name in "${required_secrets[@]}"; do
  if [[ -z "${!secret_name:-}" ]]; then
    missing_secrets+=("$secret_name")
  fi
done

if ((${#missing_secrets[@]} > 0)); then
  printf 'Missing required GitHub Actions secret(s):\n' >&2
  for secret_name in "${missing_secrets[@]}"; do
    printf '  %s\n' "$secret_name" >&2
  done
  exit 1
fi

write_secret() {
  local secret_name=$1
  local target=$2

  printf '%s' "${!secret_name}" > "$target"
}

write_secret KITCHENSYNC_CI_FIREBASE_OPTIONS_DEV lib/firebase_options_dev.dart
write_secret KITCHENSYNC_CI_FIREBASE_OPTIONS_PROD lib/firebase_options_prod.dart

if [[ "$mode" == android-integration ]]; then
  write_secret KITCHENSYNC_CI_GOOGLE_SERVICES_JSON_DEV android/app/google-services.json
fi
