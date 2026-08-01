import { defineConfig, devices } from "@playwright/test";

const localRuntimeEnvironment = {
  VITE_ADMIN_ENV: "preview",
  VITE_FIREBASE_PROJECT_ID: "kitchensync-e2e",
  VITE_EXPECTED_PROJECT_ID: "kitchensync-e2e",
  VITE_FIREBASE_API_KEY: "e2e-public-placeholder",
  VITE_FIREBASE_AUTH_DOMAIN: "kitchensync-dev-da503.firebaseapp.com",
  VITE_FIREBASE_APP_ID: "1:1234567890:web:e2eadminweb",
  VITE_APP_CHECK_SITE_KEY: "6Le2eAdminWebAppCheckScoreKey1234567890",
  VITE_FUNCTIONS_REGION: "us-central1",
  VITE_ADMIN_API_VERSION: "e2e-v1",
  VITE_APP_VERSION: "e2e-0.1.0",
} as const;

const runtimeEnvironment = Object.entries(localRuntimeEnvironment)
  .map(([key, value]) => `${key}=${value}`)
  .join(" ");

export default defineConfig({
  testDir: "./e2e",
  outputDir: "test-results",
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : undefined,
  preserveOutput: "always",
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:4173",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium-desktop",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "chromium-mobile",
      use: { ...devices["Pixel 5"] },
    },
  ],
  webServer: {
    command: `${runtimeEnvironment} npm run build && ${runtimeEnvironment} npm run preview -- --host 127.0.0.1 --port 4173 --strictPort`,
    url: "http://127.0.0.1:4173",
    reuseExistingServer: false,
  },
});
