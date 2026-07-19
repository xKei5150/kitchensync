#!/usr/bin/env node

import {
  existsSync,
  readFileSync,
  writeFileSync,
} from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { spawnSync } from "node:child_process"
import {
  configuredIndexSignatures,
  removeFixture,
  rolloutEnv,
  rolloutFixture,
} from "./readiness-test-support.mjs"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const node = process.execPath

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function run(command, args, options = {}) {
  return spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
    env: { ...process.env, ...options.env },
  })
}

const requiredFunctions = [
  "shoppingSmoke",
  "startPremiumTrial",
  "removeHouseholdMember",
  "transferHouseholdAdmin",
  "completeShoppingList",
  "cancelShoppingList",
  "deleteShoppingList",
  "planShoppingAllocation",
  "mutateShoppingListItem",
]

function assertReadinessBlocks(extra, label) {
  const fixture = rolloutFixture(repoRoot)
  try {
    const result = run("sh", [resolve(fixture.root, "tools/firebase-gates/rollout-dev.sh")], {
      env: rolloutEnv(fixture, extra),
    })
    assert(result.status !== 0, `${label} unexpectedly succeeded`)
    const log = readFileSync(fixture.log, "utf8")
    assert(!log.includes("smoke:before-rules"), `${label} reached client smoke:\n${log}`)
    assert(!log.includes("--only firestore:rules"), `${label} deployed rules:\n${log}`)
  } finally {
    removeFixture(fixture)
  }
}

function testReadinessRejectsIncompleteDeployment() {
  for (const name of requiredFunctions) {
    assertReadinessBlocks({ MISSING_FUNCTION: name }, `missing function ${name}`)
  }
  for (const [field, value] of [
    ["region", "europe-west1"],
    ["platform", "gcfv1"],
    ["runtime", "nodejs20"],
    ["state", "FAILED"],
  ]) {
    assertReadinessBlocks(
      { FUNCTION_VARIANT_TARGET: "shoppingSmoke", FUNCTION_VARIANT_FIELD: field, FUNCTION_VARIANT_VALUE: value },
      `wrong function ${field}`,
    )
  }
  for (const signature of configuredIndexSignatures(repoRoot)) {
    assertReadinessBlocks({ MISSING_INDEX: signature }, `missing index ${signature}`)
  }
  assertReadinessBlocks({ MALFORMED_FUNCTIONS: "1" }, "malformed function output")
  assertReadinessBlocks({ FUNCTIONS_STATUS: "error" }, "unsuccessful function output")
  assertReadinessBlocks({ DUPLICATE_FUNCTION: "shoppingSmoke" }, "duplicate function endpoint")
  assertReadinessBlocks({ MALFORMED_INDEXES: "1" }, "malformed index output")
  for (const variant of ["suffix-garbage", "density-garbage", "reordered", "extra"]) {
    assertReadinessBlocks({ INDEX_OUTPUT_VARIANT: variant }, `invalid index output ${variant}`)
  }
}

function testVerifierContract() {
  const result = run(node, ["tools/verify-firebase-gates.mjs"])
  assert(result.status === 0, `verifier exited ${result.status}: ${result.stderr}`)
  const output = `${result.stdout}\n${result.stderr}`
  for (const label of [
    "PASS exact Todo 9 composite indexes",
    "PASS CI uses Node 22 and Functions gates",
    "PASS Make exposes reproducible Firebase gates",
    "PASS rollout script is fail closed",
  ]) {
    assert(output.includes(label), `verifier did not prove: ${label}`)
  }
}

function testRolloutOrdering() {
  const fixture = rolloutFixture(repoRoot)
  try {
    const result = run("sh", [resolve(fixture.root, "tools/firebase-gates/rollout-dev.sh")], {
      env: rolloutEnv(fixture, { INDEX_OUTPUT_VARIANT: "density-two" }),
    })
    assert(
      result.status === 0,
      `rollout rejected real Firebase index formatting (exit ${result.status}): ${result.stderr}`,
    )
    const log = readFileSync(fixture.log, "utf8")
    const functionsDeploy = log.indexOf("--only functions,firestore:indexes")
    const beforeSmoke = log.indexOf("smoke:before-rules")
    const rulesDeploy = log.indexOf("--only firestore:rules")
    const afterSmoke = log.indexOf("smoke:after-rules")
    assert(
      functionsDeploy >= 0 && functionsDeploy < beforeSmoke && beforeSmoke < rulesDeploy && rulesDeploy < afterSmoke,
      `unsafe rollout order:\n${log}`,
    )
  } finally {
    removeFixture(fixture)
  }
}

function testBackendDeployIsNoninteractive() {
  const fixture = rolloutFixture(repoRoot)
  try {
    const result = run("sh", [resolve(fixture.root, "tools/firebase-gates/rollout-dev.sh")], {
      env: rolloutEnv(fixture, { INDEX_OUTPUT_VARIANT: "density-one" }),
    })
    assert(result.status === 0, `successful rollout fixture exited ${result.status}: ${result.stderr}`)
    const invocations = readFileSync(fixture.log, "utf8").trim().split("\n")
    assert(
      invocations.includes(
        "deploy --project kitchensync-dev-da503 --only functions,firestore:indexes --force",
      ),
      `backend deploy must use --force for noninteractive cleanup-policy creation:\n${invocations.join("\n")}`,
    )
    assert(
      invocations.includes("deploy --project kitchensync-dev-da503 --only firestore:rules"),
      `rules deploy arguments changed unexpectedly:\n${invocations.join("\n")}`,
    )
  } finally {
    removeFixture(fixture)
  }
}

