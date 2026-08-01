import { render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AuthSessionBoundary } from "../auth/AuthSessionBoundary";
import type { AdminApi } from "../api/callable";
import type { SessionGateway, SessionUser } from "../auth/session";
import { health, testConfig } from "./fixtures";

function createSession(user: SessionUser | null): SessionGateway {
  return {
    subscribe(listener) { listener(user); return () => undefined; },
    signIn: vi.fn().mockResolvedValue({ kind: "signed-in" }),
    beginPhoneMfa: vi.fn().mockResolvedValue(undefined),
    completePhoneMfa: vi.fn().mockResolvedValue(undefined),
    resetMfaChallenge: vi.fn(),
    cancelMfa: vi.fn(),
    signOut: vi.fn().mockResolvedValue(undefined),
  };
}

function createApi(healthResult: unknown): AdminApi {
  return {
    health: vi.fn().mockResolvedValue(healthResult),
    getUser360: vi.fn(),
    getHousehold360: vi.fn(),
    getEntitlementDiagnostics: vi.fn(),
  };
}

describe("AuthSessionBoundary", () => {
  it("admits only a signed-in session with a matching enabled staff health response", async () => {
    render(
      <AuthSessionBoundary config={testConfig} session={createSession({ uid: "staff-01", email: "staff@example.test" })} api={createApi(health)}>
        <p>protected console</p>
      </AuthSessionBoundary>,
    );

    expect(await screen.findByText("protected console")).toBeVisible();
  });

  it("denies access when the callable staff evidence is missing or malformed", async () => {
    render(
      <AuthSessionBoundary config={testConfig} session={createSession({ uid: "staff-01", email: "staff@example.test" })} api={createApi({ requestId: "srv_bad_12345", data: {} })}>
        <p>protected console</p>
      </AuthSessionBoundary>,
    );

    await waitFor(() => expect(screen.getByText("This account cannot access the administration console.")).toBeVisible());
    expect(screen.queryByText("protected console")).not.toBeInTheDocument();
  });

  it("shows the sign-in boundary without a Firebase session", async () => {
    render(<AuthSessionBoundary config={testConfig} session={createSession(null)} api={createApi(health)}><p>protected console</p></AuthSessionBoundary>);
    expect(await screen.findByRole("heading", { name: "Sign in with your staff account" })).toBeVisible();
  });
});
