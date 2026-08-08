import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

interface HostingConfig {
  readonly hosting: {
    readonly headers: readonly {
      readonly source: string;
      readonly headers: readonly { readonly key: string; readonly value: string }[];
    }[];
  };
}

function readJson(path: string): HostingConfig {
  return JSON.parse(readFileSync(new URL(path, import.meta.url), "utf8")) as HostingConfig;
}

function csp(config: HostingConfig): string {
  const allRoutes = config.hosting.headers.find((header) => header.source === "**");
  const value = allRoutes?.headers.find((header) => header.key === "Content-Security-Policy")?.value;
  if (!value) throw new Error("Missing Content-Security-Policy header.");
  return value;
}

function indexCachePolicy(config: HostingConfig): string | undefined {
  return config.hosting.headers
    .find((header) => header.source === "/index.html")
    ?.headers.find((header) => header.key === "Cache-Control")?.value;
}

function expectSharedCspControls(value: string): void {
  expect(value).toContain("https://identitytoolkit.googleapis.com");
  expect(value).toContain("https://securetoken.googleapis.com");
  expect(value).toContain("https://content-firebaseappcheck.googleapis.com");
  expect(value).toContain("https://www.google.com");
  expect(value).toContain("https://www.gstatic.com");
  expect(value).toContain("https://www.recaptcha.net");
  expect(value).toContain("frame-ancestors 'none'");
  expect(value).not.toMatch(/\*\.googleapis|\*\.cloudfunctions|firebaseio|unsafe-inline|unsafe-eval/);
}

describe("environment-specific Hosting CSP", () => {
  it("keeps root/default, explicit dev, and local app Hosting dev-only", () => {
    const configs = [
      readJson("../../../../firebase.json"),
      readJson("../../../../firebase.dev.json"),
      readJson("../../firebase.json"),
    ];
    for (const config of configs) {
      const value = csp(config);
      expectSharedCspControls(value);
      expect(value).toContain("https://us-central1-kitchensync-dev-da503.cloudfunctions.net");
      expect(value).toContain("https://kitchensync-dev-da503.firebaseapp.com");
      expect(value).not.toContain("kitchensync-prod-8d6fd");
      expect(indexCachePolicy(config)).toBe("no-store");
    }
  });

  it("keeps the production Hosting config production-only", () => {
    const production = readJson("../../../../firebase.prod.json");
    const value = csp(production);
    expectSharedCspControls(value);
    expect(value).toContain("https://us-central1-kitchensync-prod-8d6fd.cloudfunctions.net");
    expect(value).toContain("https://kitchensync-prod-8d6fd.firebaseapp.com");
    expect(value).not.toContain("kitchensync-dev-da503");
    expect(indexCachePolicy(production)).toBe("no-store");
  });
});
