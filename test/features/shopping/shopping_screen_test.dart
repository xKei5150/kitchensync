// SIZE_OK: shopping screen tests cover existing navigation and list states.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
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
    calendarRepositoryProvider.overrideWithValue(_FakeCalendarRepository()),
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

class _FakePantryRepository implements PantryRepository {
  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => Stream.value(const []);

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      Stream.value(null);

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async => null;

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required UnitId unit,
    required PantrySection section,
  }) async => null;

  @override
  Future<void> add(PantryItem item) async {}

  @override
  Future<void> update(PantryItem item) async {}

  @override
  Future<void> setQuantity(
    String householdId,
    String itemId,
    double newQty,
  ) async {}

  @override
  Future<void> delete(String householdId, String itemId) async {}

  @override
  Future<String> uploadPhoto(String householdId, String itemId, File file) {
    throw UnimplementedError();
  }

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) async {}
}

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
  _FakeRecipeRepository({Map<String, Recipe>? recipes})
    : recipes = recipes ?? const {};

  final Map<String, Recipe> recipes;

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value(recipes.values.toList(growable: false));

  @override
  Stream<Recipe?> watchById(String recipeId) => Stream.value(recipes[recipeId]);

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
  _FakeCalendarRepository({List<MealScheduleEntry>? meals})
    : meals = meals ?? const [];

  final List<MealScheduleEntry> meals;

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

Recipe _recipe(String id) {
  final now = DateTime(2026, 7);
  return Recipe(
    id: id,
    authorUserId: 'demo-user',
    householdId: 'solo-household',
    name: 'Braise',
    description: 'Dinner',
    defaultServingSize: 4,
    mealTimeTags: const ['Dinner'],
    recipeTags: const [],
    location: 'Home',
    visibility: RecipeVisibility.private,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: const [
      RecipeIngredient(
        id: 'ri-1',
        recipeId: 'braise',
        ingredientId: 'tomato',
        quantity: 500,
        unit: UnitId.g,
      ),
    ],
    instructions: const ['Cook.'],
  );
}

MealScheduleEntry _meal() {
  return MealScheduleEntry(
    id: 'meal-1',
    recipeId: 'braise',
    date: DateTime(2026, 7, 6),
    mealLabel: 'Dinner',
    servingSize: 4,
  );
}

class _FakeShoppingRepository implements ShoppingRepository {
  _FakeShoppingRepository([List<ShoppingListRecord>? initialLists])
    : lists = [...?initialLists];

