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
  final activeHousehold = ref.watch(activeHouseholdContextProvider);
  const householdPolicy = HouseholdPolicy();
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    redirect: (context, state) {
      final path = state.uri.path;
      final isOnboarding =
          path == '/onboarding' || path.startsWith('/onboarding/');
      if (activeHousehold == null && !isOnboarding) {
        return '/onboarding/household';
      }
      if (activeHousehold != null &&
          !activeHousehold.hasPremium &&
          path.startsWith('/menu-sets')) {
        return '/settings/premium';
      }
      if (activeHousehold != null) {
        final role = activeHousehold.role;
        final isSolo = activeHousehold.isSolo;
        bool can(HouseholdCapability capability) {
          return householdPolicy.roleCan(
            role,
            capability,
            isSoloHousehold: isSolo,
          );
        }

        if (path == '/shop/list' &&
            !can(HouseholdCapability.completeShopping)) {
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
      }
      return null;
    },
    routes: [_shellRoute(), ..._fullscreenRoutes()],
  );
}
