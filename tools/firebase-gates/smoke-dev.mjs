#!/usr/bin/env node

import { request } from "node:https"

const devProject = "kitchensync-dev-da503"
const region = "us-central1"
const phase = process.argv[2]

if (phase !== "before-rules" && phase !== "after-rules") {
  throw new Error("Usage: smoke-dev.mjs <before-rules|after-rules>")
}

const idToken = requiredEnvironment("FIREBASE_SEMANTIC_SMOKE_ID_TOKEN")
const appCheckToken = requiredEnvironment("FIREBASE_SEMANTIC_SMOKE_APP_CHECK_TOKEN")
const householdId = requiredEnvironment("FIREBASE_SEMANTIC_SMOKE_HOUSEHOLD_ID")

function requiredEnvironment(name) {
  const value = process.env[name]
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${name} is required; provide a non-anonymous QA Firebase ID token`)
  }
  return value
}

function jsonRequest(method, url, body, token, appCheck) {
  return new Promise((resolvePromise, reject) => {
    const target = new URL(url)
    const payload = JSON.stringify(body)
    const headers = {
      "content-length": Buffer.byteLength(payload),
      "content-type": "application/json",
      ...(token === undefined ? {} : { authorization: `Bearer ${token}` }),
      ...(appCheck === undefined ? {} : { "x-firebase-appcheck": appCheck }),
    }
    const clientRequest = request(
      target,
      { method, headers, timeout: 20_000 },
      (response) => {
        const chunks = []
        response.on("data", (chunk) => chunks.push(chunk))
        response.on("end", () => {
          const text = Buffer.concat(chunks).toString("utf8")
          let data
          try {
            data = text.length === 0 ? {} : JSON.parse(text)
          } catch (error) {
            reject(new Error(`Non-JSON ${method} response (${response.statusCode}): ${String(error)}`))
            return
          }
          resolvePromise({ status: response.statusCode ?? 0, data })
        })
      },
    )
    clientRequest.on("timeout", () => clientRequest.destroy(new Error(`${method} timed out`)))
    clientRequest.on("error", reject)
    clientRequest.end(payload)
  })
}

function callableUrl(name) {
  return `https://${region}-${devProject}.cloudfunctions.net/${name}`
}

async function call(name, data) {
  const response = await jsonRequest("POST", callableUrl(name), { data }, idToken, appCheckToken)
  if (response.status !== 200 || response.data.result === undefined) {
    throw new Error(`${name} failed with HTTP ${response.status}`)
  }
  return response.data.result
}

async function proveDirectPurchaseWriteDenied() {
  const documents = `https://firestore.googleapis.com/v1/projects/${devProject}/databases/(default)/documents`
  const purchaseId = `semantic-smoke-${Date.now()}`
  const result = await jsonRequest(
    "PATCH",
    `${documents}/households/${householdId}/purchases/${purchaseId}`,
    {
      fields: {
        householdId: { stringValue: householdId },
        ingredientId: { stringValue: "forged" },
        quantity: { doubleValue: 1 },
        unit: { stringValue: "piece" },
      },
    },
    idToken,
  )
  if (result.status !== 403) {
    throw new Error(`direct purchase write was not denied (HTTP ${result.status})`)
  }
}

function assertNonAnonymousIdentity(token) {
  const payload = token.split(".")[1]
  if (payload === undefined) throw new Error("FIREBASE_SEMANTIC_SMOKE_ID_TOKEN is not a Firebase ID token")
  try {
    const claims = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"))
    if (claims.firebase?.sign_in_provider === "anonymous") {
      throw new Error("FIREBASE_SEMANTIC_SMOKE_ID_TOKEN must not be anonymous")
    }
  } catch (error) {
    if (error instanceof Error && error.message.includes("must not be anonymous")) throw error
    throw new Error("FIREBASE_SEMANTIC_SMOKE_ID_TOKEN has an unreadable JWT payload")
  }
}

async function main() {
  assertNonAnonymousIdentity(idToken)
  const response = await call("shoppingSmoke", {})
  if (response.ok !== true) throw new Error("shoppingSmoke returned an unexpected response")
  if (phase === "after-rules") await proveDirectPurchaseWriteDenied()
  console.log(`PASS ${phase}: non-anonymous, App Check-enforced callable boundary is reachable`)
}

await main()
