import { createHash } from "node:crypto"

type CanonicalValue =
  | null
  | boolean
  | number
  | string
  | readonly CanonicalValue[]
  | { readonly [key: string]: CanonicalValue }

class UnsupportedCanonicalPayloadError extends Error {
  readonly name = "UnsupportedCanonicalPayloadError"

  constructor() {
    super("Canonical payload contains an unsupported value")
  }
}

export function canonicalPayloadHash(payload: unknown): string {
  const serialized = JSON.stringify(canonicalValue(payload))
  if (serialized === undefined) {
    throw new UnsupportedCanonicalPayloadError()
  }
  return createHash("sha256").update(serialized).digest("hex")
}

export function payloadHashForUpsert(payload: unknown): string {
  return canonicalPayloadHash(payload)
}

export function payloadHashForItemMutation(payload: unknown): string {
  return canonicalPayloadHash(payload)
}

function canonicalValue(value: unknown): CanonicalValue {
  if (value === null || typeof value === "boolean" || typeof value === "string") {
    return value
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new UnsupportedCanonicalPayloadError()
    }
    return value
  }
  if (Array.isArray(value)) {
    return value.map(canonicalValue)
  }
  if (isRecord(value)) {
    const result: Record<string, CanonicalValue> = {}
    for (const key of Object.keys(value).sort()) {
      const entry = value[key]
      if (entry === undefined) {
        throw new UnsupportedCanonicalPayloadError()
      }
      result[key] = canonicalValue(entry)
    }
    return result
  }
  throw new UnsupportedCanonicalPayloadError()
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}
