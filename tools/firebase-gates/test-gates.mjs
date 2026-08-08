#!/usr/bin/env node

import {
  cpSync,
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs"
import { tmpdir } from "node:os"
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
  "createJointHouseholdWithTrialTransfer",
  "accountDeletionPreflight",
  "requestAccountDeletion",
  "leaveJointHousehold",
  "transferJointHouseholdOwnership",
  "removeHouseholdMember",
  "transferHouseholdAdmin",
  "issueHouseholdInvite",
  "redeemHouseholdInvite",
  "revokeHouseholdInvite",
  "completeShoppingList",
  "cancelShoppingList",
  "deleteShoppingList",
  "planShoppingAllocation",
  "mutateShoppingListItem",
  "adminHealthGet",
  "adminUserGet",
  "adminHouseholdGet",
  "adminEntitlementGet",
  "cleanupTerminalInviteMetadataDaily",
  "processAccountDeletionRequestsEveryFifteenMinutes",
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
    assert(!log.includes("--only firestore:rules,storage:rules"), `${label} deployed rules:\n${log}`)
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
    "PASS Firebase JSON, aliases, and admin Hosting target prerequisite",
    "PASS exact Todo 9 composite indexes",
    "PASS account-deletion worker collection-group inventory indexes",
    "PASS current Functions exports use Node 22 and us-central1",
    "PASS admin web Hosting boundary",
    "PASS CI uses Node 22 and Functions gates",
    "PASS Make exposes reproducible Firebase gates",
    "PASS rollout script is fail closed",
  ]) {
    assert(output.includes(label), `verifier did not prove: ${label}`)
  }
}

function verifierFixture() {
  const root = mkdtempSync(resolve(tmpdir(), "kitchensync-verifier-contract-"))
  const requiredPaths = [
    ".firebaserc",
    "firebase.json",
    "firebase.dev.json",
    "firebase.prod.json",
    "firestore.indexes.json",
    "functions/package.json",
    "functions/src/index.ts",
    "functions/src/callableSecurity.ts",
    "functions/src/accountDeletionWorker.ts",
    "functions/src/admin/callables.ts",
    ".github/workflows/ci.yml",
    "Makefile",
    "tools/firebase-gates/rollout-dev.sh",
    "tools/firebase-gates/firebase.sh",
    "apps/admin-web/package.json",
    "apps/admin-web/src",
  ]
  for (const path of requiredPaths) {
    const destination = resolve(root, path)
    mkdirSync(dirname(destination), { recursive: true })
    cpSync(resolve(repoRoot, path), destination, { recursive: true })
  }
  return root
}

function assertVerifierRejects(mutator, label, expectedFailure) {
  const fixture = verifierFixture()
  try {
    mutator(fixture)
    const result = run(node, ["tools/verify-firebase-gates.mjs"], {
      env: { FIREBASE_GATE_REPO_ROOT: fixture },
    })
    assert(result.status !== 0, `${label} unexpectedly passed the verifier`)
    assert(
      `${result.stdout}\n${result.stderr}`.includes(expectedFailure),
      `${label} did not fail for the expected contract: ${result.stderr}`,
    )
  } finally {
    rmSync(fixture, { recursive: true, force: true })
  }
}

function testVerifierRejectsStaleCallableAndHostingContracts() {
  assertVerifierRejects(
    (fixture) => {
      const index = resolve(fixture, "functions/src/index.ts")
      writeFileSync(
        index,
        readFileSync(index, "utf8").replace(
          /export\s*\{[\s\S]*?\}\s*from\s*["']\.\/admin\/callables\.js["']\s*;?/,
          "",
        ),
      )
    },
    "legacy callable set without admin exports",
    "Functions human-callable exports must match exactly",
  )
  assertVerifierRejects(
    (fixture) => {
      const index = resolve(fixture, "functions/src/index.ts")
      writeFileSync(
        index,
        readFileSync(index, "utf8").replace("export const issueHouseholdInvite", "const issueHouseholdInvite"),
      )
    },
    "missing invite callable",
    "Functions human-callable exports must match exactly",
  )
  assertVerifierRejects(
    (fixture) => {
      const configPath = resolve(fixture, "firebase.dev.json")
      const config = JSON.parse(readFileSync(configPath, "utf8"))
      config.hosting.rewrites = []
      writeFileSync(configPath, JSON.stringify(config))
    },
    "malformed admin Hosting configuration",
    "firebase.dev.json Hosting must configure the SPA rewrite to /index.html",
  )
  assertVerifierRejects(
    (fixture) => rmSync(resolve(fixture, "firebase.prod.json")),
    "missing production Firebase configuration",
    "firebase.prod.json is not valid JSON",
  )
  assertVerifierRejects(
    (fixture) => {
      const configPath = resolve(fixture, "firebase.dev.json")
      const config = JSON.parse(readFileSync(configPath, "utf8"))
      const csp = config.hosting.headers[0].headers.find(
        (header) => header.key === "Content-Security-Policy",
      )
      csp.value += " https://us-central1-kitchensync-prod-8d6fd.cloudfunctions.net"
      writeFileSync(configPath, JSON.stringify(config))
    },
    "cross-environment CSP origin leakage",
    "firebase.dev.json Hosting CSP must not include prod origins",
  )
  assertVerifierRejects(
    (fixture) => {
      const configPath = resolve(fixture, "firebase.prod.json")
      const config = JSON.parse(readFileSync(configPath, "utf8"))
      config.hosting.headers[0].headers = config.hosting.headers[0].headers.filter(
        (header) => header.key !== "X-Content-Type-Options",
      )
      writeFileSync(configPath, JSON.stringify(config))
    },
    "malformed production Hosting headers",
    "firebase.prod.json Hosting must set X-Content-Type-Options",
  )
}

function testWorkerCollectionGroupIndexGateRejectsOmissions() {
  assertVerifierRejects(
    (fixture) => {
      const indexesPath = resolve(fixture, "firestore.indexes.json")
      const indexes = JSON.parse(readFileSync(indexesPath, "utf8"))
      indexes.indexes = indexes.indexes.filter(
        (index) =>
          !(
            index.collectionGroup === "comments" &&
            index.queryScope === "COLLECTION_GROUP" &&
            index.fields?.some((field) => field.fieldPath === "authorUserId")
          ),
      )
      writeFileSync(indexesPath, JSON.stringify(indexes))
    },
    "missing worker collection-group inventory index",
    "missing collection-group index for comments.authorUserId",
  )
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
    const rulesDeploy = log.indexOf("--only firestore:rules,storage:rules")
    const afterSmoke = log.indexOf("smoke:after-rules")
    assert(
      functionsDeploy >= 0 && functionsDeploy < beforeSmoke && beforeSmoke < rulesDeploy && rulesDeploy < afterSmoke,
      `unsafe rollout order:\n${log}`,
    )
    const rulesDeployments = log
      .split("\n")
      .filter((line) => line.startsWith("deploy ") && line.includes("rules"))
    assert(
      rulesDeployments.length === 1 &&
        rulesDeployments[0] ===
          "deploy --project kitchensync-dev-da503 --only firestore:rules,storage:rules",
      `rules must deploy together without a weaker separate path:\n${log}`,
    )
  } finally {
    removeFixture(fixture)
  }
}

