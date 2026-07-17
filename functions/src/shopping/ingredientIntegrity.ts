import type { Firestore, Transaction } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"

const massUnits = new Set(["mg", "g", "kg", "oz", "lb"])
const volumeUnits = new Set(["ml", "l", "fl-oz", "pt", "qt", "gal", "tsp", "tbsp", "cup"])

export async function requireIngredientReference(
  transaction: Transaction,
  db: Firestore,
  householdId: string,
  ingredientId: string,
  unit: string,
): Promise<void> {
  const global = await transaction.get(db.collection("ingredients").doc(ingredientId))
  const snapshot = global.exists
    ? global
    : await transaction.get(
        db
          .collection("households")
          .doc(householdId)
          .collection("customIngredients")
          .doc(ingredientId),
      )
  if (!snapshot.exists) {
    throw new HttpsError("failed-precondition", `Ingredient ${ingredientId} is not accessible`)
  }
  const data = snapshot.data() as Readonly<
    Record<string, unknown> & { readonly allowedUnits?: unknown }
  >
  const allowed = Array.isArray(data.allowedUnits)
    ? data.allowedUnits.filter((value): value is string => typeof value === "string")
    : []
  if (!unitIsAllowed(unit, allowed)) {
    throw new HttpsError(
      "failed-precondition",
      `Unit ${unit} is not allowed for ingredient ${ingredientId}`,
    )
  }
}

export function unitIsAllowed(unit: string, allowed: readonly string[]): boolean {
  if (allowed.includes(unit)) return true
  if (massUnits.has(unit)) return allowed.some((candidate) => massUnits.has(candidate))
  if (volumeUnits.has(unit)) return allowed.some((candidate) => volumeUnits.has(candidate))
  return false
}
