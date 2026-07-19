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
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/consumption_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_list_screen.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(
  Widget home, {
  ThemeData? theme,
  ActiveHouseholdContext activeHousehold = _activeHousehold,
  ShoppingRepository? shoppingRepository,
  PantryRepository? pantryRepository,
  CalendarRepository? calendarRepository,
  RecipeRepository? recipeRepository,
  ShoppingScheduleRepository? shoppingScheduleRepository,
  ShoppingCommandRepository? shoppingCommandRepository,
  Clock? clock,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final shopping = shoppingRepository ?? _FakeShoppingRepository();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (clock != null) clockProvider.overrideWithValue(clock),
    activeHouseholdContextProvider.overrideWithValue(activeHousehold),
    recipeRepositoryProvider.overrideWithValue(
      recipeRepository ?? _FakeRecipeRepository(),
    ),
    calendarRepositoryProvider.overrideWithValue(
      calendarRepository ?? _FakeCalendarRepository(),
    ),
    purchaseHistoryRepositoryProvider.overrideWithValue(
      _FakePurchaseHistoryRepository(),
    ),
    consumptionHistoryRepositoryProvider.overrideWithValue(
      _FakeConsumptionHistoryRepository(),
    ),
    wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
    shoppingRepositoryProvider.overrideWithValue(shopping),
    if (shoppingCommandRepository != null)
      shoppingCommandRepositoryProvider.overrideWithValue(
        shoppingCommandRepository,
      )
    else if (shopping is _FakeShoppingRepository)
      shoppingCommandRepositoryProvider.overrideWithValue(
        _FakeShoppingCommandRepository(shopping),
      ),
    if (shoppingCommandRepository
        case final ShoppingAllocationCommandRepository allocation)
      shoppingAllocationCommandRepositoryProvider.overrideWithValue(allocation)
    else if (shopping is _FakeShoppingRepository)
      shoppingAllocationCommandRepositoryProvider.overrideWithValue(
        _FakeShoppingCommandRepository(shopping),
      ),
    pantryRepositoryProvider.overrideWithValue(
      pantryRepository ?? _FakePantryRepository(),
    ),
    shoppingScheduleRepositoryProvider.overrideWithValue(
      shoppingScheduleRepository ?? const _FakeShoppingScheduleRepository(),
    ),
  ];
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: home),
  );
}

class _MockPantryRepository extends Mock implements PantryRepository {}

class _FakeConsumptionHistoryRepository
    implements ConsumptionHistoryRepository {
  @override
  Stream<List<ConsumptionEvent>> watchByHousehold(String householdId) =>
      Stream.value(const []);

  @override
  Future<void> add(ConsumptionEvent event) async {}
}

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

class _FakeShoppingScheduleRepository implements ShoppingScheduleRepository {
  const _FakeShoppingScheduleRepository([this.schedule]);

  final ShoppingSchedule? schedule;

  @override
  Future<void> save(ShoppingSchedule schedule) async {}

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(schedule);
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

const _shopperHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.shopper,
  isJoint: true,
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
  _FakeCalendarRepository({
    List<MealScheduleEntry>? meals,
    List<CalendarDaySettings>? daySettings,
  }) : meals = meals ?? const [],
       daySettings = daySettings ?? const [];

  final List<MealScheduleEntry> meals;
  final List<CalendarDaySettings> daySettings;

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
    meals.add(entry);
  }

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {}

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.value(daySettings);

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

class _FailingOnceCalendarRepository extends _FakeCalendarRepository {
  _FailingOnceCalendarRepository({
    required super.meals,
    required super.daySettings,
  });

  int activeSettingsWatchCount = 0;

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(String householdId) {
    activeSettingsWatchCount++;
    if (activeSettingsWatchCount == 1) {
      return Stream.error(StateError('transient calendar read failure'));
    }
    return super.watchActiveDaySettings(householdId);
  }
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

class _FakeShoppingRepository extends ShoppingRepository {
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