function testRulesDeploymentIncludesStorageAndNoWeakerPath() {
  const rollout = readFileSync(resolve(repoRoot, "tools/firebase-gates/rollout-dev.sh"), "utf8")
  assert(
    rollout.includes("--only firestore:rules,storage:rules"),
    "rollout must deploy Firestore Rules and Storage Rules together",
  )
  assert(
    !/--only\s+firestore:rules(?:[\s"']|$)/.test(rollout),
    "rollout must not retain a Firestore-only Rules deployment path",
  )
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
      invocations.includes("deploy --project kitchensync-dev-da503 --only firestore:rules,storage:rules"),
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
    assert(!log.includes("--only firestore:rules,storage:rules"), `rules deployed after failed smoke:\n${log}`)
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

function testSemanticSmokeRequiresRealAttestation() {
  const smoke = readFileSync(resolve(repoRoot, "tools/firebase-gates/smoke-dev.mjs"), "utf8")
  assert(
    smoke.includes("FIREBASE_SEMANTIC_SMOKE_ID_TOKEN"),
    "semantic smoke does not require a real Firebase identity token",
  )
  assert(
    smoke.includes("FIREBASE_SEMANTIC_SMOKE_APP_CHECK_TOKEN"),
    "semantic smoke does not require an App Check token",
  )
  assert(smoke.includes("x-firebase-appcheck"), "semantic smoke omits the App Check header")
  assert(smoke.includes("assertNonAnonymousIdentity"), "semantic smoke permits anonymous identities")
  assert(smoke.includes("shoppingSmoke"), "semantic smoke does not verify the deployed callable")
  assert(smoke.includes("direct purchase write was not denied"), "semantic smoke does not verify rules")
  assert(
    !smoke.includes("signUp?key="),
    "semantic smoke still creates an anonymous Firebase identity",
  )
  assert(!smoke.includes("upsertShoppingList"), "semantic smoke calls retired shopping write APIs")
}

function testAndroidCallableGateIsDevicePinned() {
  const gate = readFileSync(
    resolve(repoRoot, "tools/firebase-gates/run-flutter-callable-android.sh"),
    "utf8",
  )
  assert(gate.includes("pass an explicit Android device ID"), "Android gate does not fail closed without a device")
  assert(gate.includes("flutter drive --device-id=$DEVICE_ID"), "Android gate does not pin flutter drive")
  assert(gate.includes("FIREBASE_EMULATOR_HOST=10.0.2.2"), "Android gate does not use the host bridge")
  assert(
    !gate.includes("KS_ENABLE_TEST_ANONYMOUS_BOOTSTRAP"),
    "Android gate must not depend on an anonymous test identity",
  )
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
  ["verifier rejects stale callable and Hosting contracts", testVerifierRejectsStaleCallableAndHostingContracts],
  ["worker collection-group index gate rejects omissions", testWorkerCollectionGroupIndexGateRejectsOmissions],
  ["rollout ordering", testRolloutOrdering],
  ["rules deployment includes Storage Rules", testRulesDeploymentIncludesStorageAndNoWeakerPath],
  ["backend deploy is noninteractive", testBackendDeployIsNoninteractive],
  ["generated stubs are POSIX sh", testGeneratedStubsArePosix],
  ["readiness rejects incomplete deployment", testReadinessRejectsIncompleteDeployment],
  ["smoke failure blocks rules", testSmokeFailureBlocksRules],
  ["wrong alias blocks deployment", testWrongAliasBlocksDeployment],
  ["semantic smoke requires real attestation", testSemanticSmokeRequiresRealAttestation],
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
