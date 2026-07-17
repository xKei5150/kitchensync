import { getApps, initializeApp } from "firebase-admin/app"
import { getFirestore } from "firebase-admin/firestore"

const adminApp = getApps().at(0) ?? initializeApp()

export const firestore = getFirestore(adminApp)