  void store(ShoppingListRecord list) {
    lists
      ..removeWhere((current) => current.id == list.id)
      ..add(list);
    _controller.add(List<ShoppingListRecord>.unmodifiable(lists));
  }

  void remove(String householdId, String listId) {
    lists.removeWhere(
      (list) => list.householdId == householdId && list.id == listId,
    );
    _controller.add(List<ShoppingListRecord>.unmodifiable(lists));
  }
}

class _FakeShoppingCommandRepository
    implements ShoppingAllocationCommandRepository {
  _FakeShoppingCommandRepository(this.shopping, {this.failUpserts = false});

  final _FakeShoppingRepository shopping;
  final bool failUpserts;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    if (failUpserts) {
      throw StateError('temporary trusted command failure');
    }
    final intent = command.intent;
    final (id, type, shoppingDate) = switch (intent) {
      ScheduledShoppingAllocationIntent() => (
        ShoppingListRecord.weeklyOccurrenceListId(intent.occurrenceDate),
        ShoppingListType.scheduled,
        intent.occurrenceDate,
      ),
      SuggestedShoppingAllocationIntent() => (
        'suggested_${intent.originId}',
        ShoppingListType.suggested,
        intent.startDate,
      ),
      ShopNowShoppingAllocationIntent() => (
        'shop_now_${intent.startDate.toIso8601String()}',
        ShoppingListType.shopNow,
        intent.startDate,
      ),
      EmergencyShoppingAllocationIntent() => (
        'emergency_${intent.startDate.toIso8601String()}',
        ShoppingListType.emergency,
        intent.startDate,
      ),
    };
    final originId = switch (intent) {
      ScheduledShoppingAllocationIntent() => intent.scheduleKey,
      SuggestedShoppingAllocationIntent() => intent.originId,
      ShopNowShoppingAllocationIntent() => null,
      EmergencyShoppingAllocationIntent() => null,
    };
    shopping.store(
      ShoppingListRecord(
        id: id,
        householdId: intent.householdId,
        type: type,
        shoppingDate: shoppingDate,
        generatedForRangeStart: intent.startDate,
        generatedForRangeEnd: intent.endDate,
        status: ShoppingListStatus.pending,
        originId: originId,
        createdAt: intent.startDate,
        updatedAt: intent.startDate,
        items: [
          ShoppingListItemRecord(
            id: 'server-item-$id',
            shoppingListId: id,
            ingredientId: 'tomato',
            quantityNeeded: 1,
            unit: UnitId.g,
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: const [],
          ),
        ],
      ),
    );
    return ShoppingCommandResult(
      listId: id,
      status: ShoppingCommandStatus.pending,
      revision: 0,
      alreadyApplied: false,
    );
  }

