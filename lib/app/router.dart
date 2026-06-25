import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/app/shell/ks_app_shell.dart';
import 'package:kitchensync/core/utils/motion.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/dev_tools/accessibility_audit_screen.dart';
import 'package:kitchensync/features/dev_tools/accessibility_states_screen.dart';
import 'package:kitchensync/features/dev_tools/dev_tools_screen.dart';
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

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    routes: [
      // The persistent five-tab spine. Each branch keeps its own navigator
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
                path: '/recipes',
                name: 'recipes',
                builder: (context, state) => const RecipesScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes pushed over the shell (no bottom nav), each using
      // the shared reduced-motion-aware [_page] transition.
      GoRoute(
        path: '/day',
        name: 'dayView',
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
      // P2 · Premium & system. Pushed full-screen over the shell.
      GoRoute(
        path: '/menu-sets',
        name: 'menuSets',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _page(state, const MenuSetsScreen()),
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
      GoRoute(
        path: '/household',
        name: 'household',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _page(state, const HouseholdScreen()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _page(state, const SettingsScreen()),
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
          ],
        ),
    ],
  );
}
