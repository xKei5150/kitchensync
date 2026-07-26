part of 'router.dart';

/// A full-screen page whose transition slides up and fades by default, but
/// collapses to a plain 150ms cross-fade under the platform reduce-motion
/// setting — the "Page transition" row of the motion map in
/// "KitchenSync — P4 Accessibility States", Screen 24. One treatment for every
/// screen pushed over the shell, so the whole app yields together.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: KsTokens.curveStandard,
      );
      // Reduced motion: cross-fade only — nothing travels.
      if (KsMotion.reduced(context)) {
        return FadeTransition(opacity: curved, child: child);
      }
      // Default: a shared-axis rise paired with the fade.
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Authentication boundaries must replace a signed-in surface immediately.
///
/// The standard fullscreen transition starts with an opacity of zero, which
/// briefly reveals the previous shell underneath it. That is appropriate for
/// ordinary in-app navigation, but it can flash a former user's household
/// after sign-out. Auth/loading and onboarding therefore use an opaque
/// no-transition page instead.
NoTransitionPage<void> _authPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

DateTime? _parseRouteDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final normalized =
      '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return normalized == value
      ? DateTime(parsed.year, parsed.month, parsed.day)
      : null;
}

GoRouter _buildRouter(Ref ref) {
  final session = ref.watch(appSessionStateProvider);
  final authenticationOperationInProgress = ref.watch(
    authenticationOperationInProgressProvider,
  );
  const householdPolicy = HouseholdPolicy();
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth/loading',
    redirect: (context, state) {
      final sessionRedirect = appSessionRedirect(
        session: session,
        authenticationOperationInProgress: authenticationOperationInProgress,
        path: state.uri.path,
        allowHouseholdPicker:
            state.uri.queryParameters['switch'] == 'household',
      );
      if (sessionRedirect != null) return sessionRedirect;

      // Loading, signed-out, and recovery states are fully handled by the
      // session redirect above. Do not fall through and manufacture another
      // redirect just because there is (correctly) no active household yet.
      if (session.phase != AppSessionPhase.ready) return null;

      final path = state.uri.path;
      final activeHousehold = session.household;
      // The session redirect above guarantees this is a real membership, not
      // a stale or synthetic context.
      if (activeHousehold == null) return '/auth/loading';
      if (!activeHousehold.hasPremium && path.startsWith('/menu-sets')) {
        return '/settings/premium';
      }
      final role = activeHousehold.role;
      final isSolo = activeHousehold.isSolo;
      bool can(HouseholdCapability capability) {
        return householdPolicy.roleCan(
          role,
          capability,
          isSoloHousehold: isSolo,
        );
      }

      if (path == '/shop/list' && !can(HouseholdCapability.completeShopping)) {
        return '/shop';
      }
      if (path == '/pantry/add' && !can(HouseholdCapability.addPantryItems)) {
        return '/pantry';
      }
      if (path == '/pantry/waste' &&
          !can(HouseholdCapability.markPantryWaste)) {
        return '/pantry';
      }
      if (path == '/menu-sets/edit' &&
          !can(HouseholdCapability.applyMenuSets)) {
        return '/menu-sets';
      }
      if (path == '/ingredient/create' &&
          !can(HouseholdCapability.addPantryItems)) {
        return '/ingredient/pick';
      }
      return null;
    },
    routes: [_shellRoute(), ..._fullscreenRoutes()],
  );
}

/// Auth-first redirect policy, kept pure so loading/race behavior has direct
/// test coverage without needing a real Firebase SDK stream.
String? appSessionRedirect({
  required AppSessionState session,
  required bool authenticationOperationInProgress,
  required String path,
  bool allowHouseholdPicker = false,
}) {
  final isLoadingRoute = path == '/auth/loading';
  final isSignInRoute = path == '/onboarding';

  final signedInSession = switch (session.phase) {
    AppSessionPhase.loadingHousehold ||
    AppSessionPhase.needsHouseholdSetup ||
    AppSessionPhase.ready => true,
    AppSessionPhase.error => session.user != null,
    _ => false,
  };
  if (authenticationOperationInProgress && signedInSession) {
    // Hold the explicit loading route for the whole in-flight operation. If
    // this fell through to the ready case below, GoRouter would immediately
    // redirect `/auth/loading` back to `/today` while `/today` redirects back
    // here, creating a synchronous redirect loop after registration.
    return isLoadingRoute ? null : '/auth/loading';
  }

  return switch (session.phase) {
    AppSessionPhase.loadingAuth ||
    AppSessionPhase.loadingHousehold => isLoadingRoute ? null : '/auth/loading',
    AppSessionPhase.error => isLoadingRoute ? null : '/auth/loading',
    // Firebase bootstrap occurs before runApp. This is only reachable in an
    // intentionally isolated widget test or when setup failed, so the only
    // honest place to send someone is the auth entry point.
    AppSessionPhase.unavailable ||
    AppSessionPhase.signedOut => isSignInRoute ? null : '/onboarding',
    AppSessionPhase.needsHouseholdSetup => isSignInRoute ? null : '/onboarding',
    AppSessionPhase.ready =>
      (isLoadingRoute || (isSignInRoute && !allowHouseholdPicker))
          ? '/today'
          : null,
  };
}
