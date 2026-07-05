import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
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

class _FakeShoppingRepository implements ShoppingRepository {
  _FakeShoppingRepository(this.lists);

  final List<ShoppingListRecord> lists;
  final _controller = StreamController<List<ShoppingListRecord>>.broadcast();
  String? updatedHouseholdId;
  String? updatedListId;
  String? updatedItemId;
  ShoppingListItemStatus? updatedStatus;
  String? updatedSubstituteIngredientId;
  double? updatedSubstituteQuantity;
  Unit? updatedSubstituteUnit;
  ShoppingListStatus? completedStatus;
  ShoppingListRecord? adjustedShopNowList;

  void dispose() => _controller.close();

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) async* {
    yield lists
        .where((list) => list.householdId == householdId)
        .toList(growable: false);
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
  Future<void> upsertList(ShoppingListRecord list) async {}

  @override
  Future<void> updateItemStatus({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingListItemStatus status,
    String? substituteIngredientId,
    double? substituteQuantity,
    Unit? substituteUnit,
  }) async {
    updatedHouseholdId = householdId;
    updatedListId = listId;
    updatedItemId = itemId;
    updatedStatus = status;
    updatedSubstituteIngredientId = substituteIngredientId;
    updatedSubstituteQuantity = substituteQuantity;
    updatedSubstituteUnit = substituteUnit;

    final index = lists.indexWhere(
      (list) => list.householdId == householdId && list.id == listId,
    );
    final list = lists[index];
    final updatedItems = [
      for (final item in list.items)
        if (item.id == itemId)
          ShoppingListItemRecord(
            id: item.id,
            shoppingListId: item.shoppingListId,
            ingredientId: item.ingredientId,
            quantityNeeded: item.quantityNeeded,
            unit: item.unit,
            status: status,
            sourceMealLinks: item.sourceMealLinks,
            substituteIngredientId: substituteIngredientId,
            substituteQuantity: substituteQuantity,
            substituteUnit: substituteUnit,
          )
        else
          item,
    ];
    lists[index] = ShoppingListRecord(
      id: list.id,
      householdId: list.householdId,
      type: list.type,
      shoppingDate: list.shoppingDate,
      generatedForRangeStart: list.generatedForRangeStart,
      generatedForRangeEnd: list.generatedForRangeEnd,
      status: list.status,
      originId: list.originId,
      createdAt: list.createdAt,
      updatedAt: list.updatedAt,
      items: updatedItems,
    );
    _controller.add(List<ShoppingListRecord>.unmodifiable(lists));
  }

  @override
  Future<void> updateListStatus({
    required String householdId,
    required String listId,
    required ShoppingListStatus status,
  }) async {
    updatedHouseholdId = householdId;
    updatedListId = listId;
    completedStatus = status;
    final index = lists.indexWhere(
      (list) => list.householdId == householdId && list.id == listId,
    );
    final list = lists[index];
    lists[index] = ShoppingListRecord(
      id: list.id,
      householdId: list.householdId,
      type: list.type,
      shoppingDate: list.shoppingDate,
      generatedForRangeStart: list.generatedForRangeStart,
      generatedForRangeEnd: list.generatedForRangeEnd,
      status: status,
      originId: list.originId,
      createdAt: list.createdAt,
      updatedAt: list.updatedAt,
      items: list.items,
    );
    _controller.add(List<ShoppingListRecord>.unmodifiable(lists));
  }

  @override
  Future<void> applyShopNowPurchasesToScheduledLists({
    required String householdId,
    required ShoppingListRecord shopNowList,
  }) async {
    updatedHouseholdId = householdId;
    adjustedShopNowList = shopNowList;
  }

  @override
  Future<void> deleteList({
    required String householdId,
    required String listId,
  }) async {}
}

class _FakePurchaseHistoryRepository implements PurchaseHistoryRepository {
  final records = <PurchaseRecord>[];

  @override
  Stream<List<PurchaseRecord>> watchByHousehold(String householdId) =>
      Stream.value(
        records
            .where((record) => record.householdId == householdId)
            .toList(growable: false),
      );

