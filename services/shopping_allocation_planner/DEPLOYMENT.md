# Private deployment contract

Deploy this service as a private Cloud Run service only. Set ingress to internal or internal-and-cloud-load-balancing, require Cloud Run IAM authentication, and grant `roles/run.invoker` solely to the Firebase Functions runtime service account.

The service fails closed unless `PLANNER_FIRESTORE_PROJECT_ID`, `PLANNER_AUDIENCE`, and `PLANNER_CALLER_SERVICE_ACCOUNT` are set. Its workload identity needs read access to `recipes`, recipe ingredients, and the target household's meal-schedule and pantry documents. It does not accept client planning inputs beyond household, list, and inclusive date-range intent.

Functions must set `PLANNER_URL` and `PLANNER_AUDIENCE`; it obtains an ID token from its workload identity for that audience. No static token or shared secret is configured. This repository intentionally contains no deployment command or production resource mutation.
