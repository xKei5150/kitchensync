import { describe, expect, it } from "vitest";
import { isAppCheckSiteKey, isFirebaseWebAppId, readRuntimeConfig } from "../config/runtime";

const validEnvironment = {
  VITE_ADMIN_ENV: "development",
  VITE_FIREBASE_PROJECT_ID: "kitchensync-dev-da503",
  VITE_EXPECTED_PROJECT_ID: "kitchensync-dev-da503",
  VITE_FIREBASE_API_KEY: "public-key",
  VITE_FIREBASE_AUTH_DOMAIN: "kitchensync-dev-da503.firebaseapp.com",
  VITE_FIREBASE_APP_ID: "1:733234753301:web:d390bfa8a5323514f7c31c",
  VITE_APP_CHECK_SITE_KEY: "6Le2eAdminWebAppCheckScoreKey1234567890",
  VITE_FUNCTIONS_REGION: "us-central1",
  VITE_ADMIN_API_VERSION: "v1",
  VITE_APP_VERSION: "0.1.0-test",
};

describe("runtime security configuration", () => {
  it("accepts a Web App ID and score-based App Check site key only in the expected formats", () => {
    expect(isFirebaseWebAppId(validEnvironment.VITE_FIREBASE_APP_ID)).toBe(true);
    expect(isFirebaseWebAppId("1:733234753301:android:invalid")).toBe(false);
    expect(isAppCheckSiteKey(validEnvironment.VITE_APP_CHECK_SITE_KEY)).toBe(true);
    expect(isAppCheckSiteKey("not-a-site-key")).toBe(false);
  });

  it("fails closed when the App Check key or Web App ID is missing or malformed", () => {
    expect(readRuntimeConfig(validEnvironment).configurationError).toBeNull();
    expect(readRuntimeConfig({ ...validEnvironment, VITE_APP_CHECK_SITE_KEY: "" }).configurationError).toContain("App Check site key");
    expect(readRuntimeConfig({ ...validEnvironment, VITE_FIREBASE_APP_ID: "1:733234753301:android:bad" }).configurationError).toContain("Firebase Web App ID");
  });
});
