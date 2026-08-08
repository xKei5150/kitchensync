import type { FirebaseOptions } from "firebase/app";

export type AdminEnvironment = "development" | "preview" | "production";

export interface RuntimeConfig {
  readonly environment: AdminEnvironment;
  readonly projectId: string;
  readonly expectedProjectId: string;
  readonly apiVersion: string;
  readonly appVersion: string;
  readonly functionsRegion: string;
  readonly appCheckSiteKey: string;
  readonly firebase: FirebaseOptions | null;
  readonly configurationError: string | null;
}

type PublicEnvironment = Record<string, string | boolean | undefined>;

const PROJECT_ID_PATTERN = /^[a-z][a-z0-9-]{4,62}$/;
const VERSION_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const REGION_PATTERN = /^[a-z]+-[a-z]+[0-9]$/;
const FIREBASE_WEB_APP_ID_PATTERN = /^1:\d+:web:[A-Za-z0-9_-]{8,128}$/;
const APP_CHECK_SITE_KEY_PATTERN = /^6L[A-Za-z0-9_-]{20,255}$/;

function value(environment: PublicEnvironment, key: string): string {
  const candidate = environment[key];
  return typeof candidate === "string" ? candidate.trim() : "";
}

function parseEnvironment(raw: string): AdminEnvironment | null {
  if (raw === "development" || raw === "preview" || raw === "production") {
    return raw;
  }
  return null;
}

export function readRuntimeConfig(environment: PublicEnvironment): RuntimeConfig {
  const parsedEnvironment = parseEnvironment(value(environment, "VITE_ADMIN_ENV"));
  const projectId = value(environment, "VITE_FIREBASE_PROJECT_ID");
  const expectedProjectId = value(environment, "VITE_EXPECTED_PROJECT_ID");
  const apiVersion = value(environment, "VITE_ADMIN_API_VERSION");
  const appVersion = value(environment, "VITE_APP_VERSION");
  const functionsRegion = value(environment, "VITE_FUNCTIONS_REGION") || "us-central1";
  const apiKey = value(environment, "VITE_FIREBASE_API_KEY");
  const authDomain = value(environment, "VITE_FIREBASE_AUTH_DOMAIN");
  const appId = value(environment, "VITE_FIREBASE_APP_ID");
  const appCheckSiteKey = value(environment, "VITE_APP_CHECK_SITE_KEY");

  const errors: string[] = [];
  if (!parsedEnvironment) errors.push("Environment is not configured.");
  if (!PROJECT_ID_PATTERN.test(projectId)) errors.push("Project ID is not configured.");
  if (!PROJECT_ID_PATTERN.test(expectedProjectId)) errors.push("Expected project ID is not configured.");
  if (projectId !== expectedProjectId) errors.push("Project identity does not match this build.");
  if (!VERSION_PATTERN.test(apiVersion)) errors.push("API version is not configured.");
  if (!VERSION_PATTERN.test(appVersion)) errors.push("Application version is not configured.");
  if (!REGION_PATTERN.test(functionsRegion) || functionsRegion !== "us-central1") errors.push("Functions region is not configured.");
  if (!FIREBASE_WEB_APP_ID_PATTERN.test(appId)) errors.push("Firebase Web App ID is not configured.");
  if (!APP_CHECK_SITE_KEY_PATTERN.test(appCheckSiteKey)) errors.push("App Check site key is not configured.");
  if (!apiKey || !authDomain || !appId) errors.push("Firebase web configuration is incomplete.");

  const firebase = apiKey && authDomain && appId && projectId
    ? { apiKey, authDomain, appId, projectId }
    : null;

  return {
    environment: parsedEnvironment ?? "development",
    projectId: projectId || "not-configured",
    expectedProjectId: expectedProjectId || "not-configured",
    apiVersion: apiVersion || "not-configured",
    appVersion: appVersion || "not-configured",
    functionsRegion,
    appCheckSiteKey,
    firebase,
    configurationError: errors.length > 0 ? errors.join(" ") : null,
  };
}

export function isFirebaseWebAppId(value: string): boolean {
  return FIREBASE_WEB_APP_ID_PATTERN.test(value);
}

export function isAppCheckSiteKey(value: string): boolean {
  return APP_CHECK_SITE_KEY_PATTERN.test(value);
}

export const runtimeConfig = readRuntimeConfig(import.meta.env);
