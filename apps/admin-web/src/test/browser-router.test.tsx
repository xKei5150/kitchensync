import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { AppLink, BrowserHistoryRouter } from "../routing/browserRouter";
import { useBrowserRouter } from "../routing/routerContext";
import { parseAppRoute } from "../routing/routes";

function RouteProbe() {
  const { route } = useBrowserRouter();
  const detail = route.kind === "user-360" ? `:${route.uid}` : "";
  return (
    <>
      <output data-testid="route">{`${route.kind}${detail}`}</output>
      <AppLink to={{ kind: "user-lookup" }}>Open user lookup</AppLink>
    </>
  );
}

function renderRouter(pathname: string) {
  window.history.replaceState(null, "", pathname);
  return render(<BrowserHistoryRouter><RouteProbe /></BrowserHistoryRouter>);
}

describe("typed browser history router", () => {
  beforeEach(() => window.history.replaceState(null, "", "/health"));
  afterEach(() => window.history.replaceState(null, "", "/health"));

  it("parses only the supported static and dynamic routes", () => {
    expect(parseAppRoute("/users/user%3A01")).toEqual({ kind: "user-360", uid: "user:01" });
    expect(parseAppRoute("/households/household-01")).toEqual({ kind: "household-360", householdId: "household-01" });
    expect(parseAppRoute("/entitlements/household-01")).toEqual({ kind: "entitlement", householdId: "household-01" });
    expect(parseAppRoute("/users/user%2F01")).toEqual({ kind: "not-found" });
    expect(parseAppRoute("/users/one/two")).toEqual({ kind: "not-found" });
    expect(parseAppRoute("/users/%E0%A4%A")).toEqual({ kind: "not-found" });
  });

  it("intercepts normal app links and leaves a browser history entry", async () => {
    renderRouter("/health");
    fireEvent.click(screen.getByRole("link", { name: "Open user lookup" }));

    await waitFor(() => expect(screen.getByTestId("route")).toHaveTextContent("user-lookup"));
    expect(window.location.pathname).toBe("/users");
  });

  it("updates for browser back and forward navigation", async () => {
    renderRouter("/health");
    fireEvent.click(screen.getByRole("link", { name: "Open user lookup" }));
    await waitFor(() => expect(screen.getByTestId("route")).toHaveTextContent("user-lookup"));

    await act(async () => { window.history.back(); });
    await waitFor(() => expect(screen.getByTestId("route")).toHaveTextContent("health"));

    await act(async () => { window.history.forward(); });
    await waitFor(() => expect(screen.getByTestId("route")).toHaveTextContent("user-lookup"));
  });

  it("replaces the legacy root address with the health route", async () => {
    renderRouter("/");
    await waitFor(() => expect(window.location.pathname).toBe("/health"));
    expect(screen.getByTestId("route")).toHaveTextContent("health");
  });
});
