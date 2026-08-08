import type { Firestore } from "firebase-admin/firestore"
import { requireActiveAccountLifecycle } from "../accountLifecycleBarrier.js"
import { parseShoppingSmokeRequest } from "./contracts.js"
import { requireAuthUid } from "./errors.js"

export type ShoppingSmokeCallableRequest = {
  readonly authUid?: string
  readonly data: unknown
}

export type ShoppingSmokeResponse = {
  readonly ok: true
}

export async function shoppingSmokeHandler(
  request: ShoppingSmokeCallableRequest,
  db: Firestore,
): Promise<ShoppingSmokeResponse> {
  const authUid = requireAuthUid(request.authUid)
  await requireActiveAccountLifecycle({ get: (reference) => reference.get() }, db, authUid)
  parseShoppingSmokeRequest(request.data)
  return { ok: true }
}
