import { Component, type ErrorInfo, type ReactNode } from "react";
import type { AdminApi } from "./api/callable";
import { AuthSessionBoundary } from "./auth/AuthSessionBoundary";
import type { SessionGateway } from "./auth/session";
import { AppShell } from "./components/AppShell";
import { EnvironmentBanner } from "./components/EnvironmentBanner";
import type { RuntimeConfig } from "./config/runtime";
import { BrowserHistoryRouter } from "./routing/browserRouter";
import { useBrowserRouter } from "./routing/routerContext";
import { EntitlementLookupScreen, EntitlementScreen, HealthScreen, Household360Screen, HouseholdLookupScreen, NotFoundScreen, User360Screen, UserLookupScreen } from "./screens/Screens";

interface ConsoleApplicationProps {
  readonly config: RuntimeConfig;
  readonly session: SessionGateway | null;
  readonly api: AdminApi | null;
}

export function ConsoleApplication({ config, session, api }: ConsoleApplicationProps) {
  return (
    <>
      <EnvironmentBanner config={config} />
      <AuthSessionBoundary config={config} session={session} api={api}>
        {session && api ? (
          <AppShell>
            <ConsoleRoutes api={api} />
          </AppShell>
        ) : null}
      </AuthSessionBoundary>
    </>
  );
}

export function App(props: ConsoleApplicationProps) {
  return <BrowserHistoryRouter><ConsoleApplication {...props} /></BrowserHistoryRouter>;
}

function ConsoleRoutes({ api }: { readonly api: AdminApi }) {
  const { route } = useBrowserRouter();
  switch (route.kind) {
    case "root":
    case "health": return <HealthScreen />;
    case "user-lookup": return <UserLookupScreen />;
    case "user-360": return <User360Screen api={api} uid={route.uid} />;
    case "household-lookup": return <HouseholdLookupScreen />;
    case "household-360": return <Household360Screen api={api} householdId={route.householdId} />;
    case "entitlement-lookup": return <EntitlementLookupScreen />;
    case "entitlement": return <EntitlementScreen api={api} householdId={route.householdId} />;
    case "not-found": return <NotFoundScreen />;
  }
}

interface SafeAppErrorBoundaryState {
  readonly hasError: boolean;
}

export class SafeAppErrorBoundary extends Component<{ readonly children: ReactNode }, SafeAppErrorBoundaryState> {
  public override state: SafeAppErrorBoundaryState = { hasError: false };

  public static getDerivedStateFromError(): SafeAppErrorBoundaryState {
    return { hasError: true };
  }

  public override componentDidCatch(error: Error, info: ErrorInfo): void {
    // Error values may contain backend details. Deliberately do not render or persist them.
    void error;
    void info;
  }

  public override render(): ReactNode {
    if (this.state.hasError) {
      return <main className="boundary-page"><p className="eyebrow">Console unavailable</p><h1>This console view could not be displayed.</h1><p>No administrative data is shown. Refresh the page to start a new verified session.</p></main>;
    }
    return this.props.children;
  }
}
