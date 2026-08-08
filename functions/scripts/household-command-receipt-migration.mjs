import { initializeApp } from "firebase-admin/app"
import { getFirestore } from "firebase-admin/firestore"
import { accountLifecycleReceiptHmacKeyFromRuntimeSecret } from "../dist/accountLifecycle.js"
import { migrateLegacyHouseholdCommandReceipts } from "../dist/householdCommandReceipt.js"

const apply = process.argv.includes("--apply")
const allowConflicts = process.argv.includes("--allow-conflicts")
const secret = process.env.ACCOUNT_LIFECYCLE_RECEIPT_HMAC_KEY
if (typeof secret !== "string" || secret.length === 0) {
  throw new Error("ACCOUNT_LIFECYCLE_RECEIPT_HMAC_KEY is required")
}

initializeApp()
const pageSizeArgument = process.argv.find((argument) => argument.startsWith("--page-size="))
const maxRecordsArgument = process.argv.find((argument) => argument.startsWith("--max-records="))
const migrationIdArgument = process.argv.find((argument) => argument.startsWith("--migration-id="))
const pageSize = pageSizeArgument === undefined ? undefined : Number(pageSizeArgument.split("=")[1])
const maxRecords =
  maxRecordsArgument === undefined ? undefined : Number(maxRecordsArgument.split("=")[1])
const migrationId =
  migrationIdArgument === undefined ? undefined : migrationIdArgument.split("=")[1]
const summary = await migrateLegacyHouseholdCommandReceipts(
  getFirestore(),
  {
    receiptHmacKey: () => accountLifecycleReceiptHmacKeyFromRuntimeSecret(secret),
  },
  {
    apply,
    allowConflicts,
    ...(pageSize === undefined ? {} : { pageSize }),
    ...(maxRecords === undefined ? {} : { maxRecords }),
    ...(migrationId === undefined ? {} : { migrationId }),
  },
)
console.info(JSON.stringify({ apply, allowConflicts, ...summary }))
