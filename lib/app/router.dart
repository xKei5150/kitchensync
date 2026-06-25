import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/shell/ks_app_shell.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
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

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    routes: [
      // The persistent five-tab spine. Each branch keeps its own navigator
      // and state; [KsAppShell] pins the bottom nav beneath them.
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
                    builder: (context, state) => const ShoppingListScreen(),
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
                    builder: (context, state) => const AddPantryItemScreen(),
                  ),
                  GoRoute(
                    path: 'waste',
                    name: 'wasteLog',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const WasteLogScreen(),
                  ),
                  GoRoute(
                    path: ':itemId',
                    name: 'pantryItemDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => PantryItemDetailScreen(
                      itemId: state.pathParameters['itemId']!,
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

      // Full-screen routes pushed over the shell (no bottom nav).
      GoRoute(
        path: '/day',
        name: 'dayView',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DayViewScreen(),
      ),
      GoRoute(
        path: '/recipe',
        name: 'recipeDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecipeDetailScreen(),
      ),
      // P2 · Premium & system. Pushed full-screen over the shell.
      GoRoute(
        path: '/menu-sets',
        name: 'menuSets',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MenuSetsScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            name: 'menuSetEditor',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const MenuSetEditorScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/household',
        name: 'household',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HouseholdScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'premium',
            name: 'premium',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PremiumScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignInScreen(),
        routes: [
          GoRoute(
            path: 'household',
            name: 'onboardingHousehold',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const HouseholdSetupScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/ingredient/pick',
        name: 'ingredientPicker',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const IngredientPickerScreen(),
      ),
      GoRoute(
        path: '/ingredient/create',
        name: 'ingredientCreate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            CreateCustomIngredientScreen(initialName: state.extra as String?),
      ),
      GoRoute(
        path: '/ingredient/:id',
        name: 'ingredientDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            IngredientDetailScreen(id: state.pathParameters['id']!),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/dev',
          name: 'dev',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const DevToolsScreen(),
        ),
    ],
  );
}
