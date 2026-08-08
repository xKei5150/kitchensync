import { useState, type ReactNode } from "react";
import { Activity, BadgeCheck, ChevronRight, House, LogOut, Menu, UsersRound, X } from "lucide-react";
import { useStaffAccess } from "../auth/staffAccess";
import { AppLink } from "../routing/browserRouter";
import { useBrowserRouter } from "../routing/routerContext";
import { isNavigationRouteActive, type RouteDestination } from "../routing/routes";

interface AppShellProps {
  readonly children: ReactNode;
}

function maskEmail(value: string | null): string {
  if (!value) return "Staff session";
  const at = value.indexOf("@");
  if (at < 1) return "Staff session";
  return `${value.slice(0, 1)}***${value.slice(at)}`;
}

const navigation = [
  { to: { kind: "health" }, label: "Service health", description: "Live service indicators", icon: Activity },
  { to: { kind: "user-lookup" }, label: "User 360", description: "Exact UID lookup", icon: UsersRound },
  { to: { kind: "household-lookup" }, label: "Household 360", description: "Exact household lookup", icon: House },
  { to: { kind: "entitlement-lookup" }, label: "Entitlements", description: "Read-only diagnostics", icon: BadgeCheck },
] as const satisfies readonly { readonly to: RouteDestination; readonly label: string; readonly description: string; readonly icon: typeof Activity }[];

export function AppShell({ children }: AppShellProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const { user, signOut } = useStaffAccess();
  const { route } = useBrowserRouter();

  return (
    <div className="app-frame">
      <header className="app-topbar">
        <button className="icon-button mobile-menu" type="button" onClick={() => setMenuOpen((open) => !open)} aria-label={menuOpen ? "Close navigation" : "Open navigation"} title={menuOpen ? "Close navigation" : "Open navigation"}>
          {menuOpen ? <X aria-hidden="true" /> : <Menu aria-hidden="true" />}
        </button>
        <AppLink className="wordmark" to={{ kind: "health" }} aria-label="KitchenSync Admin home">
          <span className="wordmark__glyph" aria-hidden="true">K</span>
          <span>KitchenSync <em>Admin</em></span>
        </AppLink>
        <div className="app-topbar__middle"><span className="read-only-mark">Read-only console</span></div>
        <div className="staff-session">
          <span>{maskEmail(user.email)}</span>
          <button className="icon-button" type="button" onClick={() => { void signOut(); }} aria-label="Sign out" title="Sign out">
            <LogOut aria-hidden="true" />
          </button>
        </div>
      </header>
      <div className="app-layout">
        <aside className={`sidebar ${menuOpen ? "sidebar--open" : ""}`} aria-label="Administration navigation">
          <div className="sidebar__intro">
            <p className="eyebrow">Operations</p>
            <p>Read-only support and diagnostic surfaces.</p>
          </div>
          <nav>
            <ul className="nav-list">
              {navigation.map(({ to, label, description, icon: Icon }) => (
                <li key={to.kind}>
                  <AppLink className={`nav-link ${isNavigationRouteActive(to, route) ? "nav-link--active" : ""}`} to={to} onClick={() => setMenuOpen(false)}>
                    <Icon aria-hidden="true" />
                    <span><strong>{label}</strong><small>{description}</small></span>
                    <ChevronRight className="nav-link__chevron" aria-hidden="true" />
                  </AppLink>
                </li>
              ))}
            </ul>
          </nav>
          <div className="sidebar__note">
            <span aria-hidden="true">✦</span>
            Sensitive fields remain masked by default. This client has no direct database or storage access.
          </div>
        </aside>
        <main className="app-content" id="main-content">{children}</main>
      </div>
    </div>
  );
}
