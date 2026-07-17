import { createHash } from "node:crypto"
import type { DocumentReference } from "firebase-admin/firestore"
import { FieldValue, Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import type { PantryItemSnapshot, PurchaseLine, ShoppingItemSnapshot } from "./completionTypes.js"
import { assertNever } from "./exhaustiveness.js"
import type { IngredientMetadata } from "./firestoreModels.js"
import type { FirestoreWrite } from "./writePlan.js"

export function purchaseLinesFor(
  items: readonly ShoppingItemSnapshot[],
  listId: string,
): readonly PurchaseLine[] {
  const lines: PurchaseLine[] = []
  for (const item of items) {
    if (item.data.shoppingListId !== listId) {
      throw new HttpsError("failed-precondition", "Shopping list item is malformed")
    }
    switch (item.data.status) {
      case "unchecked":
      case "unavailable":
      case "skipped":
        break
      case "bought":
        lines.push({
          kind: "bought",
          itemId: item.itemId,
          originalIngredientId: item.data.ingredientId,
          originalUnit: item.data.unit,
          purchasedIngredientId: item.data.ingredientId,
          purchasedUnit: item.data.unit,
          quantity: item.data.purchasedQuantity ?? item.data.quantityNeeded,
          sourceMealLinks: item.data.sourceMealLinks,
        })
        break
      case "substituted":
        lines.push({
          kind: "substituted",
          itemId: item.itemId,
          originalIngredientId: item.data.ingredientId,
          originalUnit: item.data.unit,
          purchasedIngredientId: item.data.substituteIngredientId,
          purchasedUnit: item.data.substituteUnit,
          quantity: item.data.substituteQuantity,
          sourceMealLinks: item.data.sourceMealLinks,
        })
        break
      default:
        assertNever(item.data)
    }
  }
  return lines.sort((left, right) => left.itemId.localeCompare(right.itemId))
}

export function buildPantryAndPurchaseWrites(input: {
  readonly householdRef: DocumentReference
  readonly householdId: string
  readonly listId: string
  readonly lines: readonly PurchaseLine[]
  readonly pantryItems: readonly PantryItemSnapshot[]
  readonly ingredientMetadata: ReadonlyMap<string, IngredientMetadata>
}): readonly FirestoreWrite[] {
  const writes: FirestoreWrite[] = []
  const keys = [
    ...new Set(
      input.lines.map((line) => ingredientUnitKey(line.purchasedIngredientId, line.purchasedUnit)),
    ),
  ]
  const sectionByKey = new Map<string, "food" | "bulk" | "nonFood">()
  for (const key of keys.sort()) {
    const lines = input.lines.filter(
      (line) => ingredientUnitKey(line.purchasedIngredientId, line.purchasedUnit) === key,
    )
    const firstLine = lines.at(0)
    if (firstLine === undefined) continue
    const matchingPantry = input.pantryItems
      .filter(
        (item) =>
          item.data.ingredientId === firstLine.purchasedIngredientId &&
          item.data.unit === firstLine.purchasedUnit,
      )
      .sort(comparePantryPriority)
    const existing = matchingPantry.at(0)
    const quantity = lines.reduce((total, line) => total + line.quantity, 0)
    const metadata = input.ingredientMetadata.get(firstLine.purchasedIngredientId)
    if (metadata === undefined) {
      throw new HttpsError("failed-precondition", "Ingredient metadata is missing")
    }
    const section = existing?.data.section ?? sectionForIngredient(metadata)
    const expiryDate = defaultExpiryDate(metadata)
    sectionByKey.set(key, section)
    if (existing === undefined) {
      writes.push({
        kind: "create",
        ref: input.householdRef
          .collection("pantryItems")
          .doc(deterministicPantryId(input.listId, key)),
        data: {
          householdId: input.householdId,
          ingredientId: firstLine.purchasedIngredientId,
          quantity,
          unit: firstLine.purchasedUnit,
          section,
          lastPurchaseDate: FieldValue.serverTimestamp(),
          expiryDate,
          schemaVersion: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      })
    } else {
      writes.push({
        kind: "update",
        ref: existing.ref,
        data: {
          quantity: existing.data.quantity + quantity,
          lastPurchaseDate: FieldValue.serverTimestamp(),
          ...(existing.data.expiryDate == null && expiryDate != null ? { expiryDate } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        },
      })
    }
  }
  for (const line of input.lines) {
    const section = sectionByKey.get(
      ingredientUnitKey(line.purchasedIngredientId, line.purchasedUnit),
    )
    if (section === undefined) {
      throw new HttpsError("failed-precondition", "Pantry purchase plan is incomplete")
    }
    writes.push({
      kind: "create",
      ref: input.householdRef
        .collection("purchases")
        .doc(deterministicPurchaseId(input.listId, line.itemId)),
      data: {
        householdId: input.householdId,
        ingredientId: line.purchasedIngredientId,
        quantity: line.quantity,
        unit: line.purchasedUnit,
        purchaseDate: FieldValue.serverTimestamp(),
        sourceShoppingListId: input.listId,
        isBulk: section === "bulk",
        isNonFood: section === "nonFood",
        schemaVersion: 1,
      },
    })
  }
  return writes
}

export function sectionForIngredient(metadata: IngredientMetadata): "food" | "bulk" | "nonFood" {
  if (metadata.isNonFood) return "nonFood"
  if (metadata.isBulkCandidate) return "bulk"
  return "food"
}

export function defaultExpiryDate(
  metadata: IngredientMetadata,
  nowMillis = Date.now(),
): Timestamp | null {
  const days = metadata.defaultShelfLifeDays
  if (days === undefined) return null
  return Timestamp.fromMillis(nowMillis + days * 24 * 60 * 60 * 1000)
}

export function deterministicPurchaseId(listId: string, itemId: string): string {
  return `shopping_${digest(`${listId}\0${itemId}`)}`
}

function deterministicPantryId(listId: string, ingredientUnit: string): string {
  return `shopping_${digest(`${listId}\0${ingredientUnit}`)}`
}

function digest(value: string): string {
  return createHash("sha256").update(value).digest("hex")
}

function ingredientUnitKey(ingredientId: string, unit: string): string {
  return JSON.stringify([ingredientId, unit])
}

function comparePantryPriority(left: PantryItemSnapshot, right: PantryItemSnapshot): number {
  const section = pantryPriority(left.data.section) - pantryPriority(right.data.section)
  return section === 0 ? left.ref.id.localeCompare(right.ref.id) : section
}

function pantryPriority(section: "food" | "bulk" | "nonFood"): number {
  switch (section) {
    case "food":
      return 0
    case "bulk":
      return 1
    case "nonFood":
      return 2
    default:
      return assertNever(section)
  }
}
