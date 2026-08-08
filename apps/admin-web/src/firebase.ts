import { getApp, getApps, initializeApp, type FirebaseApp } from "firebase/app";
import { initializeAppCheck, ReCaptchaEnterpriseProvider, type AppCheckOptions } from "firebase/app-check";
import { getAuth } from "firebase/auth";
import { getFunctions } from "firebase/functions";
import { createFirebaseAdminApi, type AdminApi } from "./api/callable";
import { createFirebaseSessionGateway, type SessionGateway } from "./auth/session";
import type { RuntimeConfig } from "./config/runtime";

export interface FirebaseConsoleServices {
  readonly session: SessionGateway;
  readonly api: AdminApi;
}

export interface AppCheckInitializationDependencies {
  readonly createProvider: (siteKey: string) => AppCheckOptions["provider"];
  readonly initialize: (app: FirebaseApp, options: AppCheckOptions) => void;
}

const firebaseAppCheckDependencies: AppCheckInitializationDependencies = {
  createProvider: (siteKey) => new ReCaptchaEnterpriseProvider(siteKey),
  initialize: (app, options) => { initializeAppCheck(app, options); },
};

const appCheckInitializedApps = new Set<string>();

export function initializeAppCheckForApp(
  app: FirebaseApp,
  siteKey: string,
  dependencies: AppCheckInitializationDependencies = firebaseAppCheckDependencies,
): void {
  if (appCheckInitializedApps.has(app.name)) return;
  dependencies.initialize(app, {
    provider: dependencies.createProvider(siteKey),
    isTokenAutoRefreshEnabled: true,
  });
  appCheckInitializedApps.add(app.name);
}

/**
 * This module intentionally initializes only Auth and Functions. Firestore and
 * Storage client SDKs are not dependencies of the admin console boundary.
 */
export function createFirebaseConsoleServices(config: RuntimeConfig): FirebaseConsoleServices | null {
  if (config.configurationError || !config.firebase) return null;
  const existing = getApps().find((candidate) => candidate.options.appId === config.firebase?.appId);
  const app = existing ? getApp(existing.name) : initializeApp(config.firebase, "kitchensync-admin-web");
  try {
    // App Check is deliberately activated before Functions so every callable can carry a token.
    initializeAppCheckForApp(app, config.appCheckSiteKey);
  } catch {
    return null;
  }
  return {
    session: createFirebaseSessionGateway(getAuth(app)),
    api: createFirebaseAdminApi(getFunctions(app, config.functionsRegion), config.apiVersion),
  };
}