  @override
  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  ) => Stream.value(
    records
        .where(
          (record) =>
              record.householdId == householdId &&
              record.ingredientId == ingredientId,
        )
        .toList(growable: false),
  );

  @override
  Future<void> record(PurchaseRecord record) async {
    records.add(record);
  }
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

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(this.items);

  final List<PantryItem> items;

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => Stream.value(
    items
        .where(
          (item) => item.householdId == householdId && item.section == section,
        )
        .toList(growable: false),
  );

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      Stream.value(_find((item) => item.id == itemId));

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async => _find(
    (item) =>
        item.householdId == householdId && item.ingredientId == ingredientId,
  );

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required Unit unit,
    required PantrySection section,
  }) async => _find(
    (item) =>
        item.householdId == householdId &&
        item.ingredientId == ingredientId &&
        item.unit == unit &&
        item.section == section,
  );

  @override
  Future<void> add(PantryItem item) async {
    items.add(item);
  }

  @override
  Future<void> update(PantryItem item) async {
    items
      ..removeWhere((current) => current.id == item.id)
      ..add(item);
  }

  @override
  Future<void> setQuantity(
    String householdId,
    String itemId,
    double newQty,
  ) async {}

  @override
  Future<void> delete(String householdId, String itemId) async {}

  @override
  Future<String> uploadPhoto(String householdId, String itemId, File file) =>
      throw UnimplementedError();

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) async {}

  PantryItem? _find(bool Function(PantryItem item) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository(this.meals);

  final List<MealScheduleEntry> meals;
  final upserted = <MealScheduleEntry>[];

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(
    meals
        .where((meal) {
          final date = DateTime(meal.date.year, meal.date.month, meal.date.day);
          final start = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          final end = DateTime(endDate.year, endDate.month, endDate.day);
          return !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false),
  );

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {
    upserted.add(entry);
  }

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

ShoppingListRecord _record() {
  final now = DateTime(2026, 7, 5, 12);
  return ShoppingListRecord(
    id: 'persisted-shop',
    householdId: 'solo-household',
    type: ShoppingListType.shopNow,
    shoppingDate: now,
    generatedForRangeStart: DateTime(2026, 7, 6),
    generatedForRangeEnd: DateTime(2026, 7, 12),
    status: ShoppingListStatus.pending,
    createdAt: now,
    updatedAt: now,
    items: const [
      ShoppingListItemRecord(
        id: 'item-beans',
        shoppingListId: 'persisted-shop',
        ingredientId: 'beans',
        quantityNeeded: 2,
        unit: Unit.piece,
        status: ShoppingListItemStatus.unchecked,
        sourceMealLinks: [],
      ),
      ShoppingListItemRecord(
        id: 'item-tomato',
        shoppingListId: 'persisted-shop',
        ingredientId: 'tomato',
        quantityNeeded: 500,
        unit: Unit.g,
        status: ShoppingListItemStatus.bought,
        sourceMealLinks: [],
      ),
    ],
  );
}

ShoppingListRecord _substitutedRecord() {
  final now = DateTime(2026, 7, 5, 12);
  return ShoppingListRecord(
    id: 'sub-shop',
    householdId: 'solo-household',
    type: ShoppingListType.shopNow,
    shoppingDate: now,
    generatedForRangeStart: DateTime(2026, 7, 6),
    generatedForRangeEnd: DateTime(2026, 7, 6),
    status: ShoppingListStatus.pending,
    createdAt: now,
    updatedAt: now,
    items: [
      ShoppingListItemRecord(
        id: 'item-tomato',
        shoppingListId: 'sub-shop',
        ingredientId: 'tomato',
        quantityNeeded: 500,
        unit: Unit.g,
        status: ShoppingListItemStatus.substituted,
        substituteIngredientId: 'pepper',
        substituteQuantity: 300,
        substituteUnit: Unit.g,
        sourceMealLinks: [
          MealSourceLink(
            mealEntryId: 'meal-1',
            recipeId: 'stew',
            date: DateTime(2026, 7, 6),
            quantity: 500,
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('ShoppingListScreen without a list id shows an empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(),
        ),
      ),
    );

    expect(find.text('No shopping list selected'), findsOneWidget);
    expect(find.byType(KsChecklistRow), findsNothing);
  });

  testWidgets('ShoppingListScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ShoppingListScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ShoppingListScreen renders persisted shopping records by id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('White beans'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(KsChecklistRow), findsNWidgets(2));
  });

  testWidgets('ShoppingListScreen persists checklist item status changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstRow = find.byType(KsChecklistRow).first;
    await tester.tapAt(tester.getTopLeft(firstRow) + const Offset(24, 24));
    await tester.pumpAndSettle();

    expect(repo.updatedHouseholdId, 'solo-household');
    expect(repo.updatedListId, 'persisted-shop');
    expect(repo.updatedItemId, 'item-beans');
    expect(repo.updatedStatus, ShoppingListItemStatus.bought);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets(
    'ShoppingListScreen records substitution status from row actions',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeShoppingRepository([_record()]);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
            recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
            shoppingRepositoryProvider.overrideWithValue(repo),
            pantryRepositoryProvider.overrideWithValue(
              _FakePantryRepository([]),
            ),
            purchaseHistoryRepositoryProvider.overrideWithValue(
              _FakePurchaseHistoryRepository(),
            ),
            wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
            calendarRepositoryProvider.overrideWithValue(
              _FakeCalendarRepository([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ShoppingListScreen(listId: 'persisted-shop'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(KsChecklistRow).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record substitution'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Substitute ingredient ID'),
        'pepper',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '3');
      await tester.tap(find.text('Save substitution'));
      await tester.pumpAndSettle();

      expect(repo.updatedItemId, 'item-beans');
      expect(repo.updatedStatus, ShoppingListItemStatus.substituted);
      expect(repo.updatedSubstituteIngredientId, 'pepper');
      expect(repo.updatedSubstituteQuantity, 3);
      expect(repo.updatedSubstituteUnit, Unit.piece);
      expect(find.textContaining('Pepper'), findsOneWidget);
    },
  );

  testWidgets('ShoppingListScreen completes persisted lists into pantry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final pantry = _FakePantryRepository([
      PantryItem(
        id: 'pantry-tomato',
        householdId: 'solo-household',
        ingredientId: 'tomato',
        quantity: 100,
        unit: Unit.g,
        section: PantrySection.food,
        createdAt: DateTime(2026, 7),
        updatedAt: DateTime(2026, 7),
      ),
    ]);
    addTearDown(repo.dispose);
    final router = GoRouter(
      initialLocation: '/list/persisted-shop',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Done')),
          routes: [
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
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          pantryRepositoryProvider.overrideWithValue(pantry),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done shopping'));
    await tester.pumpAndSettle();

    expect(repo.completedStatus, ShoppingListStatus.completed);
    expect(repo.adjustedShopNowList?.id, 'persisted-shop');
    final tomato = pantry.items.singleWhere(
      (item) => item.ingredientId == 'tomato',
    );
    expect(tomato.quantity, 600);
    expect(tomato.lastPurchaseDate, isNotNull);
    expect(pantry.items.any((item) => item.ingredientId == 'beans'), isFalse);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('ShoppingListScreen stores meal substitution overrides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_substitutedRecord()]);
    final pantry = _FakePantryRepository([]);
    final calendar = _FakeCalendarRepository([
      MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'stew',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
    ]);
    addTearDown(repo.dispose);
    final router = GoRouter(
      initialLocation: '/list/sub-shop',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Done')),
          routes: [
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
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          pantryRepositoryProvider.overrideWithValue(pantry),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(calendar),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done shopping'));
    await tester.pumpAndSettle();

    expect(pantry.items.single.ingredientId, 'pepper');
    final override = calendar.upserted.single.ingredientOverrides.single;
    expect(override.originalIngredientId, 'tomato');
    expect(override.substituteIngredientId, 'pepper');
    expect(override.substituteQuantity, 300);
    expect(find.text('Done'), findsOneWidget);
  });
}
