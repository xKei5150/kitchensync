import { expect, test, type Page, type TestInfo } from "@playwright/test";

const TEST_ONLY_UNREGISTERED_APP_CHECK_DEBUG_TOKEN = "e2e-unregistered-app-check-debug-token";

test.beforeEach(async ({ page }) => {
  await page.addInitScript((token) => {
    // This test-only pre-navigation value is intentionally absent from application source.
    (window as Window & { FIREBASE_APPCHECK_DEBUG_TOKEN?: string }).FIREBASE_APPCHECK_DEBUG_TOKEN = token;
  }, TEST_ONLY_UNREGISTERED_APP_CHECK_DEBUG_TOKEN);
});

interface BrowserErrors {
  readonly errors: string[];
  getExpectedAppCheckDebugRejections(): number;
}

function collectConsoleErrors(page: Page): BrowserErrors {
  const errors: string[] = [];
  let expectedAppCheckDebugRejections = 0;
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", (response) => {
    if (response.status() === 400 && response.url().startsWith("https://content-firebaseappcheck.googleapis.com/")) {
      expectedAppCheckDebugRejections += 1;
    }
  });
  return { errors, getExpectedAppCheckDebugRejections: () => expectedAppCheckDebugRejections };
}

function expectNoUnexpectedConsoleErrors(browserErrors: BrowserErrors): void {
  // Chromium reports this no-op meta-CSP warning before application code runs.
  const expectedBrowserCspWarning = "The Content Security Policy directive 'frame-ancestors' is ignored when delivered via a <meta> element.";
  const allowedConsoleErrors = [expectedBrowserCspWarning];
  const expectedDebugRejections = browserErrors.getExpectedAppCheckDebugRejections();
  expect(browserErrors.errors.filter((error) => {
    if (allowedConsoleErrors.some((expected) => error.startsWith(expected))) return false;
    return !(expectedDebugRejections > 0 && error === "Failed to load resource: the server responded with a status of 400 ()");
  })).toEqual([]);
}

async function expectSignInBoundary(page: Page): Promise<void> {
  await expect(page.getByRole("heading", { name: "Sign in with your staff account" })).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Administration navigation" })).toHaveCount(0);
  await expect(page.locator("#main-content")).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "User 360" })).toHaveCount(0);
}

async function expectPrimaryUiToFitWithoutOverlap(page: Page): Promise<void> {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);

  const banner = await page.getByLabel("Build environment").boundingBox();
  const boundary = await page.locator("main.boundary-page").boundingBox();
  expect(banner).not.toBeNull();
  expect(boundary).not.toBeNull();
  expect(boundary!.y).toBeGreaterThanOrEqual(banner!.y + banner!.height);
}

async function attachScreenshot(page: Page, testInfo: TestInfo): Promise<void> {
  const screenshotPath = testInfo.outputPath(`unauthenticated-boundary-${testInfo.project.name}.png`);
  await page.screenshot({ path: screenshotPath, fullPage: true });
  await testInfo.attach(`unauthenticated-boundary-${testInfo.project.name}.png`, {
    path: screenshotPath,
    contentType: "image/png",
  });
}

test("renders build signals and fails closed before any customer view", async ({ page }, testInfo) => {
  const consoleErrors = collectConsoleErrors(page);

  await page.goto("/users/non-customer-route-id");

  const buildEnvironment = page.getByLabel("Build environment");
  await expect(buildEnvironment).toContainText("Preview");
  await expect(buildEnvironment).toContainText("Project");
  await expect(buildEnvironment).toContainText("kitchensync-e2e");
  await expect(buildEnvironment).toContainText("API");
  await expect(buildEnvironment).toContainText("e2e-v1");
  await expect(buildEnvironment).toContainText("App");
  await expect(buildEnvironment).toContainText("e2e-0.1.0");
  await expectSignInBoundary(page);
  await attachScreenshot(page, testInfo);

  await page.waitForTimeout(250);
  expectNoUnexpectedConsoleErrors(consoleErrors);
});

test("unknown and malformed direct routes remain bounded at the sign-in boundary", async ({ page }) => {
  const consoleErrors = collectConsoleErrors(page);

  for (const path of ["/not-a-console-route", "/users/%2Fnot-a-path-segment"]) {
    await page.goto(path);
    await expectSignInBoundary(page);
    await expectPrimaryUiToFitWithoutOverlap(page);
  }

  await page.waitForTimeout(250);
  expectNoUnexpectedConsoleErrors(consoleErrors);
});