  final List<ShoppingListRecord> lists;
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
    UnitId? substituteUnit,
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

ShoppingListRecord _shoppingRecord({
  required String id,
  required ShoppingListType type,
  required ShoppingListStatus status,
  DateTime? shoppingDate,
  int itemCount = 2,
}) {
  final date = shoppingDate ?? DateTime(2026, 7);
  return ShoppingListRecord(
    id: id,
    householdId: 'solo-household',
    type: type,
    shoppingDate: date,
    generatedForRangeStart: date,
    generatedForRangeEnd: date,
    status: status,
    createdAt: date,
    updatedAt: date,
    items: [
      for (var i = 0; i < itemCount; i++)
        ShoppingListItemRecord(
          id: '$id-item-$i',
          shoppingListId: id,
          ingredientId: i.isEven ? 'beans' : 'tomato',
          quantityNeeded: i + 1,
          unit: UnitId.piece,
          status: ShoppingListItemStatus.unchecked,
          sourceMealLinks: const [],
        ),
    ],
  );
}

void main() {
  testWidgets(
    'ShoppingScreen renders the Shop Now card, upcoming and history',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeShoppingRepository([
        _shoppingRecord(
          id: 'scheduled',
          type: ShoppingListType.scheduled,
          status: ShoppingListStatus.pending,
          shoppingDate: DateTime(2026, 7, 6),
          itemCount: 3,
        ),
        _shoppingRecord(
          id: 'done',
          type: ShoppingListType.shopNow,
          status: ShoppingListStatus.completed,
        ),
      ]);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(const ShoppingScreen(), shoppingRepository: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Knock out next week early?'), findsOneWidget);
      expect(find.text('Start a shop'), findsOneWidget);
      expect(find.text('Scheduled list'), findsOneWidget);
      expect(find.text('6 Jul · 3 items'), findsOneWidget);
      expect(find.text('1 Jul · 2 items · Shop Now'), findsOneWidget);
    },
  );

  testWidgets('ShoppingScreen shows suggested lists separately from upcoming', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([
      _shoppingRecord(
        id: 'suggested',
        type: ShoppingListType.suggested,
        status: ShoppingListStatus.pending,
        shoppingDate: DateTime(2026, 7, 6),
        itemCount: 1,
      ),
      _shoppingRecord(
        id: 'emergency',
        type: ShoppingListType.emergency,
        status: ShoppingListStatus.pending,
        shoppingDate: DateTime(2026, 7, 7),
      ),
      _shoppingRecord(
        id: 'scheduled',
        type: ShoppingListType.scheduled,
        status: ShoppingListStatus.pending,
        shoppingDate: DateTime(2026, 7, 8),
        itemCount: 3,
      ),
    ]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(const ShoppingScreen(), shoppingRepository: repo),
    );
    await tester.pumpAndSettle();

    expect(find.text('SUGGESTIONS'), findsOneWidget);
    expect(find.text('Suggested list'), findsOneWidget);
    expect(find.text('Emergency list'), findsOneWidget);
    expect(find.text('1 item · 6 Jul'), findsOneWidget);
    expect(find.text('2 items · 7 Jul'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Scheduled list'), findsOneWidget);
    expect(find.text('8 Jul · 3 items'), findsOneWidget);
  });

  testWidgets('ShoppingScreen can ignore a suggested list', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([
      _shoppingRecord(
        id: 'suggested',
        type: ShoppingListType.suggested,
        status: ShoppingListStatus.pending,
        shoppingDate: DateTime(2026, 7, 6),
      ),
    ]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(
        const Scaffold(body: ShoppingScreen()),
        shoppingRepository: repo,
        pantryRepository: _MockPantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ignore suggestion'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Ignore suggestion'));
    await tester.tap(find.byTooltip('Ignore suggestion'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repo.lists, isEmpty);
    expect(find.text('Suggested list ignored'), findsOneWidget);
    expect(find.text('SUGGESTIONS'), findsNothing);
  });

  testWidgets('ShoppingScreen accepts a suggested list by opening it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([
      _shoppingRecord(
        id: 'suggested',
        type: ShoppingListType.suggested,
        status: ShoppingListStatus.pending,
        shoppingDate: DateTime(2026, 7, 6),
      ),
    ]);
    addTearDown(repo.dispose);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/shop',
      routes: [
        GoRoute(
          path: '/shop',
          builder: (context, state) => const ShoppingScreen(),
          routes: [
            GoRoute(
              path: 'list/:listId',
              builder: (context, state) =>
                  Text('list ${state.pathParameters['listId']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          shoppingRepositoryProvider.overrideWithValue(repo),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Accept suggestion'));
    await tester.pumpAndSettle();

    expect(find.text('list suggested'), findsOneWidget);
  });

  testWidgets('ShoppingScreen opens the Shop Now "how far ahead?" sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(const ShoppingScreen(), shoppingRepository: repo),
    );
    await tester.pumpAndSettle();

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
    final pantry = _FakePantryRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 6, 9))),
        recipeRepositoryProvider.overrideWithValue(
          _FakeRecipeRepository(recipes: {'braise': _recipe('braise')}),
        ),
        shoppingRepositoryProvider.overrideWithValue(repo),
        pantryRepositoryProvider.overrideWithValue(pantry),
        purchaseHistoryRepositoryProvider.overrideWithValue(
          _FakePurchaseHistoryRepository(),
        ),
        wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
        calendarRepositoryProvider.overrideWithValue(
          _FakeCalendarRepository(meals: [_meal()]),
        ),
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

    expect(repo.lists, hasLength(1));
    expect(repo.lists.single.type, ShoppingListType.shopNow);
    expect(repo.lists.single.items, isNotEmpty);
    expect(find.text('Done shopping'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
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
