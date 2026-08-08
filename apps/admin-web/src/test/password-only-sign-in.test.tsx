import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { AuthSessionBoundary, SignInPanel } from "../auth/AuthSessionBoundary";
import { PasswordOnlySignInError, createFirebaseSessionGateway, type SessionGateway } from "../auth/session";
import type { AdminApi } from "../api/callable";
import { health, testConfig } from "./fixtures";

function passwordOnlyMock(overrides: Partial<SessionGateway> = {}): SessionGateway {
  return {
    subscribe: vi.fn((listener) => {
      listener(null);
      return () => undefined;
    }),
    signIn: vi.fn().mockRejectedValue({ code: "auth/multi-factor-auth-required" }),
    signOut: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

describe("password-only staff sign-in", () => {
  it("maps a Firebase MFA-required response to a generic gateway error", async () => {
    const auth = {} as Parameters<typeof createFirebaseSessionGateway>[0];
    const gateway = createFirebaseSessionGateway(auth, {
      signInWithEmailAndPassword: vi.fn().mockRejectedValue({ code: "auth/multi-factor-auth-required" }),
    });

    await expect(gateway.signIn("staff@example.test", "password")).rejects.toBeInstanceOf(PasswordOnlySignInError);
    await expect(gateway.signIn("staff@example.test", "password")).rejects.toThrow("Sign-in could not be completed.");
  });

  it("shows only the generic password failure and never exposes protected or alternate-factor UI", async () => {
    const user = userEvent.setup();
    render(<SignInPanel session={passwordOnlyMock()} />);

    await user.type(screen.getByLabelText("Email"), "staff@example.test");
    await user.type(screen.getByLabelText("Password"), "not-a-real-password");
    await user.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Sign-in could not be completed.");
    expect(screen.queryByText(/second factor|phone factor|verification code/i)).not.toBeInTheDocument();
    expect(screen.queryByText("protected console")).not.toBeInTheDocument();
  });

  it("keeps the protected boundary closed when password sign-in fails with MFA-required", async () => {
    const user = userEvent.setup();
    const session = passwordOnlyMock();
    const api: AdminApi = {
      health: vi.fn().mockResolvedValue(health),
      getUser360: vi.fn(),
      getHousehold360: vi.fn(),
      getEntitlementDiagnostics: vi.fn(),
    };
    render(<AuthSessionBoundary config={testConfig} session={session} api={api}><p>protected console</p></AuthSessionBoundary>);

    await user.type(screen.getByLabelText("Email"), "staff@example.test");
    await user.type(screen.getByLabelText("Password"), "not-a-real-password");
    await user.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Sign-in could not be completed.");
    expect(screen.queryByText("protected console")).not.toBeInTheDocument();
  });
});
