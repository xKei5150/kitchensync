#!/usr/bin/env bash
#
# Deploys the private shopping allocation planner (services/shopping_allocation_planner)
# to Cloud Run on the DEV project and wires planShoppingAllocation to it.
#
# Safe to re-run (idempotent). Authenticates gcloud via the owner ADC token, so
# no `gcloud auth login` is needed. Run from the repo root:
#   bash tools/deploy-planner-dev.sh
#
set -euo pipefail

PROJECT="kitchensync-dev-da503"
PROJECT_NUMBER="733234753301"
REGION="us-central1"
SERVICE="shopping-allocation-planner"
REPO="kitchensync-services"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${SERVICE}:latest"

# Dedicated least-privilege runtime identity for the planner (Firestore read only).
PLANNER_SA="ks-shopping-planner@${PROJECT}.iam.gserviceaccount.com"
# The Firebase Functions gen2 runtime identity — the only allowed caller.
FUNCTIONS_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
# Cloud Run deterministic URL (verified against the live deploy below).
URL="https://${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"

export CLOUDSDK_AUTH_ACCESS_TOKEN="$(gcloud auth application-default print-access-token)"
export CLOUDSDK_CORE_PROJECT="$PROJECT"

echo "==> 1/8 Enable APIs (no-op if already enabled)"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com firestore.googleapis.com --project "$PROJECT"

echo "==> 2/8 Planner runtime service account"
gcloud iam service-accounts create ks-shopping-planner \
  --display-name="Shopping allocation planner runtime" --project "$PROJECT" \
  || echo "   (already exists)"
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:${PLANNER_SA}" \
  --role="roles/datastore.viewer" --condition=None >/dev/null
echo "   granted roles/datastore.viewer to ${PLANNER_SA}"

echo "==> 3/8 Artifact Registry repo"
gcloud artifacts repositories create "$REPO" \
  --repository-format=docker --location="$REGION" \
  --description="KitchenSync backing services" --project "$PROJECT" \
  || echo "   (already exists)"

echo "==> 4/8 Build image via Cloud Build (Flutter image — a few minutes)"
gcloud builds submit \
  --config services/shopping_allocation_planner/cloudbuild.yaml \
  --substitutions=_IMAGE="$IMAGE" \
  --project "$PROJECT" .

echo "==> 5/8 Deploy PRIVATE Cloud Run service"
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --project "$PROJECT" \
  --no-allow-unauthenticated \
  --ingress internal \
  --service-account "$PLANNER_SA" \
  --set-env-vars "PLANNER_FIRESTORE_PROJECT_ID=${PROJECT},PLANNER_AUDIENCE=${URL},PLANNER_CALLER_SERVICE_ACCOUNT=${FUNCTIONS_SA}"

echo "==> 6/8 Grant run.invoker to the Functions runtime SA only"
gcloud run services add-iam-policy-binding "$SERVICE" \
  --region "$REGION" --project "$PROJECT" \
  --member="serviceAccount:${FUNCTIONS_SA}" \
  --role="roles/run.invoker" >/dev/null

ACTUAL_URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" --format='value(status.url)')"
echo "   service URL: $ACTUAL_URL"
if [ "$ACTUAL_URL" != "$URL" ]; then
  echo "   WARNING: actual URL differs from predicted ($URL). Using actual."
  URL="$ACTUAL_URL"
  echo "   Re-setting PLANNER_AUDIENCE on the service to the actual URL..."
  gcloud run services update "$SERVICE" --region "$REGION" --project "$PROJECT" \
    --update-env-vars "PLANNER_AUDIENCE=${URL}"
fi

echo "==> 7/8 Point the function at the planner (functions env) and redeploy"
cat > functions/.env."${PROJECT}" <<ENV
PLANNER_URL=${URL}
PLANNER_AUDIENCE=${URL}
ENV
echo "   wrote functions/.env.${PROJECT}"
tools/firebase-gates/firebase.sh deploy --project "$PROJECT" \
  --only functions:planShoppingAllocation --non-interactive

echo "==> 8/8 Done. Verify: generate a shopping list in the app; tail logs with:"
echo "   tools/firebase-gates/firebase.sh functions:log --only planShoppingAllocation --project ${PROJECT}"
