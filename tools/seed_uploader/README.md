# Seed uploader

Uploads `assets/seed/ingredients.json` to Firestore via the Firebase Admin SDK.

## Service account

Per env:
1. Firebase Console -> kitchensync-dev (or prod) -> Project Settings -> Service Accounts
2. "Generate new private key" -> save as `service-account-dev.json` (or `-prod.json`) in this folder.
3. **Confirm `.gitignore` blocks it** — `tools/seed_uploader/service-account*.json` is gitignored
   except for `service-account.example.json`.

## Run

```bash
cd tools/seed_uploader
npm install
npm run upload:dev      # uploads to kitchensync-dev
npm run upload:prod     # uploads to kitchensync-prod (do not run by mistake)
```

Idempotent — uses `merge: true`. Safe to re-run after edits.
