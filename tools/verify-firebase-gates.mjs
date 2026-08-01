#!/usr/bin/env node

import { readFileSync, readdirSync } from "node:fs"
import { dirname, extname, relative, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const scriptRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const repoRoot = resolve(process.env.FIREBASE_GATE_REPO_ROOT ?? scriptRoot)
const devProject = "kitchensync-dev-da503"
const expectedHumanCallableNames = [
  "shoppingSmoke",
  "startPremiumTrial",
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
]
const expectedScheduledWorkerNames = ["cleanupTerminalInviteMetadataDaily"]
const hostingEnvironments = {
  dev: {
    functionsOrigin: "https://us-central1-kitchensync-dev-da503.cloudfunctions.net",
    authIframeOrigin: "https://kitchensync-dev-da503.firebaseapp.com",
  },
  prod: {
    functionsOrigin: "https://us-central1-kitchensync-prod-8d6fd.cloudfunctions.net",
    authIframeOrigin: "https://kitchensync-prod-8d6fd.firebaseapp.com",
  },
}
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

function sourceFiles(relativeDirectory) {
  const directory = resolve(repoRoot, relativeDirectory)
  const files = []
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const entryPath = resolve(directory, entry.name)
    if (entry.isDirectory()) {
      files.push(...sourceFiles(relative(repoRoot, entryPath)))
    } else if ([".js", ".jsx", ".ts", ".tsx"].includes(extname(entry.name))) {
      files.push(relative(repoRoot, entryPath))
    }
  }
  return files
}

/**
 * Collect public `onCall` exports from an entry module and its local re-exports.
 * This deliberately detects the export declaration rather than the options
 * expression so shared options objects and inline object spreads are both valid.
 */
