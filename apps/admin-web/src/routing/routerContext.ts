import { createContext, useContext } from "react";
import type { AppRoute, RouteDestination } from "./routes";

export interface BrowserRouterValue {
  readonly route: AppRoute;
  readonly navigate: (destination: RouteDestination, options?: { readonly replace?: boolean }) => void;
}

export const BrowserRouterContext = createContext<BrowserRouterValue | null>(null);

export function useBrowserRouter(): BrowserRouterValue {
  const value = useContext(BrowserRouterContext);
  if (!value) throw new Error("Browser router is not available.");
  return value;
}
