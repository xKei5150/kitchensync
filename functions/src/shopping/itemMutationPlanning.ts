import { HttpsError } from "firebase-functions/v2/https"
import { assertNever } from "./exhaustiveness.js"
import type { ShoppingItemMutation, StoredShoppingItem } from "./shoppingWriteModels.js"

export function applyItemMutation(
  item: StoredShoppingItem,
  mutation: Exclude<ShoppingItemMutation, { readonly kind: "add" | "remove" }>,
): StoredShoppingItem {
  switch (mutation.kind) {
    case "setNeededQuantity":
      return {
        ...item,
        quantityNeeded: mutation.quantityNeeded,
        sourceMealLinks: trimSourceMealLinks(item.sourceMealLinks, mutation.quantityNeeded),
      }
    case "setPurchasedQuantity":
      if (item.status !== "bought" && mutation.purchasedQuantity !== null) {
        throw new HttpsError("failed-precondition", "Only bought items have purchased quantity")
      }
      return { ...item, purchasedQuantity: mutation.purchasedQuantity }
    case "setStatus":
      return {
        ...item,
        status: mutation.status,
        purchasedQuantity: mutation.purchasedQuantity,
        substituteIngredientId: mutation.substituteIngredientId,
        substituteQuantity: mutation.substituteQuantity,
        substituteUnit: mutation.substituteUnit,
      }
    default:
      return assertNever(mutation)
  }
}

function trimSourceMealLinks(
  sourceMealLinks: StoredShoppingItem["sourceMealLinks"],
  quantityNeeded: number,
): StoredShoppingItem["sourceMealLinks"] {
  const linkedQuantity = roundQuantity(
    sourceMealLinks.reduce((total, link) => total + link.quantity, 0),
  )
  let quantityToTrim = roundQuantity(linkedQuantity - quantityNeeded)
  if (quantityToTrim <= 0) return sourceMealLinks

  const result = []
  const orderedLinks = [...sourceMealLinks].sort(compareSourceMealLinks)
  for (const link of orderedLinks) {
    if (quantityToTrim >= link.quantity) {
      quantityToTrim = roundQuantity(quantityToTrim - link.quantity)
      continue
    }
    if (quantityToTrim > 0) {
      result.push({ ...link, quantity: roundQuantity(link.quantity - quantityToTrim) })
      quantityToTrim = 0
      continue
    }
    result.push(link)
  }
  return absorbRoundingDrift(result, Math.min(quantityNeeded, linkedQuantity))
}

function absorbRoundingDrift(
  links: readonly StoredShoppingItem["sourceMealLinks"][number][],
  expectedQuantity: number,
): StoredShoppingItem["sourceMealLinks"] {
  const actualQuantity = roundQuantity(links.reduce((total, link) => total + link.quantity, 0))
  const drift = roundQuantity(expectedQuantity - actualQuantity)
  if (drift === 0) return links

  for (let index = links.length - 1; index >= 0; index -= 1) {
    const link = links[index]
    if (link === undefined || link.quantity <= 0) continue
    const adjustedQuantity = roundQuantity(link.quantity + drift)
    if (adjustedQuantity <= 0) {
      throw new HttpsError("failed-precondition", "Shopping source link is malformed")
    }
    return links.map((candidate, candidateIndex) =>
      candidateIndex === index ? { ...candidate, quantity: adjustedQuantity } : candidate,
    )
  }
  throw new HttpsError("failed-precondition", "Shopping source link is malformed")
}

function compareSourceMealLinks(
  left: StoredShoppingItem["sourceMealLinks"][number],
  right: StoredShoppingItem["sourceMealLinks"][number],
): number {
  const date = left.date.localeCompare(right.date)
  if (date !== 0) return date
  const meal = left.mealEntryId.localeCompare(right.mealEntryId)
  return meal === 0 ? left.recipeId.localeCompare(right.recipeId) : meal
}

function roundQuantity(value: number): number {
  return Math.round(value * 1000) / 1000
}
