#!/usr/bin/env node

import { randomUUID } from "node:crypto"
import { spawnSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { request } from "node:https"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const devProject = "kitchensync-dev-da503"
const region = "us-central1"
const phase = process.argv[2]

if (phase !== "before-rules" && phase !== "after-rules") {
  throw new Error("Usage: smoke-dev.mjs <before-rules|after-rules>")
}

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const firebaseBin = process.env.FIREBASE_BIN ?? resolve(repoRoot, "tools/firebase-gates/firebase.sh")
const googleServices = JSON.parse(readFileSync(resolve(repoRoot, "android/app/google-services.json"), "utf8"))
if (googleServices.project_info?.project_id !== devProject) {
  throw new Error(`Android Firebase config must target ${devProject}`)
}
const apiKey = googleServices.client?.[0]?.api_key?.[0]?.current_key
if (typeof apiKey !== "string") throw new Error("Android Firebase config is missing apiKey")

const today = new Date().toISOString().slice(0, 10)

class SemanticSmokeError extends Error {
  constructor(message, cleanupErrors = []) {
    super(message)
    this.cleanupErrors = cleanupErrors
  }
}

function postJson(url, body, token) {
  return jsonRequest("POST", url, body, token)
}

function patchJson(url, body, token) {
  return jsonRequest("PATCH", url, body, token)
}

function jsonRequest(method, url, body, token) {
  return new Promise((resolvePromise, reject) => {
    const target = new URL(url)
    const payload = JSON.stringify(body)
    const headers = {
      "content-length": Buffer.byteLength(payload),
      "content-type": "application/json",
      ...(token === undefined ? {} : { authorization: `Bearer ${token}` }),
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

function firestoreDocument(fields) {
  return { fields }
}

function stringValue(value) {
  return { stringValue: value }
}

function callableUrl(name) {
  return `https://${region}-${devProject}.cloudfunctions.net/${name}`
}

async function call(name, data, token) {
  const response = await postJson(callableUrl(name), { data }, token)
  if (response.status !== 200 || response.data.result === undefined) {
    throw new Error(`${name} failed with HTTP ${response.status}`)
  }
  return response.data.result
}

async function createFixture(token, uid, householdId) {
  const documents = `https://firestore.googleapis.com/v1/projects/${devProject}/databases/(default)/documents`
  const household = await patchJson(
    `${documents}/households/${householdId}?currentDocument.exists=false`,
    { fields: {
      name: stringValue("Todo 9 rollout QA"),
      creatorUserId: stringValue(uid),
      isJoint: { booleanValue: false },
      hasPremium: { booleanValue: false },
      maxMembers: { integerValue: "1" },
    } },
    token,
  )
  if (household.status !== 200) throw new Error(`fixture household create failed: HTTP ${household.status}`)
  const member = await patchJson(
    `${documents}/households/${householdId}/members/${uid}?currentDocument.exists=false`,
    { fields: { role: stringValue("admin") } },
    token,
  )
  if (member.status !== 200) throw new Error(`fixture member create failed: HTTP ${member.status}`)
}

async function proveDirectWritesDenied(token, householdId, listId, itemId) {
  const documents = `https://firestore.googleapis.com/v1/projects/${devProject}/databases/(default)/documents`
  const parent = await patchJson(
    `${documents}/households/${householdId}/shoppingLists/${listId}?updateMask.fieldPaths=revision`,
    firestoreDocument({ revision: { integerValue: "999" } }),
    token,
  )
  const item = await patchJson(
    `${documents}/households/${householdId}/shoppingLists/${listId}/items/${itemId}?updateMask.fieldPaths=quantityNeeded`,
    firestoreDocument({ quantityNeeded: { doubleValue: 999 } }),
    token,
  )
  if (parent.status !== 403 || item.status !== 403) {
    throw new Error(`direct writes were not both denied (parent=${parent.status}, item=${item.status})`)
  }
}

function cleanupFixture(householdId, receiptIds) {
  const cleanupErrors = []
  const cleanupTargets = [
    { path: `households/${householdId}`, recursive: true },
    ...receiptIds.map((receiptId) => ({ path: `shoppingCommandReceipts/${receiptId}`, recursive: false })),
  ]
  for (const target of cleanupTargets) {
    const result = spawnSync(
      firebaseBin,
      [
        "firestore:delete",
        "--project",
        devProject,
        "--database",
        "(default)",
        ...(target.recursive ? ["--recursive"] : []),
        "--force",
        target.path,
      ],
      { cwd: repoRoot, encoding: "utf8" },
    )
    if (result.status !== 0) {
      cleanupErrors.push(`Firebase CLI cleanup exited ${result.status ?? "without status"}`)
    }
  }
  return cleanupErrors
}

async function main() {
  const auth = await postJson(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${encodeURIComponent(apiKey)}`,
    { returnSecureToken: true },
  )
  const token = auth.data.idToken
  const uid = auth.data.localId
  if (auth.status !== 200 || typeof token !== "string" || typeof uid !== "string") {
    throw new Error(`anonymous dev authentication failed: HTTP ${auth.status}`)
  }
  const suffix = `${Date.now()}-${randomUUID().slice(0, 8)}`
  const householdId = `qa-household-${suffix}`
  const listId = `qa-list-${suffix}`
  const itemId = "qa-item"
  const upsertCommandId = `upsert-${suffix}`
  const mutateCommandId = `mutate-${suffix}`
  const postRulesCommandId = `post-rules-${suffix}`
  const deleteCommandId = `delete-${suffix}`
  let smokeError

  try {
    await createFixture(token, uid, householdId)

    const created = await call(
      "upsertShoppingList",
      {
        householdId,
        listId,
        commandId: upsertCommandId,
        expectedRevision: null,
        list: {
          type: "shop_now",
          shoppingDate: today,
          generatedForRangeStart: today,
          generatedForRangeEnd: today,
          originId: null,
          status: "pending",
          items: [
            {
              itemId,
              ingredientId: "rice",
              quantityNeeded: 2,
              purchasedQuantity: null,
              unit: "kg",
              status: "unchecked",
              substituteIngredientId: null,
              substituteQuantity: null,
              substituteUnit: null,
              sourceMealLinks: [],
            },
          ],
        },
      },
      token,
    )
    if (created.revision !== 0 || created.alreadyApplied !== false) {
      throw new Error("upsertShoppingList returned an unexpected create response")
    }

    const mutated = await call(
      "mutateShoppingListItem",
      {
        householdId,
        listId,
        itemId,
        commandId: mutateCommandId,
        expectedRevision: 0,
        mutation: { kind: "setNeededQuantity", quantityNeeded: 3 },
      },
      token,
    )
    if (mutated.revision !== 1 || mutated.alreadyApplied !== false) {
      throw new Error("mutateShoppingListItem returned an unexpected response")
    }

    if (phase === "after-rules") {
      await proveDirectWritesDenied(token, householdId, listId, itemId)
      const afterRules = await call(
        "mutateShoppingListItem",
        {
          householdId,
          listId,
          itemId,
          commandId: postRulesCommandId,
          expectedRevision: 1,
          mutation: { kind: "setNeededQuantity", quantityNeeded: 4 },
        },
        token,
      )
      if (afterRules.revision !== 2) {
        throw new Error("callable mutation did not remain available after rules deployment")
      }
    }

    await call("deleteShoppingList", { householdId, listId, commandId: deleteCommandId }, token)
  } catch (error) {
    smokeError = error
  }

  const receiptIds = [upsertCommandId, mutateCommandId, postRulesCommandId, deleteCommandId]
  const cleanupErrors = cleanupFixture(householdId, receiptIds)
  if (smokeError !== undefined || cleanupErrors.length > 0) {
    const message = smokeError instanceof Error ? smokeError.message : String(smokeError)
    throw new SemanticSmokeError(message, cleanupErrors)
  }

  console.log(`PASS ${phase}: callable write boundary is reachable and semantically correct`)
}

await main()
