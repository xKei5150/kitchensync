import { Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import type { PlannerDraft } from "./plannerClient.js"

export function validatePlannedDraft(
  draft: PlannerDraft,
  command: Readonly<{ readonly householdId: string; readonly intent: PlannerDraft["intent"] }>,
): void {
  if (
    draft.householdId !== command.householdId ||
    JSON.stringify(draft.intent) !== JSON.stringify(command.intent)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Private allocation planner returned a mismatched draft",
    )
  }
  if (Date.parse(draft.expiresAt) <= Date.now()) {
    throw new HttpsError(
      "failed-precondition",
      "Private allocation planner returned an expired draft",
    )
  }
}

export function readyDraftData(planned: PlannerDraft): FirebaseFirestore.DocumentData {
  return {
    householdId: planned.householdId,
    listId: planned.listId,
    state: planned.state,
    createdAt: Timestamp.fromDate(new Date(planned.createdAt)),
    expiresAt: Timestamp.fromDate(new Date(planned.expiresAt)),
    contentHash: planned.contentHash,
    intent: planned.intent,
    list: planned.list,
  }
}

export function requireReadyDraft(
  data: FirebaseFirestore.DocumentData | undefined,
  planned: PlannerDraft,
): void {
  if (
    !isReadyDraftData(data) ||
    data.state !== "ready" ||
    data.householdId !== planned.householdId ||
    data.listId !== planned.listId ||
    data.contentHash !== planned.contentHash ||
    Date.parse(data.expiresAt.toDate().toISOString()) <= Date.now() ||
    JSON.stringify(data.intent) !== JSON.stringify(planned.intent) ||
    JSON.stringify(data.list) !== JSON.stringify(planned.list)
  ) {
    throw new HttpsError("failed-precondition", "Shopping allocation draft is not ready")
  }
}

type ReadyDraftData = Readonly<{
  readonly state: unknown
  readonly householdId: unknown
  readonly listId: unknown
  readonly contentHash: unknown
  readonly expiresAt: { readonly toDate: () => Date }
  readonly intent: unknown
  readonly list: unknown
}>

function isReadyDraftData(
  data: FirebaseFirestore.DocumentData | undefined,
): data is ReadyDraftData {
  if (data === undefined) return false
  const { state, householdId, listId, contentHash, expiresAt, intent, list } = data
  return (
    typeof state !== "undefined" &&
    typeof householdId !== "undefined" &&
    typeof listId !== "undefined" &&
    typeof contentHash !== "undefined" &&
    typeof expiresAt === "object" &&
    expiresAt !== null &&
    "toDate" in expiresAt &&
    typeof expiresAt.toDate === "function" &&
    typeof intent !== "undefined" &&
    typeof list !== "undefined"
  )
}
