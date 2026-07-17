#!/usr/bin/env node

import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const scriptRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const repoRoot = resolve(process.env.FIREBASE_GATE_REPO_ROOT ?? scriptRoot)
const devProject = "kitchensync-dev-da503"
let failures = 0

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function check(label, assertion) {
  try {
    assertion()
    console.log(`PASS ${label}`)
  } catch (error) {
    failures += 1
    const message = error instanceof Error ? error.message : String(error)
    console.error(`FAIL ${label}: ${message}`)
  }
}

function source(relativePath) {
  return readFileSync(resolve(repoRoot, relativePath), "utf8")
}

function json(relativePath) {
  try {
    return JSON.parse(source(relativePath))
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(`${relativePath} is not valid JSON (${message})`)
  }
}

function exactIndex(collectionGroup, fields) {
  return {
    collectionGroup,
    queryScope: "COLLECTION",
    fields: fields.map(([fieldPath, order]) => ({ fieldPath, order })),
  }
}

function hasExactIndex(indexes, expected) {
  return indexes.some((candidate) => JSON.stringify(candidate) === JSON.stringify(expected))
}

function requireFirebaseConfig(config, relativePath) {
  assert(config.firestore?.rules !== undefined, `${relativePath} must configure Firestore rules`)
  assert(
    config.firestore?.indexes === "firestore.indexes.json",
    `${relativePath} must use firestore.indexes.json`,
  )
  assert(config.functions?.source === "functions", `${relativePath} functions.source must be functions`)
  const ports = { auth: 9099, firestore: 8080, functions: 5001, storage: 9199 }
  for (const [emulator, port] of Object.entries(ports)) {
    assert(
      config.emulators?.[emulator]?.port === port,
      `${relativePath} ${emulator} emulator port must be ${port}`,
    )
  }
}

check("Firebase JSON and aliases", () => {
  const firebaseConfig = json("firebase.json")
  const firebaseDevConfig = json("firebase.dev.json")
  const aliases = json(".firebaserc")
  requireFirebaseConfig(firebaseConfig, "firebase.json")
  requireFirebaseConfig(firebaseDevConfig, "firebase.dev.json")
  assert(aliases.projects?.default === devProject, ".firebaserc default must be the dev project")
  assert(aliases.projects?.dev === devProject, ".firebaserc dev must be the dev project")
})

check("exact Todo 9 composite indexes", () => {
  const indexesFile = json("firestore.indexes.json")
  assert(Array.isArray(indexesFile.indexes), "firestore.indexes.json indexes must be an array")
  const expected = [
    exactIndex("mealScheduleEntries", [
      ["date", "ASCENDING"],
      ["mealSlot", "ASCENDING"],
    ]),
    exactIndex("daySettings", [
      ["isActive", "ASCENDING"],
      ["dateRangeStart", "ASCENDING"],
    ]),
    exactIndex("shoppingLists", [
      ["status", "ASCENDING"],
      ["shoppingDate", "ASCENDING"],
    ]),
    exactIndex("shoppingLists", [
      ["type", "ASCENDING"],
      ["status", "ASCENDING"],
    ]),
    exactIndex("shoppingLists", [
      ["status", "ASCENDING"],
      ["updatedAt", "DESCENDING"],
    ]),
  ]
  const missing = expected.filter((index) => !hasExactIndex(indexesFile.indexes, index))
  assert(missing.length === 0, `missing exact indexes: ${JSON.stringify(missing)}`)
  const history = expected.at(-1)
  assert(
    history !== undefined && !history.fields.some(({ fieldPath }) => fieldPath === "__name__"),
    "history index must rely on Firestore's implicit document-name order",
  )
  const explicitName = indexesFile.indexes.some(
    (index) =>
      index.collectionGroup === "shoppingLists" &&
      index.fields?.some(({ fieldPath }) => fieldPath === "__name__"),
  )
  assert(!explicitName, "shoppingLists indexes must not declare __name__ explicitly")
})