  @override
  Future<ShoppingCommandResult> upsertList(
    ShoppingListUpsertCommand command,
  ) async {
    if (failUpserts) {
      throw StateError('temporary trusted command failure');
    }
    ShoppingListRecord? existing;
    for (final list in shopping.lists) {
      if (list.id == command.listId) {
        existing = list;
        break;
      }
    }
    final revision = existing == null ? 0 : existing.revision + 1;
    shopping.store(_shoppingListWith(command.list, revision: revision));
    return ShoppingCommandResult(
      listId: command.listId,
      status: _commandStatus(command.list.status),
      revision: revision,
      alreadyApplied: false,
    );
  }

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ShoppingCommandResult> completeList(
    ShoppingCommandRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ShoppingCommandResult> deleteList(
    ShoppingCommandRequest request,
  ) async {
    shopping.remove(request.householdId, request.listId);
    return ShoppingCommandResult(
      listId: request.listId,
      status: ShoppingCommandStatus.deleted,
      alreadyApplied: false,
    );
  }
}

ShoppingCommandStatus _commandStatus(ShoppingListStatus status) =>
    switch (status) {
      ShoppingListStatus.pending => ShoppingCommandStatus.pending,
      ShoppingListStatus.cancelled => ShoppingCommandStatus.cancelled,
      ShoppingListStatus.completed => ShoppingCommandStatus.completed,
    };

ShoppingListRecord _shoppingListWith(
  ShoppingListRecord list, {
  required int revision,
}) => ShoppingListRecord(
  id: list.id,
  householdId: list.householdId,
  type: list.type,
  shoppingDate: list.shoppingDate,
  generatedForRangeStart: list.generatedForRangeStart,
  generatedForRangeEnd: list.generatedForRangeEnd,
  status: list.status,
  originId: list.originId,
  completionId: list.completionId,
  completedAt: list.completedAt,
  completedByUserId: list.completedByUserId,
  schemaVersion: list.schemaVersion,
  revision: revision,
  createdAt: list.createdAt,
  updatedAt: list.updatedAt,
  items: list.items,
);

ShoppingListRecord _shoppingRecord({
  required String id,
  required ShoppingListType type,
  required ShoppingListStatus status,
  DateTime? shoppingDate,
  String? originId,
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
    originId: originId,
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
      expect(find.text('See all'), findsOneWidget);
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
        originId: 'recovery:core:v1',
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

  testWidgets(
    'ShoppingScreen keeps premium suggestions separate from core ignore',
    (tester) async {
      final repo = _FakeShoppingRepository([
        _shoppingRecord(
          id: 'premium-suggestion',
          type: ShoppingListType.suggested,
          status: ShoppingListStatus.pending,
          originId: 'bulk:prediction:v1',
        ),
      ]);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(const ShoppingScreen(), shoppingRepository: repo),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open suggestion'), findsOneWidget);
      expect(find.byTooltip('Ignore suggestion'), findsNothing);
    },
  );

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
          shoppingCommandRepositoryProvider.overrideWithValue(
            _FakeShoppingCommandRepository(repo),
          ),
          shoppingAllocationCommandRepositoryProvider.overrideWithValue(
            _FakeShoppingCommandRepository(repo),
          ),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository(),
          ),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository()),
          shoppingScheduleRepositoryProvider.overrideWithValue(
            const _FakeShoppingScheduleRepository(),
          ),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          consumptionHistoryRepositoryProvider.overrideWithValue(
            _FakeConsumptionHistoryRepository(),
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

    await tester.tap(find.byTooltip('Open suggestion'));
    await tester.pumpAndSettle();

    expect(find.text('list suggested'), findsOneWidget);
  });

  testWidgets(
    'ShoppingScreen reconciles core recovery on home load for Shopper',
    (tester) async {
      final repo = _FakeShoppingRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        await _wrap(
          const ShoppingScreen(),
          activeHousehold: _shopperHousehold,
          shoppingRepository: repo,
          pantryRepository: _FakePantryRepository(),
          calendarRepository: _FakeCalendarRepository(
            meals: [_meal().copyWith(date: DateTime(2026, 7, 12))],
          ),
          recipeRepository: _FakeRecipeRepository(
            recipes: {'braise': _recipe('braise')},
          ),
          clock: FakeClock(DateTime(2026, 7, 12, 9)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        repo.lists.where((list) => list.originId == 'recovery:core:v1'),
        hasLength(1),
      );
    },
  );

  testWidgets('ShoppingScreen does not reconcile core recovery for Member', (
    tester,
  ) async {
    final repo = _FakeShoppingRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      await _wrap(
        const ShoppingScreen(),
        activeHousehold: const ActiveHouseholdContext(
          id: 'solo-household',
          name: 'Test kitchen',
          role: HouseholdRole.member,
          isJoint: true,
          hasPremium: false,
        ),
        shoppingRepository: repo,
        pantryRepository: _FakePantryRepository(),
        calendarRepository: _FakeCalendarRepository(
          meals: [_meal().copyWith(date: DateTime(2026, 7, 12))],
        ),
        recipeRepository: _FakeRecipeRepository(
          recipes: {'braise': _recipe('braise')},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lists, isEmpty);
  });

  testWidgets(
    'ShoppingScreen Shop Now previews actual items for compact ranges',
    (tester) async {
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
      for (final label in ['1 day', '3 days', '7 days', '14 days']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Custom end date'), findsOneWidget);
      for (final count in [11, 20, 28]) {
        expect(find.text('$count items'), findsNothing);
      }
      expect(find.text('Generate list'), findsOneWidget);
    },
  );

  testWidgets('Shop Now disables generation when the preview has no items', (
    tester,
  ) async {
    final repo = _FakeShoppingRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      await _wrap(
        const ShoppingScreen(),
        shoppingRepository: repo,
        calendarRepository: _FakeCalendarRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start a shop'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to buy for this range.'), findsOneWidget);
    expect(
      find.text(
        'Choose a longer range or plan meals before generating a list.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Generate list'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('ShoppingScreen keeps an empty-range explanation '
      'after cancelling custom date picker', (tester) async {
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
    await tester.tap(find.text('Custom end date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Generate list'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        'Choose a longer range or plan meals before generating a list.',
      ),
      findsOneWidget,
    );
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
        shoppingCommandRepositoryProvider.overrideWithValue(
          _FakeShoppingCommandRepository(repo),
        ),
        shoppingAllocationCommandRepositoryProvider.overrideWithValue(
          _FakeShoppingCommandRepository(repo),
        ),
        pantryRepositoryProvider.overrideWithValue(pantry),
        purchaseHistoryRepositoryProvider.overrideWithValue(
          _FakePurchaseHistoryRepository(),
        ),
        consumptionHistoryRepositoryProvider.overrideWithValue(
          _FakeConsumptionHistoryRepository(),
        ),
        wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
        calendarRepositoryProvider.overrideWithValue(
          _FakeCalendarRepository(meals: [_meal()]),
        ),
        shoppingScheduleRepositoryProvider.overrideWithValue(
          const _FakeShoppingScheduleRepository(),
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
    await tester.tap(find.text('14 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate list'));
    await tester.pumpAndSettle();

    final shopNow = repo.lists.singleWhere(
      (list) => list.type == ShoppingListType.shopNow,
    );
    expect(shopNow.generatedForRangeStart, DateTime(2026, 7, 6));
    expect(shopNow.generatedForRangeEnd, DateTime(2026, 7, 19));
    expect(shopNow.items, isNotEmpty);
    expect(find.text('Done shopping'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
  });

  testWidgets(
    'ShoppingScreen keeps a failed Shop Now generation visible and retryable',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakeShoppingRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(
          const ShoppingScreen(),
          shoppingRepository: repo,
          shoppingCommandRepository: _FakeShoppingCommandRepository(
            repo,
            failUpserts: true,
          ),
          calendarRepository: _FakeCalendarRepository(meals: [_meal()]),
          recipeRepository: _FakeRecipeRepository(
            recipes: {'braise': _recipe('braise')},
          ),
          clock: FakeClock(DateTime(2026, 7, 6, 9)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start a shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate list'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not generate this list'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Shop how far ahead?'), findsOneWidget);
      expect(repo.lists, isEmpty);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not generate this list'),
        findsOneWidget,
      );
      expect(find.text('Shop how far ahead?'), findsOneWidget);
      expect(repo.lists, isEmpty);
    },
  );

  testWidgets('ShoppingScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(const ShoppingScreen(), theme: AppTheme.dark()),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ShoppingScreen Solo Admin reconciles active calendar ranges', (
    tester,
  ) async {
    final repo = _FakeShoppingRepository();
    addTearDown(repo.dispose);
    final schedule = ShoppingSchedule(
      householdId: 'solo-household',
      cadence: ShoppingScheduleCadence.weekly,
      isoWeekday: DateTime.sunday,
      effectiveFrom: DateTime(2026, 7, 6),
      isActive: true,
      createdAt: DateTime(2026, 7, 6),
      updatedAt: DateTime(2026, 7, 6),
      updatedByUserId: 'user-1',
    );
    final calendar = _FakeCalendarRepository(
      meals: [_meal()],
      daySettings: [
        CalendarDaySettings(
          id: 'active-week',
          householdId: 'solo-household',
          dateRangeStart: DateTime(2026, 7, 6),
          dateRangeEnd: DateTime(2026, 7, 12),
          mealsPerDay: 3,
          dishesPerMeal: 1,
          mealModeName: 'standard',
          isActive: true,
        ),
      ],
    );

    await tester.pumpWidget(
      await _wrap(
        const ShoppingScreen(),
        shoppingRepository: repo,
        pantryRepository: _FakePantryRepository(),
        calendarRepository: calendar,
        recipeRepository: _FakeRecipeRepository(
          recipes: {'braise': _recipe('braise')},
        ),
        shoppingScheduleRepository: _FakeShoppingScheduleRepository(schedule),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lists, hasLength(1));
    expect(repo.lists.single.type, ShoppingListType.scheduled);
    expect(repo.lists.single.id, 'scheduled_weekly_20260712');
  });

  testWidgets(
    'ShoppingScreen reconciles again when its persistent tab becomes visible',
    (tester) async {
      final repo = _FakeShoppingRepository();
      addTearDown(repo.dispose);
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final schedule = ShoppingSchedule(
        householdId: 'solo-household',
        cadence: ShoppingScheduleCadence.weekly,
        isoWeekday: DateTime.sunday,
        effectiveFrom: DateTime(2026, 7, 6),
        isActive: true,
        createdAt: DateTime(2026, 7, 6),
        updatedAt: DateTime(2026, 7, 6),
        updatedByUserId: 'user-1',
      );
      final calendar = _FakeCalendarRepository(
        meals: [_meal()],
        daySettings: [
          CalendarDaySettings(
            id: 'active-week',
            householdId: 'solo-household',
            dateRangeStart: DateTime(2026, 7, 6),
            dateRangeEnd: DateTime(2026, 7, 12),
            mealsPerDay: 3,
            dishesPerMeal: 1,
            mealModeName: 'standard',
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        await _wrap(
          ValueListenableBuilder<bool>(
            valueListenable: visibility,
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: const ShoppingScreen(),
          ),
          shoppingRepository: repo,
          pantryRepository: _FakePantryRepository(),
          calendarRepository: calendar,
          recipeRepository: _FakeRecipeRepository(
            recipes: {'braise': _recipe('braise')},
          ),
          shoppingScheduleRepository: _FakeShoppingScheduleRepository(schedule),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lists.single.items, isNotEmpty);

      visibility.value = false;
      await tester.pump();
      calendar.meals[0] = _meal().copyWith(state: ScheduledMealState.cooked);
      visibility.value = true;
      await tester.pumpAndSettle();

      expect(repo.lists.single.items, isNotEmpty);
    },
  );

  testWidgets(
    'ShoppingScreen retries a transient reconciliation failure on next load',
    (tester) async {
      final repo = _FakeShoppingRepository();
      addTearDown(repo.dispose);
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final schedule = ShoppingSchedule(
        householdId: 'solo-household',
        cadence: ShoppingScheduleCadence.weekly,
        isoWeekday: DateTime.sunday,
        effectiveFrom: DateTime(2026, 7, 6),
        isActive: true,
        createdAt: DateTime(2026, 7, 6),
        updatedAt: DateTime(2026, 7, 6),
        updatedByUserId: 'user-1',
      );
      final calendar = _FailingOnceCalendarRepository(
        meals: [_meal()],
        daySettings: [
          CalendarDaySettings(
            id: 'active-week',
            householdId: 'solo-household',
            dateRangeStart: DateTime(2026, 7, 6),
            dateRangeEnd: DateTime(2026, 7, 12),
            mealsPerDay: 3,
            dishesPerMeal: 1,
            mealModeName: 'standard',
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        await _wrap(
          ValueListenableBuilder<bool>(
            valueListenable: visibility,
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: const ShoppingScreen(),
          ),
          shoppingRepository: repo,
          pantryRepository: _FakePantryRepository(),
          calendarRepository: calendar,
          recipeRepository: _FakeRecipeRepository(
            recipes: {'braise': _recipe('braise')},
          ),
          shoppingScheduleRepository: _FakeShoppingScheduleRepository(schedule),
        ),
      );
      await tester.pump();
      expect(calendar.activeSettingsWatchCount, 1);

      visibility.value = false;
      await tester.pump();
      visibility.value = true;
      await tester.pumpAndSettle();

      expect(calendar.activeSettingsWatchCount, 2);
      expect(repo.lists, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ShoppingScreen joint Shopper reconciles merged active calendar ranges',
    (tester) async {
      final repo = _FakeShoppingRepository();
      addTearDown(repo.dispose);
      final schedule = ShoppingSchedule(
        householdId: 'solo-household',
        cadence: ShoppingScheduleCadence.weekly,
        isoWeekday: DateTime.sunday,
        effectiveFrom: DateTime(2026, 7, 6),
        isActive: true,
        createdAt: DateTime(2026, 7, 6),
        updatedAt: DateTime(2026, 7, 6),
        updatedByUserId: 'user-1',
      );
      final calendar = _FakeCalendarRepository(
        meals: [
          _meal(),
          MealScheduleEntry(
            id: 'meal-2',
            recipeId: 'braise',
            date: DateTime(2026, 7, 14),
            mealLabel: 'Dinner',
            servingSize: 4,
          ),
        ],
        daySettings: [
          CalendarDaySettings(
            id: 'first-active-range',
            householdId: 'solo-household',
            dateRangeStart: DateTime(2026, 7, 6),
            dateRangeEnd: DateTime(2026, 7, 12),
            mealsPerDay: 3,
            dishesPerMeal: 1,
            mealModeName: 'standard',
            isActive: true,
          ),
          CalendarDaySettings(
            id: 'overlapping-active-range',
            householdId: 'solo-household',
            dateRangeStart: DateTime(2026, 7, 10),
            dateRangeEnd: DateTime(2026, 7, 19),
            mealsPerDay: 3,
            dishesPerMeal: 1,
            mealModeName: 'standard',
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        await _wrap(
          const ShoppingScreen(),
          activeHousehold: _shopperHousehold,
          shoppingRepository: repo,
          pantryRepository: _FakePantryRepository(),
          calendarRepository: calendar,
          recipeRepository: _FakeRecipeRepository(
            recipes: {'braise': _recipe('braise')},
          ),
          shoppingScheduleRepository: _FakeShoppingScheduleRepository(schedule),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        repo.lists.map((list) => list.id),
        containsAll(['scheduled_weekly_20260712', 'scheduled_weekly_20260719']),
      );
    },
  );

  testWidgets('ShoppingScreen renders persisted empty occurrences', (
    tester,
  ) async {
    final repo = _FakeShoppingRepository([
      _shoppingRecord(
        id: 'scheduled-empty',
        type: ShoppingListType.scheduled,
        status: ShoppingListStatus.pending,
        shoppingDate: DateTime(2026, 7, 12),
        itemCount: 0,
      ),
    ]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(const ShoppingScreen(), shoppingRepository: repo),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing to buy'), findsOneWidget);
    expect(find.textContaining('0 items'), findsNothing);
  });

  testWidgets('ShoppingScreen shows honest empty state with no lists', (
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

    // With no persisted lists the Upcoming and History empty states show.
    expect(find.text('No shopping lists yet'), findsOneWidget);
    expect(find.text('No completed shops yet.'), findsOneWidget);
    expect(find.text('SUGGESTIONS'), findsNothing);
  });

  testWidgets('ShoppingScreen surfaces a lists load error', (tester) async {
    final repo = _ErroringShoppingRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(const ShoppingScreen(), shoppingRepository: repo),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load shopping'), findsOneWidget);
  });
}

/// A shopping repository whose list stream fails, to exercise the home
/// surface's honest error branch (`Could not load shopping`).
class _ErroringShoppingRepository extends _FakeShoppingRepository {
  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.error(StateError('transient shopping read failure'));
}
