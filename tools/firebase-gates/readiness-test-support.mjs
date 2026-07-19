import { chmodSync, cpSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { resolve } from "node:path"

function executable(path, source) {
  writeFileSync(path, source)
  chmodSync(path, 0o755)
}

function firebaseStub(path) {
  executable(path, `#!/bin/sh
set -eu
printf '%s\\n' "$*" >> "$FIREBASE_STUB_LOG"
case "$*" in
  "login:list --json")
    printf '%s\\n' '{"status":"success","result":[{"user":{"email":"redacted@example.test"}}]}'
    ;;
  "use --json")
    printf '%s\\n' '{"status":"success","result":"kitchensync-dev-da503"}'
    ;;
  *"functions:list"*)
    if [ "\${MALFORMED_FUNCTIONS:-}" = "1" ]; then
      printf '%s\\n' 'not-json'
    else
      jq -nc --arg missing "\${MISSING_FUNCTION:-}" \
        --arg target "\${FUNCTION_VARIANT_TARGET:-}" \
        --arg field "\${FUNCTION_VARIANT_FIELD:-}" \
        --arg value "\${FUNCTION_VARIANT_VALUE:-}" \
        --arg status "\${FUNCTIONS_STATUS:-success}" \
        --arg duplicate "\${DUPLICATE_FUNCTION:-}" '
          ["shoppingSmoke", "startPremiumTrial", "removeHouseholdMember",
            "transferHouseholdAdmin", "completeShoppingList",
            "cancelShoppingList", "deleteShoppingList",
            "planShoppingAllocation", "mutateShoppingListItem"] |
          map(select(. != $missing) | {
            id: ., region: "us-central1", platform: "gcfv2",
            runtime: "nodejs22", state: "ACTIVE"
          } | if .id == $target then .[$field] = $value else . end) as $functions |
          {status:$status, result: ($functions +
            (if $duplicate == "" then [] else [$functions[] | select(.id == $duplicate)] end))}'
    fi
    ;;
  *"firestore:indexes"*)
    if [ "\${MALFORMED_INDEXES:-}" = "1" ]; then
      printf '%s\\n' 'not-an-index-list'
    else
      jq -r --arg missing "\${MISSING_INDEX:-}" \
        --arg variant "\${INDEX_OUTPUT_VARIANT:-}" '
        .indexes[] | "\\(.collectionGroup)|" +
          ([.fields[] | "\\(.fieldPath):\\(.order // .arrayConfig)"] | join(",")) |
          select(. != $missing) | split("|") as $parts |
          ($parts[1] | split(",") | map(split(":") | "(\\(.[0]),\\(.[1]))")) as $fields |
          (if $variant == "reordered" then ($fields | reverse)
            elif $variant == "extra" then $fields + ["(unexpected,ASCENDING)"]
            else $fields end) as $rendered |
          "[READY] (\\($parts[0])) -- " + ($rendered | join(" ")) +
            (if $variant == "density-one" then " -- Density:SPARSE_ALL"
              elif $variant == "density-two" then "  -- Density:SPARSE_ALL"
              elif $variant == "suffix-garbage" then " -- garbage"
              elif $variant == "density-garbage" then " -- Density:SPARSE_ALL garbage"
              else "" end)' \
        firestore.indexes.json
    fi
    ;;
  *"deploy"*) printf '%s\\n' 'deploy complete' ;;
  *) printf '%s\\n' "unexpected firebase invocation: $*" >&2; exit 64 ;;
esac
`)
}

function smokeStub(path) {
  executable(path, `#!/bin/sh
set -eu
printf 'smoke:%s\\n' "$1" >> "$FIREBASE_STUB_LOG"
if [ "\${FAIL_SMOKE_PHASE:-}" = "$1" ]; then exit 42; fi
`)
}

export function rolloutFixture(repoRoot) {
  const root = mkdtempSync(resolve(tmpdir(), "kitchensync-firebase-gates-"))
  mkdirSync(resolve(root, "tools/firebase-gates"), { recursive: true })
  cpSync(resolve(repoRoot, "tools/firebase-gates/rollout-dev.sh"), resolve(root, "tools/firebase-gates/rollout-dev.sh"))
  cpSync(resolve(repoRoot, "firestore.indexes.json"), resolve(root, "firestore.indexes.json"))
  writeFileSync(resolve(root, ".firebaserc"), JSON.stringify({
    projects: { default: "kitchensync-dev-da503", dev: "kitchensync-dev-da503" },
  }))
  const fixture = {
    root,
    log: resolve(root, "firebase.log"),
    firebase: resolve(root, "firebase stub"),
    smoke: resolve(root, "semantic-smoke"),
  }
  firebaseStub(fixture.firebase)
  smokeStub(fixture.smoke)
  return fixture
}

export function rolloutEnv(fixture, extra = {}) {
  return {
    FIREBASE_GATE_REPO_ROOT: fixture.root,
    FIREBASE_BIN: fixture.firebase,
    FIREBASE_STUB_LOG: fixture.log,
    FIREBASE_SEMANTIC_SMOKE_COMMAND: fixture.smoke,
    FIREBASE_GATE_WAIT_ATTEMPTS: "1",
    FIREBASE_GATE_WAIT_SECONDS: "0",
    ...extra,
  }
}

export function configuredIndexSignatures(repoRoot) {
  const config = JSON.parse(readFileSync(resolve(repoRoot, "firestore.indexes.json"), "utf8"))
  return config.indexes.map(
    (index) => `${index.collectionGroup}|${index.fields.map((field) => `${field.fieldPath}:${field.order ?? field.arrayConfig}`).join(",")}`,
  )
}

export function removeFixture(fixture) {
  rmSync(fixture.root, { recursive: true, force: true })
}
