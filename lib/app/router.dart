import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/features/dev_tools/dev_tools_screen.dart';
import 'package:kitchensync/features/home/home_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_detail_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/add_pantry_item_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/pantry_home_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/pantry_item_detail_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/waste_log_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'ingredient/pick',
            name: 'ingredientPicker',
            builder: (context, state) => const IngredientPickerScreen(),
          ),
          GoRoute(
            path: 'ingredient/create',
            name: 'ingredientCreate',
            builder: (context, state) => CreateCustomIngredientScreen(
              initialName: state.extra as String?,
            ),
          ),
          GoRoute(
            path: 'ingredient/:id',
            name: 'ingredientDetail',
            builder: (context, state) =>
                IngredientDetailScreen(id: state.pathParameters['id']!),
          ),
          if (kDebugMode)
            GoRoute(
              path: 'dev',
              name: 'dev',
              builder: (context, state) => const DevToolsScreen(),
            ),
          GoRoute(
            path: 'pantry',
            name: 'pantry',
            builder: (context, state) => const PantryHomeScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'pantryAdd',
                builder: (context, state) => const AddPantryItemScreen(),
              ),
              GoRoute(
                path: 'waste',
                name: 'wasteLog',
                builder: (context, state) => const WasteLogScreen(),
              ),
              GoRoute(
                path: ':itemId',
                name: 'pantryItemDetail',
                builder: (context, state) => PantryItemDetailScreen(
                  itemId: state.pathParameters['itemId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
