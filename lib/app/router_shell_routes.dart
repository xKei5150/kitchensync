part of 'router.dart';

RouteBase _shellRoute() => StatefulShellRoute.indexedStack(
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
          routes: [
            GoRoute(
              path: 'shopping-schedule',
              name: 'shoppingSchedule',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  _page(state, const ShoppingScheduleScreen()),
            ),
          ],
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
              path: 'history',
              name: 'shopHistory',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  _page(state, const ShoppingHistoryScreen()),
            ),
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
                ShoppingListScreen(listId: state.pathParameters['listId']),
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
                PantryItemDetailScreen(itemId: state.pathParameters['itemId']!),
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
);
