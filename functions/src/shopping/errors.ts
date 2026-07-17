import { type FunctionsErrorCode, HttpsError } from "firebase-functions/v2/https"

export function requireAuthUid(authUid: string | undefined): string {
  if (authUid === undefined || authUid.length === 0) {
    throw new HttpsError("unauthenticated", "Authentication is required")
  }
  return authUid
}

export async function mapFirestoreErrors<T>(action: () => Promise<T>): Promise<T> {
  try {
    return await action()
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error
    }
    const retryableCode = retryableFirestoreCode(error)
    if (retryableCode !== undefined) {
      throw new HttpsError(retryableCode, "Retryable Firestore error", { cause: error })
    }
    if (isResourceExhausted(error)) {
      throw new HttpsError("resource-exhausted", "Firestore write limit exceeded", {
        cause: error,
      })
    }
    throw error
  }
}

function isResourceExhausted(error: unknown): boolean {
  if (!hasCode(error)) return false
  if (error.code === "resource-exhausted" || error.code === 8) return true
  return error.code === 3 && hasDetails(error) && error.details.includes("maximum entity size")
}

function hasDetails(
  error: unknown,
): error is { readonly code: string | number; readonly details: string } {
  return hasCode(error) && "details" in error && typeof error.details === "string"
}

function retryableFirestoreCode(error: unknown): FunctionsErrorCode | undefined {
  if (!hasCode(error)) {
    return undefined
  }
  if (error.code === "aborted" || error.code === 10) {
    return "aborted"
  }
  if (error.code === "unavailable" || error.code === 14) {
    return "unavailable"
  }
  return undefined
}

function hasCode(error: unknown): error is { readonly code: string | number } {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (typeof error.code === "string" || typeof error.code === "number")
  )
}