check("required Functions use Node 22 and us-central1", () => {
  const packageFile = json("functions/package.json")
  assert(packageFile.engines?.node === "22", "functions/package.json engines.node must be 22")
  const functionsSource = source("functions/src/index.ts")
  const required = [
    "shoppingSmoke",
    "completeShoppingList",
    "deleteShoppingList",
    "planShoppingAllocation",
    "mutateShoppingListItem",
  ]
  const exports = [
    ...functionsSource.matchAll(
      /export\s+const\s+(\w+)\s*=\s*onCall\s*\(\s*\{\s*region:\s*["']([^"']+)["']/g,
    ),
  ].map((match) => ({ name: match[1], region: match[2] }))
  assert(exports.length === required.length, "Functions callable exports must match the required set")
  assert(
    new Set(exports.map((entry) => entry.name)).size === exports.length,
    "Functions callable exports must not contain duplicate names",
  )
  for (const name of required) {
    const callable = exports.find((entry) => entry.name === name)
    assert(callable !== undefined, `missing callable export ${name}`)
    assert(callable.region === "us-central1", `${name} must use us-central1`)
  }
})

check("CI uses Node 22 and Functions gates", () => {
  const ci = source(".github/workflows/ci.yml")
  const nodeVersions = [...ci.matchAll(/node-version:\s*['"]?(\d+)['"]?/g)].map((match) => match[1])
  assert(nodeVersions.length > 0, "CI must configure Node")
  assert(nodeVersions.every((version) => version === "22"), "every CI Node version must be 22")
  for (const command of [
    "npm --prefix functions ci",
    "npm --prefix functions run lint",
    "npm --prefix functions run build",
    "npm --prefix functions test",
    "npm --prefix functions run test:emulator",
  ]) {
    assert(ci.includes(command), `CI is missing ${command}`)
  }
  assert(/--only[^\n]*(functions)/.test(ci), "CI emulator gate must include Functions")
  assert(
    ci.includes("reactivecircus/android-emulator-runner") &&
      ci.includes("tools/firebase-gates/run-flutter-callable-android.sh"),
    "CI must run the signed-in callable gate on a pinned Android emulator",
  )
})

check("Make exposes reproducible Firebase gates", () => {
  const makefile = source("Makefile")
  for (const target of [
    "emulators-full:",
    "rules-test:",
    "functions-gate:",
    "integration-gate:",
    "firebase-gates:",
    "firebase-indexes-list:",
    "firebase-deploy-dev-backend:",
    "firebase-rollout-dev:",
  ]) {
    assert(makefile.includes(target), `Makefile is missing ${target}`)
  }
  assert(
    makefile.includes("--project kitchensync-dev-da503") &&
      makefile.includes("tools/firebase-gates/firebase.sh"),
    "Make Firebase commands must pin the dev project and Firebase CLI version",
  )
  assert(
    makefile.includes('tools/firebase-gates/run-flutter-callable-android.sh "$(ANDROID_DEVICE_ID)"'),
    "Make integration gate must require an explicit Android device",
  )
  assert(!/firebase[^\n]*deploy[^\n]*(prod|kitchensync-prod)/.test(makefile), "Makefile must not deploy prod")
})

check("rollout script is fail closed", () => {
  const rollout = source("tools/firebase-gates/rollout-dev.sh")
  const backend = rollout.indexOf("functions,firestore:indexes")
  const beforeSmoke = rollout.indexOf("before-rules")
  const rules = rollout.indexOf("firestore:rules")
  const afterSmoke = rollout.indexOf("after-rules")
  assert(rollout.includes("set -eu"), "rollout must stop on errors")
  assert(rollout.includes(devProject), "rollout must pin the dev project")
  assert(
    backend >= 0 && backend < beforeSmoke && beforeSmoke < rules && rules < afterSmoke,
    "rollout order must be backend, pre-rules smoke, rules, post-rules smoke",
  )
  assert(rollout.includes("login:list --json"), "rollout must verify credentials")
  assert(rollout.includes("functions:list"), "rollout must verify deployed Functions")
  assert(rollout.includes("firestore:indexes"), "rollout must verify index readiness")
  assert(
    source("tools/firebase-gates/firebase.sh").includes("firebase-tools@15.18.0"),
    "Firebase CLI wrapper must pin firebase-tools@15.18.0",
  )
})

if (failures > 0) {
  console.error(`Firebase gate assertions failed: ${failures}`)
  process.exitCode = 1
} else {
  console.log("Firebase Todo 9 gate assertions passed")
}
