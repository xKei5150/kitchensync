part of 'router.dart';

List<RouteBase> _fullscreenRoutes() => [
  // Full-screen routes pushed over the shell (no bottom nav), each using
  // the shared reduced-motion-aware [_page] transition.
  GoRoute(
    path: '/day/:date',
    name: 'dayView',
    parentNavigatorKey: _rootNavigatorKey,
    redirect: (context, state) {
      final date = _parseRouteDate(state.pathParameters['date']);
      return date == null ? '/calendar' : null;
    },
    pageBuilder: (context, state) => _page(
      state,
      DayViewScreen(
        selectedDate: _parseRouteDate(state.pathParameters['date']),
      ),
    ),
  ),
  GoRoute(
    path: '/day',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(state, const DayViewScreen()),
  ),
  GoRoute(
    path: '/recipe',
    name: 'recipeDetail',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(state, const RecipeDetailScreen()),
  ),
  GoRoute(
    path: '/recipe/:recipeId',
    name: 'recipeDetailById',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(
      state,
      RecipeDetailScreen(recipeId: state.pathParameters['recipeId']),
    ),
  ),
  GoRoute(
    path: '/household',
    name: 'household',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(state, const HouseholdScreen()),
  ),
  // P5 · the premium Insights surface (Screen 30), pushed full-screen over
  // the shell. Real charts over the live pantry, behind the premium veil.
  GoRoute(
    path: '/insights',
    name: 'insights',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(state, const InsightsScreen()),
  ),
  GoRoute(
    path: '/pantry/bulk-purchases',
    name: 'bulkPurchases',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(state, const BulkPurchaseScreen()),
  ),
  GoRoute(
    path: '/notifications',
    name: 'notifications',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(state, const NotificationsScreen()),
  ),
  GoRoute(
    path: '/settings/notifications',
    name: 'notificationPreferences',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) =>
        _page(state, const NotificationPreferencesScreen()),
  ),
  GoRoute(
    path: '/onboarding',
    name: 'onboarding',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(state, const SignInScreen()),
    routes: [
      GoRoute(
        path: 'household',
        name: 'onboardingHousehold',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _page(state, const HouseholdSetupScreen()),
      ),
    ],
  ),
  GoRoute(
    path: '/ingredient/pick',
    name: 'ingredientPicker',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) =>
        _page(state, const IngredientPickerScreen()),
  ),
  GoRoute(
    path: '/ingredient/create',
    name: 'ingredientCreate',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) {
      final extra = state.extra;
      return _page(
        state,
        CreateCustomIngredientScreen(
          initialName: extra is String ? extra : null,
          initialIngredient: extra is Ingredient ? extra : null,
        ),
      );
    },
  ),
  GoRoute(
    path: '/ingredient/:id',
    name: 'ingredientDetail',
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) => _page(
      state,
      IngredientDetailScreen(
        id: state.pathParameters['id']!,
        householdId: state.uri.queryParameters['householdId'],
      ),
    ),
  ),
  if (kDebugMode)
    GoRoute(
      path: '/dev',
      name: 'dev',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _page(state, const DevToolsScreen()),
      routes: [
        // P3 · the accessibility verification surface (Screens 17–19).
        // Debug-only — a runtime contrast + colour-vision audit.
        GoRoute(
          path: 'a11y',
          name: 'accessibilityAudit',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) =>
              _page(state, const AccessibilityAuditScreen()),
        ),
        // P4 · the accessibility *states* gallery (Screens 22–25).
        // Debug-only — focus, dynamic type, reduced motion, validation.
        GoRoute(
          path: 'a11y-states',
          name: 'accessibilityStates',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) =>
              _page(state, const AccessibilityStatesScreen()),
        ),
        // P5 · the system-states gallery (Screens 26–30). Debug-only —
        // the presentational conflict / queue / role surfaces beside live
        // skeleton + chart demos.
        GoRoute(
          path: 'system-states',
          name: 'systemStates',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) =>
              _page(state, const SystemStatesScreen()),
        ),
      ],
    ),
];