function callableExports(relativePath, visited = new Set()) {
  if (visited.has(relativePath)) return new Map()
  visited.add(relativePath)

  const moduleSource = source(relativePath)
  const exports = new Map()
  for (const match of moduleSource.matchAll(
    /export\s+const\s+([A-Za-z_$][\w$]*)\s*=\s*onCall\s*\(/g,
  )) {
    exports.set(match[1], match[1])
  }

  for (const match of moduleSource.matchAll(
    /export\s*\{([\s\S]*?)\}\s*from\s*["']([^"']+)["']\s*;?/g,
  )) {
    const [, specifiers, moduleSpecifier] = match
    if (!moduleSpecifier.startsWith(".")) continue
    const targetPath = relative(
      repoRoot,
      resolve(dirname(resolve(repoRoot, relativePath)), moduleSpecifier.replace(/\.js$/, ".ts")),
    )
    const targetExports = callableExports(targetPath, visited)
    for (const specifier of specifiers.split(",")) {
      const parsed = specifier.trim().match(/^(?:type\s+)?([A-Za-z_$][\w$]*)(?:\s+as\s+([A-Za-z_$][\w$]*))?$/)
      if (parsed === null) continue
      const [, importedName, exportedName = importedName] = parsed
      if (targetExports.has(importedName)) exports.set(exportedName, importedName)
    }
  }
  return exports
}

function scheduledExports(relativePath) {
  return [
    ...source(relativePath).matchAll(
      /export\s+const\s+([A-Za-z_$][\w$]*)\s*=\s*onSchedule\s*\(/g,
    ),
  ].map((match) => match[1])
}

function assertExactNames(actual, expected, label) {
  const actualNames = [...actual].sort()
  const expectedNames = [...expected].sort()
  const missing = expectedNames.filter((name) => !actualNames.includes(name))
  const unexpected = actualNames.filter((name) => !expectedNames.includes(name))
  assert(
    missing.length === 0 && unexpected.length === 0,
    `${label} must match exactly; missing: ${missing.join(", ") || "none"}; unexpected: ${
      unexpected.join(", ") || "none"
    }`,
  )
}

function parseContentSecurityPolicy(value, relativePath) {
  assert(typeof value === "string", `${relativePath} Hosting must set Content-Security-Policy`)
  const directives = new Map()
  for (const clause of value.split(";")) {
    const tokens = clause.trim().split(/\s+/).filter(Boolean)
    if (tokens.length === 0) continue
    const [directive, ...sources] = tokens
    assert(sources.length > 0, `${relativePath} Hosting CSP ${directive} must declare sources`)
    assert(!directives.has(directive), `${relativePath} Hosting CSP must not repeat ${directive}`)
    directives.set(directive, sources)
  }
  return directives
}

function assertExactCspSources(directives, directive, expected, relativePath) {
  const actual = directives.get(directive)
  assert(Array.isArray(actual), `${relativePath} Hosting CSP must declare ${directive}`)
  const missing = expected.filter((source) => !actual.includes(source))
  const unexpected = actual.filter((source) => !expected.includes(source))
  assert(
    new Set(actual).size === actual.length && missing.length === 0 && unexpected.length === 0,
    `${relativePath} Hosting CSP ${directive} sources must match exactly; missing: ${
      missing.join(", ") || "none"
    }; unexpected: ${unexpected.join(", ") || "none"}`,
  )
}

function requireEnvironmentExactCsp(value, relativePath, environmentName) {
  const environment = hostingEnvironments[environmentName]
  const otherEnvironment = hostingEnvironments[environmentName === "dev" ? "prod" : "dev"]
  const directives = parseContentSecurityPolicy(value, relativePath)
  const expected = {
    "default-src": ["'self'"],
    "base-uri": ["'self'"],
    "object-src": ["'none'"],
    "script-src": [
      "'self'",
      "https://apis.google.com",
      "https://www.google.com",
      "https://www.gstatic.com",
    ],
    "style-src": ["'self'"],
    "img-src": ["'self'", "data:"],
    "font-src": ["'self'"],
    "connect-src": [
      "'self'",
      "https://apis.google.com",
      "https://identitytoolkit.googleapis.com",
      "https://securetoken.googleapis.com",
      "https://content-firebaseappcheck.googleapis.com",
      environment.functionsOrigin,
      "https://www.google.com",
      "https://www.recaptcha.net",
    ],
    "frame-src": [
      "'self'",
      environment.authIframeOrigin,
      "https://www.google.com",
      "https://www.recaptcha.net",
    ],
    "frame-ancestors": ["'none'"],
    "form-action": ["'self'"],
  }
  assertExactNames(directives.keys(), Object.keys(expected), `${relativePath} Hosting CSP directives`)
  const allSources = [...directives.values()].flat()
  assert(
    !allSources.includes("'unsafe-inline'") && !allSources.includes("'unsafe-eval'"),
    `${relativePath} Hosting CSP must not allow unsafe-inline or unsafe-eval`,
  )
  assert(
    !allSources.some(
      (source) => source.includes("*") && /(google|cloudfunctions|firebaseio)/i.test(source),
    ),
    `${relativePath} Hosting CSP must not wildcard Google, Functions, or FirebaseIO origins`,
  )
  assert(
    !allSources.includes(otherEnvironment.functionsOrigin) &&
      !allSources.includes(otherEnvironment.authIframeOrigin),
    `${relativePath} Hosting CSP must not include ${environmentName === "dev" ? "prod" : "dev"} origins`,
  )
  for (const [directive, sources] of Object.entries(expected)) {
    assertExactCspSources(directives, directive, sources, relativePath)
  }
}

function requireAdminHosting(config, relativePath, environmentName) {
  const hosting = config.hosting
  assert(
    typeof hosting === "object" && hosting !== null && !Array.isArray(hosting),
    `${relativePath} must configure admin Hosting`,
  )
  assert(
    hosting.target === "admin",
    `${relativePath} Hosting must use the admin target; map it with firebase target:apply before Hosting deployment`,
  )
  assert(
    hosting.public === "apps/admin-web/dist",
    `${relativePath} Hosting public directory must be apps/admin-web/dist`,
  )
  assert(
    Array.isArray(hosting.rewrites) &&
      hosting.rewrites.some((rewrite) => rewrite?.source === "**" && rewrite?.destination === "/index.html"),
    `${relativePath} Hosting must configure the SPA rewrite to /index.html`,
  )
  assert(Array.isArray(hosting.headers), `${relativePath} Hosting must configure security headers`)
  const wildcardHeaderEntries = hosting.headers.filter((entry) => entry?.source === "**")
  assert(
    wildcardHeaderEntries.length === 1,
    `${relativePath} Hosting must configure exactly one wildcard security-header entry`,
  )
  const wildcardHeaders = wildcardHeaderEntries[0]?.headers
  assert(Array.isArray(wildcardHeaders), `${relativePath} Hosting must configure wildcard security headers`)
  const header = (key) => {
    const matches = wildcardHeaders.filter((candidate) => candidate?.key === key)
    assert(matches.length === 1, `${relativePath} Hosting must set ${key}`)
    return matches[0].value
  }
  const contentSecurityPolicy = header("Content-Security-Policy")
  requireEnvironmentExactCsp(contentSecurityPolicy, relativePath, environmentName)
  assert(
    header("X-Content-Type-Options") === "nosniff",
    `${relativePath} Hosting must set X-Content-Type-Options to nosniff`,
  )
  assert(
    header("Referrer-Policy") === "no-referrer",
    `${relativePath} Hosting must set Referrer-Policy to no-referrer`,
  )
  assert(
    header("Permissions-Policy") === "camera=(), geolocation=(), microphone=(), payment=(), usb=()",
    `${relativePath} Hosting must set the restrictive Permissions-Policy`,
  )
  const indexHeaderEntries = hosting.headers.filter((entry) => entry?.source === "/index.html")
  const indexHeaders = indexHeaderEntries[0]?.headers
  const cacheControlHeaders = Array.isArray(indexHeaders)
    ? indexHeaders.filter((candidate) => candidate?.key === "Cache-Control")
    : []
  assert(
    indexHeaderEntries.length === 1 &&
      cacheControlHeaders.length === 1 &&
      cacheControlHeaders[0]?.value === "no-store",
    `${relativePath} Hosting must set Cache-Control no-store for /index.html`,
  )
}

function requireFirebaseConfig(config, relativePath, environmentName, requireEmulators) {
  assert(config.firestore?.rules !== undefined, `${relativePath} must configure Firestore rules`)
  assert(
    config.firestore?.indexes === "firestore.indexes.json",
    `${relativePath} must use firestore.indexes.json`,
  )
  assert(config.functions?.source === "functions", `${relativePath} functions.source must be functions`)
  requireAdminHosting(config, relativePath, environmentName)
  if (!requireEmulators) return
  const ports = { auth: 9099, firestore: 8080, functions: 5001, storage: 9199 }
  for (const [emulator, port] of Object.entries(ports)) {
    assert(
      config.emulators?.[emulator]?.port === port,
      `${relativePath} ${emulator} emulator port must be ${port}`,
    )
  }
}

check("Firebase JSON, aliases, and admin Hosting target prerequisite", () => {
  const firebaseConfig = json("firebase.json")
  const firebaseDevConfig = json("firebase.dev.json")
  const firebaseProdConfig = json("firebase.prod.json")
  const aliases = json(".firebaserc")
  requireFirebaseConfig(firebaseConfig, "firebase.json", "dev", true)
  requireFirebaseConfig(firebaseDevConfig, "firebase.dev.json", "dev", true)
  requireFirebaseConfig(firebaseProdConfig, "firebase.prod.json", "prod", false)
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

check("current Functions exports use Node 22 and us-central1", () => {
  const packageFile = json("functions/package.json")
  assert(packageFile.engines?.node === "22", "functions/package.json engines.node must be 22")
  const functionsSource = source("functions/src/index.ts")
  const callableSecuritySource = source("functions/src/callableSecurity.ts")
  const adminCallablesSource = source("functions/src/admin/callables.ts")
  const callables = callableExports("functions/src/index.ts")
  const scheduledWorkers = scheduledExports("functions/src/index.ts")
  assertExactNames(callables.keys(), expectedHumanCallableNames, "Functions human-callable exports")
  assertExactNames(scheduledWorkers, expectedScheduledWorkerNames, "Functions scheduled-worker exports")
  for (const name of expectedScheduledWorkerNames) {
    assert(!callables.has(name), `${name} must be a scheduled worker, not a callable`)
  }
  for (const name of expectedHumanCallableNames.filter((name) => !name.startsWith("admin"))) {
    assert(
      new RegExp(
        `export\\s+const\\s+${name}\\s*=\\s*onCall\\s*\\(\\s*(?:callableSecurity\\s*,|\\{\\s*\\.\\.\\.callableSecurity\\s*,)`,
      ).test(functionsSource),
      `${name} must use the shared callable security options`,
    )
  }
  for (const name of expectedHumanCallableNames.filter((name) => name.startsWith("admin"))) {
    assert(
      new RegExp(`export\\s+const\\s+${name}\\s*=\\s*onCall\\s*\\(\\s*adminCallableOptions\\s*,`).test(
        adminCallablesSource,
      ),
      `${name} must use adminCallableOptions`,
    )
  }
  assert(
    callableSecuritySource.includes('region: "us-central1"'),
    "callable security options must pin us-central1",
  )
  assert(
    callableSecuritySource.includes('enforceAppCheck: environment["FUNCTIONS_EMULATOR"] !== "true"'),
    "deployed callable functions must enforce App Check",
  )
  assert(
    /const\s+adminCallableOptions\s*:\s*CallableOptions\s*=\s*\{[\s\S]*?region\s*:\s*["']us-central1["']/.test(
      adminCallablesSource,
    ),
    "admin callable options must pin us-central1",
  )
  assert(
    /const\s+adminCallableOptions\s*:\s*CallableOptions\s*=\s*\{[\s\S]*?enforceAppCheck\s*:\s*true/.test(
      adminCallablesSource,
    ),
    "admin callable options must enforce App Check",
  )
})

check("admin web Hosting boundary", () => {
  const packageFile = json("apps/admin-web/package.json")
  for (const script of ["build", "test", "typecheck", "lint"]) {
    assert(
      typeof packageFile.scripts?.[script] === "string" && packageFile.scripts[script].trim().length > 0,
      `apps/admin-web/package.json must define a ${script} script`,
    )
  }
  const forbiddenImport = /(?:from\s*|import\s*(?:\(\s*)?)["']firebase\/(?:firestore|storage)(?:\/[^"']*)?["']/
  const offenders = sourceFiles("apps/admin-web/src").filter((path) => forbiddenImport.test(source(path)))
  assert(
    offenders.length === 0,
    `admin web must use callable APIs rather than direct Firestore or Storage imports: ${offenders.join(", ")}`,
  )
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
