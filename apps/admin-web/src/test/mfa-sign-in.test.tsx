import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { SignInPanel } from "../auth/AuthSessionBoundary";
import type { SessionGateway } from "../auth/session";

function createMfaGateway(): SessionGateway {
  return {
    subscribe: vi.fn(() => () => undefined),
    signIn: vi.fn().mockResolvedValue({
      kind: "mfa-required",
      factors: [
        { id: "phone-factor-1", label: "Phone factor 1 ending in **11" },
        { id: "phone-factor-2", label: "Phone factor 2 ending in **22" },
      ],
    }),
    beginPhoneMfa: vi.fn().mockResolvedValue(undefined),
    completePhoneMfa: vi.fn().mockResolvedValue(undefined),
    resetMfaChallenge: vi.fn(),
    cancelMfa: vi.fn(),
    signOut: vi.fn().mockResolvedValue(undefined),
  };
}

describe("phone MFA sign-in", () => {
  it("selects a masked phone factor, requests a code, verifies it, and resets the verifier through the gateway", async () => {
    const user = userEvent.setup();
    const session = createMfaGateway();
    render(<SignInPanel session={session} />);

    await user.type(screen.getByLabelText("Email"), "staff@example.test");
    await user.type(screen.getByLabelText("Password"), "not-a-real-password");
    await user.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByRole("heading", { name: "Verify your second factor" })).toBeVisible();
    await user.click(screen.getByRole("radio", { name: "Phone factor 2 ending in **22" }));
    await user.click(screen.getByRole("button", { name: "Send verification code" }));
    expect(session.beginPhoneMfa).toHaveBeenCalledWith("phone-factor-2", expect.any(HTMLDivElement));

    await user.type(screen.getByLabelText("Verification code"), "123456");
    await user.click(screen.getByRole("button", { name: "Verify and sign in" }));
    expect(session.completePhoneMfa).toHaveBeenCalledWith("123456");

    await user.click(screen.getByRole("button", { name: "Send a new code" }));
    expect(session.resetMfaChallenge).toHaveBeenCalledTimes(1);
  });
});
