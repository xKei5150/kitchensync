import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { HEALTH_REVALIDATION_INTERVAL_MS, AuthSessionBoundary } from "../auth/AuthSessionBoundary";
import type { AdminApi } from "../api/callable";
import type { CallableEnvelope, HealthDto } from "../api/dtos";
import type { SessionGateway, SessionUser } from "../auth/session";
import { health, testConfig } from "./fixtures";

interface ControlledSession {
  readonly gateway: SessionGateway;
  emit(user: SessionUser | null): void;
}

function createControlledSession(): ControlledSession {
  let listener: ((user: SessionUser | null) => void) | undefined;
  return {
    gateway: {
      subscribe(next) { listener = next; return () => { listener = undefined; }; },
      signIn: vi.fn().mockResolvedValue({ kind: "signed-in" }),
      signOut: vi.fn().mockResolvedValue(undefined),
    },
    emit(user) { listener?.(user); },
  };
}

function createApi(healthRequest: () => Promise<CallableEnvelope<HealthDto>>): AdminApi {
  return {
    health: vi.fn(healthRequest),
    getUser360: vi.fn(),
    getHousehold360: vi.fn(),
    getEntitlementDiagnostics: vi.fn(),
  };
}

function healthFor(uid: string): CallableEnvelope<HealthDto> {
  return { ...health, data: { ...health.data, staff: { ...health.data.staff, uid } } };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

afterEach(() => vi.useRealTimers());

describe("staff session security boundary", () => {
  it("ignores a stale health result after the authenticated user changes", async () => {
    const first = deferred<CallableEnvelope<HealthDto>>();
    const second = deferred<CallableEnvelope<HealthDto>>();
    const controlled = createControlledSession();
    const api = createApi(vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise));
    render(<AuthSessionBoundary config={testConfig} session={controlled.gateway} api={api}><p>protected console</p></AuthSessionBoundary>);

    act(() => controlled.emit({ uid: "staff-01", email: "first@example.test" }));
    act(() => controlled.emit({ uid: "staff-02", email: "second@example.test" }));
    await act(async () => { second.resolve(healthFor("staff-02")); await second.promise; });
    expect(await screen.findByText("protected console")).toBeVisible();

    await act(async () => { first.resolve(healthFor("staff-01")); await first.promise; });
    expect(screen.getByText("protected console")).toBeVisible();
    expect(screen.queryByText("This account cannot access the administration console.")).not.toBeInTheDocument();
  });

  it("revalidates on focus and the bounded interval without concurrent duplicate requests", async () => {
    vi.useFakeTimers();
    const controlled = createControlledSession();
    const api = createApi(vi.fn().mockResolvedValue(health));
    render(<AuthSessionBoundary config={testConfig} session={controlled.gateway} api={api}><p>protected console</p></AuthSessionBoundary>);

    act(() => controlled.emit({ uid: "staff-01", email: "staff@example.test" }));
    await act(async () => { await Promise.resolve(); });
    expect(screen.getByText("protected console")).toBeVisible();

    act(() => {
      fireEvent.focus(window);
      fireEvent.focus(window);
    });
    await act(async () => { await Promise.resolve(); });
    expect(api.health).toHaveBeenCalledTimes(2);

    act(() => vi.advanceTimersByTime(HEALTH_REVALIDATION_INTERVAL_MS));
    await act(async () => { await Promise.resolve(); });
    expect(api.health).toHaveBeenCalledTimes(3);
  });

  it("clears the protected view and signs out before requiring a fresh password sign-in", async () => {
    const user = userEvent.setup();
    const controlled = createControlledSession();
    const api = createApi(vi.fn().mockRejectedValue(new Error("denied")));
    render(<AuthSessionBoundary config={testConfig} session={controlled.gateway} api={api}><p>protected console</p></AuthSessionBoundary>);

    act(() => controlled.emit({ uid: "staff-01", email: "staff@example.test" }));
    await screen.findByText("This account cannot access the administration console.");
    await user.click(screen.getByRole("button", { name: "Sign out and sign in again" }));

    await waitFor(() => expect(controlled.gateway.signOut).toHaveBeenCalledTimes(1));
    expect(screen.queryByText("protected console")).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Sign in with your staff account" })).toBeVisible();
  });
});
