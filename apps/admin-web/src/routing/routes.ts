export type RouteDestination =
  | { readonly kind: "health" }
  | { readonly kind: "user-lookup" }
  | { readonly kind: "user-360"; readonly uid: string }
  | { readonly kind: "household-lookup" }
  | { readonly kind: "household-360"; readonly householdId: string }
  | { readonly kind: "entitlement-lookup" }
  | { readonly kind: "entitlement"; readonly householdId: string };

export type AppRoute = RouteDestination | { readonly kind: "root" } | { readonly kind: "not-found" };

function decodePathSegment(segment: string): string | null {
  try {
    const decoded = decodeURIComponent(segment);
    return decoded.includes("\0") || decoded.includes("/") || decoded.includes("\\") ? null : decoded;
  } catch {
    return null;
  }
}

export function parseAppRoute(pathname: string): AppRoute {
  if (!pathname.startsWith("/")) return { kind: "not-found" };
  if (pathname === "/") return { kind: "root" };

  const segments = pathname.slice(1).split("/");
  if (segments.some((segment) => segment.length === 0)) return { kind: "not-found" };
  const decoded = segments.map(decodePathSegment);
  if (decoded.some((segment) => segment === null)) return { kind: "not-found" };

  if (decoded.length === 1) {
    switch (decoded[0]) {
      case "health": return { kind: "health" };
      case "users": return { kind: "user-lookup" };
      case "households": return { kind: "household-lookup" };
      case "entitlements": return { kind: "entitlement-lookup" };
      default: return { kind: "not-found" };
    }
  }

  if (decoded.length === 2 && decoded[1]) {
    switch (decoded[0]) {
      case "users": return { kind: "user-360", uid: decoded[1] };
      case "households": return { kind: "household-360", householdId: decoded[1] };
      case "entitlements": return { kind: "entitlement", householdId: decoded[1] };
      default: return { kind: "not-found" };
    }
  }
  return { kind: "not-found" };
}

export function routePath(destination: RouteDestination): string {
  switch (destination.kind) {
    case "health": return "/health";
    case "user-lookup": return "/users";
    case "user-360": return `/users/${encodeURIComponent(destination.uid)}`;
    case "household-lookup": return "/households";
    case "household-360": return `/households/${encodeURIComponent(destination.householdId)}`;
    case "entitlement-lookup": return "/entitlements";
    case "entitlement": return `/entitlements/${encodeURIComponent(destination.householdId)}`;
  }
}

export function isNavigationRouteActive(destination: RouteDestination, route: AppRoute): boolean {
  switch (destination.kind) {
    case "health": return route.kind === "health" || route.kind === "root";
    case "user-lookup": return route.kind === "user-lookup" || route.kind === "user-360";
    case "household-lookup": return route.kind === "household-lookup" || route.kind === "household-360";
    case "entitlement-lookup": return route.kind === "entitlement-lookup" || route.kind === "entitlement";
    case "user-360": return route.kind === "user-360" && route.uid === destination.uid;
    case "household-360": return route.kind === "household-360" && route.householdId === destination.householdId;
    case "entitlement": return route.kind === "entitlement" && route.householdId === destination.householdId;
  }
}
