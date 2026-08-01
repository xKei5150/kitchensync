import { useCallback, useEffect, useMemo, useState, type AnchorHTMLAttributes, type MouseEvent, type ReactNode } from "react";
import { BrowserRouterContext, type BrowserRouterValue, useBrowserRouter } from "./routerContext";
import { parseAppRoute, routePath, type RouteDestination } from "./routes";

function currentPathname(): string {
  return window.location.pathname;
}

export function BrowserHistoryRouter({ children }: { readonly children: ReactNode }) {
  const [pathname, setPathname] = useState(currentPathname);
  const route = parseAppRoute(pathname);

  const navigate = useCallback((destination: RouteDestination, options?: { readonly replace?: boolean }) => {
    const path = routePath(destination);
    if (window.location.pathname === path) return;
    if (options?.replace) {
      window.history.replaceState(null, "", path);
    } else {
      window.history.pushState(null, "", path);
    }
    setPathname(path);
  }, []);

  useEffect(() => {
    const handlePopState = (): void => setPathname(currentPathname());
    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, []);

  useEffect(() => {
    if (route.kind === "root") navigate({ kind: "health" }, { replace: true });
  }, [navigate, route.kind]);

  const value = useMemo<BrowserRouterValue>(() => ({ route, navigate }), [navigate, route]);
  return <BrowserRouterContext.Provider value={value}>{children}</BrowserRouterContext.Provider>;
}

interface AppLinkProps extends Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href"> {
  readonly to: RouteDestination;
}

export function AppLink({ to, onClick, target, ...props }: AppLinkProps) {
  const { navigate } = useBrowserRouter();
  const href = routePath(to);

  function handleClick(event: MouseEvent<HTMLAnchorElement>): void {
    onClick?.(event);
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.altKey || event.ctrlKey || event.shiftKey || (target !== undefined && target !== "" && target !== "_self") || props.download !== undefined) {
      return;
    }
    event.preventDefault();
    navigate(to);
  }

  return <a {...props} href={href} target={target} onClick={handleClick} />;
}