function testGeneratedStubsArePosix() {
  const fixture = rolloutFixture(repoRoot)
  try {
    for (const stub of [fixture.firebase, fixture.smoke]) {
      const syntax = run("dash", ["-n", stub])
      assert(syntax.status === 0, `generated stub is not POSIX sh: ${syntax.stderr}`)
    }
    const execution = run("dash", [fixture.firebase, "login:list", "--json"], {
      env: { FIREBASE_STUB_LOG: fixture.log },
    })
    assert(execution.status === 0, `generated Firebase stub failed under dash: ${execution.stderr}`)
  } finally {
    removeFixture(fixture)
  }
}

function testSmokeFailureBlocksRules() {
  const fixture = rolloutFixture(repoRoot)
  try {
    const result = run("sh", [resolve(fixture.root, "tools/firebase-gates/rollout-dev.sh")], {
      env: rolloutEnv(fixture, { FAIL_SMOKE_PHASE: "before-rules" }),
    })
    assert(result.status !== 0, "pre-rules semantic smoke failure unexpectedly succeeded")
    const log = readFileSync(fixture.log, "utf8")
    assert(!log.includes("--only firestore:rules"), `rules deployed after failed smoke:\n${log}`)
  } finally {
    removeFixture(fixture)
  }
}

function testWrongAliasBlocksDeployment() {
  const fixture = rolloutFixture(repoRoot)
  try {
    writeFileSync(resolve(fixture.root, ".firebaserc"), JSON.stringify({ projects: { dev: "wrong-project" } }))
    const result = run("sh", [resolve(fixture.root, "tools/firebase-gates/rollout-dev.sh")], {
      env: rolloutEnv(fixture),
    })
    assert(result.status !== 0, "wrong project alias unexpectedly succeeded")
    const log = existsSync(fixture.log) ? readFileSync(fixture.log, "utf8") : ""
    assert(!log.includes(" deploy "), `deployment ran with wrong alias:\n${log}`)
  } finally {
    removeFixture(fixture)
  }
}

function testSemanticSmokeRegistersCleanup() {
  const smoke = readFileSync(resolve(repoRoot, "tools/firebase-gates/smoke-dev.mjs"), "utf8")
  assert(smoke.includes("function cleanupFixture"), "semantic smoke is missing fixture cleanup")
  assert(smoke.includes("shoppingCommandReceipts"), "semantic smoke does not clean command receipts")
  assert(smoke.includes("cleanupFixture(householdId"), "semantic smoke does not run cleanup on failure")
}

function testAndroidCallableGateIsDevicePinned() {
  const gate = readFileSync(
    resolve(repoRoot, "tools/firebase-gates/run-flutter-callable-android.sh"),
    "utf8",
  )
  assert(gate.includes("pass an explicit Android device ID"), "Android gate does not fail closed without a device")
  assert(gate.includes("flutter drive --device-id=$DEVICE_ID"), "Android gate does not pin flutter drive")
  assert(gate.includes("FIREBASE_EMULATOR_HOST=10.0.2.2"), "Android gate does not use the host bridge")
  assert(!gate.includes("flutter test integration_test"), "Android gate can silently select another platform")
}

function testDebugBuildDisablesProductionTelemetry() {
  const manifest = readFileSync(resolve(repoRoot, "android/app/src/debug/AndroidManifest.xml"), "utf8")
  for (const setting of [
    "firebase_sessions_enabled",
    "firebase_crashlytics_collection_enabled",
    "firebase_analytics_collection_enabled",
  ]) {
    assert(
      manifest.includes(`android:name="${setting}"`) && manifest.includes('android:value="false"'),
      `debug Android manifest does not disable ${setting}`,
    )
  }
}

const tests = [
  ["verifier contract", testVerifierContract],
  ["rollout ordering", testRolloutOrdering],
  ["backend deploy is noninteractive", testBackendDeployIsNoninteractive],
  ["generated stubs are POSIX sh", testGeneratedStubsArePosix],
  ["readiness rejects incomplete deployment", testReadinessRejectsIncompleteDeployment],
  ["smoke failure blocks rules", testSmokeFailureBlocksRules],
  ["wrong alias blocks deployment", testWrongAliasBlocksDeployment],
  ["semantic smoke cleanup", testSemanticSmokeRegistersCleanup],
  ["device-pinned Android callable gate", testAndroidCallableGateIsDevicePinned],
  ["debug build disables production telemetry", testDebugBuildDisablesProductionTelemetry],
]

let failures = 0
for (const [name, test] of tests) {
  try {
    test()
    console.log(`PASS ${name}`)
  } catch (error) {
    failures += 1
    console.error(`FAIL ${name}: ${error instanceof Error ? error.message : String(error)}`)
  }
}

if (failures > 0) process.exitCode = 1
