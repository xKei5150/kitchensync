import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/app/shell/ks_app_shell.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/motion.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/dev_tools/accessibility_audit_screen.dart';
import 'package:kitchensync/features/dev_tools/accessibility_states_screen.dart';
import 'package:kitchensync/features/dev_tools/dev_tools_screen.dart';
import 'package:kitchensync/features/dev_tools/system_states_screen.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/household/presentation/screens/household_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_detail_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_set_editor_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_sets_screen.dart';
import 'package:kitchensync/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/sign_in_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/add_pantry_item_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/insights_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/pantry_home_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/pantry_item_detail_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/waste_log_screen.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipes_screen.dart';
import 'package:kitchensync/features/settings/presentation/screens/premium_screen.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_list_screen.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:kitchensync/features/today/presentation/screens/day_view_screen.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
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
    routes: [
      // The persistent dashboard spine. Each branch keeps its own navigator
      // and state; [KsAppShell] pins the bottom nav beneath them. Tab switches
      // are an indexed stack (no page transition), so these stay builders.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            KsAppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                name: 'today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recipes',
                name: 'recipes',
                builder: (context, state) => const RecipesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                name: 'calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                name: 'shop',
                builder: (context, state) => const ShoppingScreen(),
                routes: [
                  GoRoute(
                    path: 'list',
                    name: 'shopList',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        _page(state, const ShoppingListScreen()),
                  ),
                  GoRoute(
                    path: 'list/:listId',
                    name: 'shopListById',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => _page(
                      state,
                      ShoppingListScreen(
                        listId: state.pathParameters['listId'],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pantry',
                name: 'pantry',
                builder: (context, state) => const PantryHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'pantryAdd',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        _page(state, const AddPantryItemScreen()),
                  ),
                  GoRoute(
                    path: 'waste',
                    name: 'wasteLog',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        _page(state, const WasteLogScreen()),
                  ),
                  GoRoute(
                    path: ':itemId',
                    name: 'pantryItemDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => _page(
                      state,
                      PantryItemDetailScreen(
                        itemId: state.pathParameters['itemId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/menu-sets',
                name: 'menuSets',
                builder: (context, state) => const MenuSetsScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'menuSetEditor',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        _page(state, const MenuSetEditorScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'premium',
                    name: 'premium',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        _page(state, const PremiumScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

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
        pageBuilder: (context, state) =>
            _page(state, const RecipeDetailScreen()),
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
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _page(state, const NotificationsScreen()),
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
        pageBuilder: (context, state) => _page(
          state,
          CreateCustomIngredientScreen(initialName: state.extra as String?),
        ),
      ),
      GoRoute(
        path: '/ingredient/:id',
        name: 'ingredientDetail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _page(
          state,
          IngredientDetailScreen(id: state.pathParameters['id']!),
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
    ],
  );
}
