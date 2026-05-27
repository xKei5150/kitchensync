# Seed uploader

Uploads `assets/seed/ingredients.json` to Firestore via the Firebase Admin SDK.

## Authentication

Two options — the uploader prefers a key file, then falls back to ADC.

### Option A (recommended): Application Default Credentials — no key file

`flutterfire`/`firebase login` do **not** provide an Admin SDK key. Instead,
authenticate with gcloud once (this writes ADC to `~/.config/gcloud`):

```bash
gcloud auth application-default login
```

The uploader then uses ADC automatically (project id is baked in per env).

### Option B: service-account key file

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
