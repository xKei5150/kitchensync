import { initializeApp } from "firebase-admin/app"
import { getFirestore } from "firebase-admin/firestore"
import { backfillAccountLifecycleSchema } from "../dist/accountLifecycleBackfill.js"

const apply = process.argv.includes("--apply")
const allowConflicts = process.argv.includes("--allow-conflicts")
const projectId = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT
initializeApp(projectId === undefined ? undefined : { projectId })

const report = await backfillAccountLifecycleSchema(getFirestore(), { apply, allowConflicts })
console.log(JSON.stringify(report, null, 2))
if (!apply) {
  console.log("Dry run only. Re-run with --apply after reviewing conflicts.")
}
