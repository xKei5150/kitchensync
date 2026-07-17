import { randomUUID } from "node:crypto"
import { deleteApp, type FirebaseApp, initializeApp } from "firebase/app"
import { type Auth, connectAuthEmulator, getAuth, signInAnonymously } from "firebase/auth"
import {
  connectFunctionsEmulator,
  type Functions,
  getFunctions,
  httpsCallable,
} from "firebase/functions"
import { afterEach, describe, expect, it } from "vitest"
import { authEmulatorUrl, functionsEmulatorEndpoint } from "./emulatorEnv.js"

const gcloudProjectEnvKey = "GCLOUD_PROJECT"
const projectId = process.env[gcloudProjectEnvKey] ?? "kitchensync-dev-da503"

function createClient(): {
  readonly app: FirebaseApp
  readonly auth: Auth
  readonly functions: Functions
} {
  const app = initializeApp({
    apiKey: "ownerless-emulator-key",
    appId: `1:000000000000:web:${randomUUID().replaceAll("-", "")}`,
    projectId,
  })
  const auth = getAuth(app)
  const functions = getFunctions(app)
  const functionsEndpoint = functionsEmulatorEndpoint()
  connectAuthEmulator(auth, authEmulatorUrl(), { disableWarnings: true })
  connectFunctionsEmulator(functions, functionsEndpoint.host, functionsEndpoint.port)
  return { app, auth, functions }
}

async function expectCallableCode(action: () => Promise<unknown>, code: string): Promise<void> {
  try {
    await action()
  } catch (error) {
    if (error instanceof Error && hasStringCode(error)) {
      expect(error.code).toBe(`functions/${code}`)
      return
    }
    throw error
  }
  throw new Error(`callable did not throw ${code}`)
}

function hasStringCode(error: Error): error is Error & { readonly code: string } {
  return "code" in error && typeof error.code === "string"
}

describe("shoppingSmoke emulator smoke", () => {
  let appToDelete: FirebaseApp | undefined

  afterEach(async () => {
    if (appToDelete !== undefined) {
      await deleteApp(appToDelete)
      appToDelete = undefined
    }
  })

  it("returns ok for an authenticated caller and unauthenticated for an anonymous transport", async () => {
    // Given: a real Functions emulator client and an unsigned callable request.
    const client = createClient()
    appToDelete = client.app
    const smoke = httpsCallable(client.functions, "shoppingSmoke")

    // When/Then: the unsigned transport receives Firebase's unauthenticated code.
    await expectCallableCode(() => smoke({}), "unauthenticated")

    // Given: the same client signs in through the real Auth emulator.
    await signInAnonymously(client.auth)

    // When: the callable is invoked through the Functions emulator.
    const response = await smoke({})

    // Then: the observable callable payload matches the contract.
    expect(response.data).toEqual({ ok: true })
  })
})
