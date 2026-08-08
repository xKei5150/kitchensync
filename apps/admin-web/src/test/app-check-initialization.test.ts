import { describe, expect, it, vi } from "vitest";
import type { FirebaseApp } from "firebase/app";
import type { AppCheckOptions } from "firebase/app-check";
import { initializeAppCheckForApp } from "../firebase";

describe("App Check initialization seam", () => {
  it("constructs the provider and enables token auto-refresh before service construction", () => {
    const provider = {} as AppCheckOptions["provider"];
    const createProvider = vi.fn().mockReturnValue(provider);
    const initialize = vi.fn();
    const app = { name: "unit-test-app-check-seam" } as FirebaseApp;

    initializeAppCheckForApp(app, "6Le2eAdminWebAppCheckScoreKey1234567890", { createProvider, initialize });

    expect(createProvider).toHaveBeenCalledWith("6Le2eAdminWebAppCheckScoreKey1234567890");
    expect(initialize).toHaveBeenCalledWith(app, { provider, isTokenAutoRefreshEnabled: true });
  });
});
