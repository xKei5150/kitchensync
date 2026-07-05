import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/planning_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_list_screen.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(
  Widget home, {
  ThemeData? theme,
  ShoppingRepository? shoppingRepository,
  PantryRepository? pantryRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
    recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
    purchaseHistoryRepositoryProvider.overrideWithValue(
      _FakePurchaseHistoryRepository(),
    ),
    wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
    if (shoppingRepository != null)
      shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
    if (pantryRepository != null)
      pantryRepositoryProvider.overrideWithValue(pantryRepository),
  ];
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: home),
  );
}

class _MockPantryRepository extends Mock implements PantryRepository {}

class _FakePurchaseHistoryRepository implements PurchaseHistoryRepository {
  @override
  Stream<List<PurchaseRecord>> watchByHousehold(String householdId) =>
      const Stream.empty();

  @override
  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  ) => const Stream.empty();

  @override
  Future<void> record(PurchaseRecord record) async {}
}

class _FakeWasteRepository implements WasteRepository {
  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => const Stream.empty();

  @override
  Future<void> log(WasteEvent event) async {}
}

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

class _FakeRecipeRepository implements RecipeRepository {
  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      const Stream.empty();

  @override
  Stream<Recipe?> watchById(String recipeId) => Stream.value(null);

  @override
  Future<void> upsert(Recipe recipe) async {}

  @override
  Future<void> delete(String recipeId) async {}

  @override
  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  }) async => const [];

  @override
  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCalendarRepository implements CalendarRepository {
  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => const Stream.empty();

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {}

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {}

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => const Stream.empty();

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

class _FakeShoppingRepository implements ShoppingRepository {
  final List<ShoppingListRecord> lists = [];
  final _controller = StreamController<List<ShoppingListRecord>>.broadcast();

  void dispose() => _controller.close();

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) async* {
    List<ShoppingListRecord> scoped() => lists
        .where((list) => list.householdId == householdId)
        .toList(growable: false);
    yield scoped();
    yield* _controller.stream.map((_) => scoped());
  }

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) async* {
    ShoppingListRecord? byId() {
      for (final list in lists) {
        if (list.householdId == householdId && list.id == listId) {
          return list;
        }
      }
      return null;
    }

    yield byId();
    yield* _controller.stream.map((_) => byId());
  }

  @override
  Future<void> upsertList(ShoppingListRecord list) async {
    lists
      ..removeWhere((current) => current.id == list.id)
      ..add(list);
    _controller.add(List<ShoppingListRecord>.unmodifiable(lists));
  }

  @override
  Future<void> updateItemStatus({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingListItemStatus status,
    String? substituteIngredientId,
    double? substituteQuantity,
    Unit? substituteUnit,
  }) async {}

  @override
  Future<void> updateListStatus({
    required String householdId,
    required String listId,
    required ShoppingListStatus status,
  }) async {}

  @override
  Future<void> applyShopNowPurchasesToScheduledLists({
    required String householdId,
    required ShoppingListRecord shopNowList,
  }) async {}

  @override
  Future<void> deleteList({
    required String householdId,
    required String listId,
  }) async {
    lists.removeWhere(
      (list) => list.householdId == householdId && list.id == listId,
    );
    _controller.add(List<ShoppingListRecord>.unmodifiable(lists));
  }
}

void main() {
  testWidgets(
    'ShoppingScreen renders the Shop Now card, upcoming and history',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _wrap(const ShoppingScreen()));

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Knock out next week early?'), findsOneWidget);
      expect(find.text('Start a shop'), findsOneWidget);
      expect(find.text('Weekly shop'), findsOneWidget);
      expect(find.text('Fri 20 Jun · 13 items · £58'), findsOneWidget);
    },
  );

  testWidgets('ShoppingScreen opens the Shop Now "how far ahead?" sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const ShoppingScreen()));

    await tester.tap(find.text('Start a shop'));
    await tester.pumpAndSettle();

    expect(find.text('Shop how far ahead?'), findsOneWidget);
    expect(find.text('+ 1 week ahead'), findsOneWidget);
    expect(find.text('Build the list · 20 items'), findsOneWidget);
  });

  testWidgets('ShoppingScreen builds a Shop Now list before routing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeShoppingRepository();
    final pantry = _MockPantryRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
        recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
        shoppingRepositoryProvider.overrideWithValue(repo),
        pantryRepositoryProvider.overrideWithValue(pantry),
        purchaseHistoryRepositoryProvider.overrideWithValue(
          _FakePurchaseHistoryRepository(),
        ),
        wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
        calendarRepositoryProvider.overrideWithValue(_FakeCalendarRepository()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);
    final router = GoRouter(
      initialLocation: '/shop',
      routes: [
        GoRoute(
          path: '/shop',
          builder: (context, state) => const ShoppingScreen(),
          routes: [
            GoRoute(
              path: 'list',
              builder: (context, state) => const ShoppingListScreen(),
            ),
            GoRoute(
              path: 'list/:listId',
              builder: (context, state) =>
                  ShoppingListScreen(listId: state.pathParameters['listId']),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start a shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build the list · 20 items'));
    await tester.pumpAndSettle();

    final activeList = container
        .read(planningControllerProvider)
        .activeShoppingList;
    expect(activeList, isNotNull);
    expect(activeList!.items, isNotEmpty);
    expect(repo.lists, hasLength(1));
    expect(repo.lists.single.id, activeList.id);
    expect(repo.lists.single.items, isNotEmpty);
    expect(find.text('Done shopping'), findsOneWidget);
    expect(find.text('White beans'), findsOneWidget);
  });

  testWidgets('ShoppingScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(const ShoppingScreen(), theme: AppTheme.dark()),
    );

    expect(tester.takeException(), isNull);
  });
}
