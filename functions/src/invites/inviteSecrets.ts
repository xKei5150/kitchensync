import { createHmac, randomBytes } from "node:crypto"
import { inspect } from "node:util"

/** 256 bits exceeds the 128-bit minimum required for invite bearer secrets. */
export const INVITE_TOKEN_BYTES = 32
export const DEFAULT_INVITE_ISSUE_ATTEMPTS = 5

const hmacVersion = "hmac-sha256-v1"
const inviteTokenPattern = /^[A-Za-z0-9_-]{43}$/
const redactedInviteToken = "[REDACTED_INVITE_TOKEN]"

/**
 * The only representation of an invite token allowed in persistent records.
 * `tryReserveLookup` must atomically reject a value that is already reserved.
 */
export type InviteSecretStorage = Readonly<{
  readonly tokenLookupHmac: string
  readonly tokenLookupHmacVersion: "hmac-sha256-v1"
}>

export type InviteSecretIssuanceOptions = Readonly<{
  /** A server-only HMAC key. It must not be placed in callable input or records. */
  readonly hmacKey: Uint8Array
  /**
   * Atomically reserves the lookup representation for the eventual invite
   * record. It receives no raw bearer token and returns false on collision.
   */
  readonly tryReserveLookup: (storage: InviteSecretStorage) => Promise<boolean>
  /** Test seam; production uses Node's cryptographically secure randomBytes. */
  readonly randomBytes?: (size: number) => Uint8Array
}>

export type IssuedInviteSecret = Readonly<{
  /** Redacted on JSON/string/diagnostic rendering; reveal only in the issuance response. */
  readonly rawToken: InviteRawToken
  readonly storage: InviteSecretStorage
}>

const rawTokenValues = new WeakMap<RedactedInviteRawToken, string>()

/**
 * An intentionally opaque raw bearer token. Its value is held only in process
 * memory, so accidental JSON serialization or structured diagnostics redact it.
 */
class RedactedInviteRawToken {
  private constructor() {}

  static fromRawValue(value: string): RedactedInviteRawToken {
    const token = new RedactedInviteRawToken()
    rawTokenValues.set(token, value)
    return Object.freeze(token)
  }

  toJSON(): string {
    return redactedInviteToken
  }

  toString(): string {
    return redactedInviteToken
  }

  [inspect.custom](): string {
    return `InviteRawToken ${redactedInviteToken}`
  }
}

export type InviteRawToken = RedactedInviteRawToken

/**
 * Returns the raw bearer secret exactly for the trusted issuance response.
 * Never pass its result to storage, logging, audit, analytics, or admin output.
 */
export function revealInviteToken(token: InviteRawToken): string {
  const value = rawTokenValues.get(token)
  if (value === undefined) throw new Error("Invite token is unavailable")
  return value
}

/**
 * Issues an opaque token only after its HMAC lookup key has been atomically
 * reserved. Collision attempts are discarded without exposing their raw value.
 */
export async function issueInviteSecret(
  options: InviteSecretIssuanceOptions,
): Promise<IssuedInviteSecret> {
  const randomSource = options.randomBytes ?? randomBytes
  for (let attempt = 0; attempt < DEFAULT_INVITE_ISSUE_ATTEMPTS; attempt += 1) {
    const rawValue = newRawInviteToken(randomSource)
    const storage = lookupForInviteToken(rawValue, options.hmacKey)
    if (await options.tryReserveLookup(storage)) {
      return {
        rawToken: RedactedInviteRawToken.fromRawValue(rawValue),
        storage,
      }
    }
  }
  throw new InviteTokenCollisionError()
}

/**
 * Computes the sole persistent lookup representation for a received raw token.
 * Legacy `KS-` values are rejected by the opaque-token format before lookup.
 */
export function lookupForInviteToken(rawToken: string, hmacKey: Uint8Array): InviteSecretStorage {
  if (!inviteTokenPattern.test(rawToken)) throw new Error("Invalid invite token")
  const digest = createHmac("sha256", validHmacKey(hmacKey)).update(rawToken).digest("base64url")
  return {
    tokenLookupHmac: `${hmacVersion}:${digest}`,
    tokenLookupHmacVersion: hmacVersion,
  }
}

export class InviteTokenCollisionError extends Error {
  constructor() {
    super("Unable to issue invite")
    this.name = "InviteTokenCollisionError"
  }
}

function newRawInviteToken(randomSource: (size: number) => Uint8Array): string {
  const bytes = randomSource(INVITE_TOKEN_BYTES)
  if (!(bytes instanceof Uint8Array) || bytes.byteLength !== INVITE_TOKEN_BYTES) {
    throw new Error("Invite random source returned an invalid byte count")
  }
  return Buffer.from(bytes).toString("base64url")
}

function validHmacKey(key: Uint8Array): Buffer {
  if (!(key instanceof Uint8Array) || key.byteLength < 32) {
    throw new Error("Invite HMAC key must contain at least 256 bits")
  }
  return Buffer.from(key)
}
