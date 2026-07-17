import { parseShoppingSmokeRequest } from "./contracts.js"
import { requireAuthUid } from "./errors.js"

export type ShoppingSmokeCallableRequest = {
  readonly authUid?: string
  readonly data: unknown
}

export type ShoppingSmokeResponse = {
  readonly ok: true
}

export function shoppingSmokeHandler(request: ShoppingSmokeCallableRequest): ShoppingSmokeResponse {
  requireAuthUid(request.authUid)
  parseShoppingSmokeRequest(request.data)
  return { ok: true }
}
