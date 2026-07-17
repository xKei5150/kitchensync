#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
RUNNER="$ROOT/tools/run-shopping-planner-runtime-qa.sh"
SERVICE="$ROOT/services/shopping_allocation_planner"
SERVICE_TOOL="$SERVICE/.dart_tool"
BACKUP="$SERVICE/.dart_tool.clean-cache-test.$$"

cleanup() {
  status=$?
  trap - EXIT INT TERM
  rm -rf "$SERVICE_TOOL"
  if [ -d "$BACKUP" ]; then
    mv "$BACKUP" "$SERVICE_TOOL"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

[ -x "$RUNNER" ] || {
  printf '%s\n' 'missing planner runtime QA runner' >&2
  exit 1
}

if [ -d "$SERVICE_TOOL" ]; then
  mv "$SERVICE_TOOL" "$BACKUP"
fi

LOCAL_PLANNER_PORT=${LOCAL_PLANNER_PORT:-18081} "$RUNNER"

[ -f "$SERVICE_TOOL/package_config.json" ] || {
  printf '%s\n' 'planner runtime QA did not restore the clean service package config' >&2
  exit 1
}

printf '%s\n' 'PASS: planner runtime QA bootstraps and passes from a clean service cache'
