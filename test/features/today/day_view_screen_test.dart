// SIZE_OK: day view tests cover existing multi-feature daily UI surface.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
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
import 'package:kitchensync/features/today/presentation/screens/day_view_screen.dart';

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository({List<MealScheduleEntry>? meals})
    : _meals = meals ?? [_scheduledDinner];

  final List<MealScheduleEntry> _meals;
  MealScheduleEntry? upserted;

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(
    _meals
        .where((meal) {
          final date = DateTime(meal.date.year, meal.date.month, meal.date.day);
          return !date.isBefore(startDate) && !date.isAfter(endDate);
        })
        .toList(growable: false),
  );

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {
    upserted = entry;
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

final _scheduledDinner = MealScheduleEntry(
  id: 'existing-dinner',
  recipeId: 'braise',
  date: DateTime(2026, 7, 6),
  mealLabel: 'Dinner',
  servingSize: 4,
);

final _cookedDinner = _scheduledDinner.copyWith(
  state: ScheduledMealState.cooked,
);

final _leftoverDinner = _scheduledDinner.copyWith(
  servingSize: 3,
  state: ScheduledMealState.leftover,
  marking: ScheduledMealMarking.leftoverScheduled,
  linkedLeftoverId: 'leftover-1',
);

final _leftoverPantryItem = PantryItem(
  id: 'leftover-1',
  householdId: 'solo-household',
  ingredientId: 'tomato',
  quantity: 3,
  unit: UnitId.serving,
  section: PantrySection.leftover,
  relatedRecipeId: 'braise',
  leftoverServings: 3,
  expiryDate: DateTime(2026, 7, 9),
  createdAt: DateTime(2026, 7, 6),
  updatedAt: DateTime(2026, 7, 6),
);

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository({
    this.stockTomato = true,
    List<PantryItem> items = const [],
  }) : addedItems = [...items];

  final bool stockTomato;
  final List<PantryItem> addedItems;
  final quantities = <String, double>{};
  PantryItem? updatedItem;
  WasteEvent? wasteEvent;
  double? wasteRemainingQuantity;

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => const Stream.empty();

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      Stream.value(addedItems.where((item) => item.id == itemId).firstOrNull);

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
  }) async {
    if (!stockTomato) return null;
    if (ingredientId != 'tomato' || unit != UnitId.g) return null;
    final now = DateTime(2026, 7);
    return PantryItem(
      id: 'pantry-tomato',
      householdId: householdId,
      ingredientId: ingredientId,
      quantity: 1000,
      unit: unit,
      section: section,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> add(PantryItem item) async {
    addedItems.add(item);
  }

  @override
  Future<void> update(PantryItem item) async {
    updatedItem = item;
  }

  @override
  Future<void> setQuantity(
    String householdId,
    String itemId,
    double newQty,
  ) async {
    quantities[itemId] = newQty;
  }

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
  }) async {
    this.wasteEvent = wasteEvent;
    wasteRemainingQuantity = newPantryQuantity;
  }
}

class _FakeShoppingRepository extends ShoppingRepository {
  ShoppingListRecord? upserted;

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.value(upserted == null ? const [] : [upserted!]);

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(upserted?.id == listId ? upserted : null);
}

class _FakeShoppingCommandRepository
    implements ShoppingAllocationCommandRepository {
  _FakeShoppingCommandRepository(this.shopping);

  final _FakeShoppingRepository shopping;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    const listId = 'server-emergency-list';
    shopping.upserted = ShoppingListRecord(
      id: listId,
      householdId: command.intent.householdId,
      type: ShoppingListType.emergency,
      shoppingDate: command.intent.startDate,
      generatedForRangeStart: command.intent.startDate,
      generatedForRangeEnd: command.intent.endDate,
      status: ShoppingListStatus.pending,
      createdAt: command.intent.startDate,
      updatedAt: command.intent.startDate,
      items: [
        const ShoppingListItemRecord(
          id: 'server-tomato',
          shoppingListId: listId,
          ingredientId: 'tomato',
          quantityNeeded: 800,
          unit: UnitId.g,
          status: ShoppingListItemStatus.unchecked,
          sourceMealLinks: [],
        ),
      ],
    );
    return const ShoppingCommandResult(
      listId: listId,
      status: ShoppingCommandStatus.pending,
      revision: 0,
      alreadyApplied: false,
    );
  }

  @override
  Future<ShoppingCommandResult> upsertList(
    ShoppingListUpsertCommand command,
  ) async {
    final currentRevision = shopping.upserted?.revision;
    if (command.expectedRevision != currentRevision) {
      throw StateError('Unexpected shopping list revision.');
    }
    final revision = currentRevision == null ? 0 : currentRevision + 1;
    shopping.upserted = _withRevision(command.list, revision);
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
  ) => throw UnsupportedError('Item mutations are not used in these tests.');

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      throw UnsupportedError('List completion is not used in these tests.');

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) =>
      throw UnsupportedError('List deletion is not used in these tests.');
}

ShoppingCommandStatus _commandStatus(ShoppingListStatus status) =>
    switch (status) {
      ShoppingListStatus.pending => ShoppingCommandStatus.pending,
      ShoppingListStatus.cancelled => ShoppingCommandStatus.cancelled,
      ShoppingListStatus.completed => ShoppingCommandStatus.completed,
    };

ShoppingListRecord _withRevision(ShoppingListRecord list, int revision) =>
    ShoppingListRecord(
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

class _EmptyShoppingScheduleRepository implements ShoppingScheduleRepository {
  const _EmptyShoppingScheduleRepository();

  @override
  Future<void> save(ShoppingSchedule schedule) async {}

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(null);
}

class _FakePurchaseHistoryRepository implements PurchaseHistoryRepository {
  @override
  Stream<List<PurchaseRecord>> watchByHousehold(String householdId) =>
      Stream.value(const []);

  @override
  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  ) => Stream.value(const []);

  @override
  Future<void> record(PurchaseRecord record) async {}
}

class _FakeWasteRepository implements WasteRepository {
  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Future<void> log(WasteEvent event) async {}
}

class _FakeConsumptionHistoryRepository
    implements ConsumptionHistoryRepository {
  @override
  Stream<List<ConsumptionEvent>> watchByHousehold(String householdId) =>
      Stream.value(const []);

  @override
  Future<void> add(ConsumptionEvent event) async {}
}

class _FakeRecipeRepository implements RecipeRepository {
  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value([_recipe('braise'), _recipe('pad-thai')]);

  @override
  Stream<Recipe?> watchById(String recipeId) {
    return Stream.value(_recipe(recipeId));
  }

  Recipe _recipe(String recipeId) {
    final now = DateTime(2026, 7);
    final name = switch (recipeId) {
      'oats' => 'Overnight oats',
      'salad' => 'Chickpea salad',
      'pad-thai' => 'Pad Thai',
      _ => 'Tomato & white bean braise',
    };
    return Recipe(
      id: recipeId,
      authorUserId: 'user-1',
      householdId: 'solo-household',
      name: name,
      description: '',
      defaultServingSize: 2,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Comfort'],
      priceEstimate: 120,
      location: '',
      visibility: RecipeVisibility.private,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      ingredients: const [
        RecipeIngredient(
          id: 'tomato-line',
          recipeId: 'braise',
          ingredientId: 'tomato',
          quantity: 400,
          unit: UnitId.g,
        ),
      ],
      instructions: const [],
    );
  }

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

Widget _wrap(
  DayViewScreen screen, {
  required _FakeCalendarRepository calendarRepository,
  required _FakePantryRepository pantryRepository,
  _FakeShoppingRepository? shoppingRepository,
  ThemeData? theme,
}) {
  final shopping = shoppingRepository ?? _FakeShoppingRepository();
  final shoppingCommands = _FakeShoppingCommandRepository(shopping);
  return ProviderScope(
    overrides: [
      activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
      calendarRepositoryProvider.overrideWithValue(calendarRepository),
      cookingInventoryServiceProvider.overrideWithValue(null),
      pantryRepositoryProvider.overrideWithValue(pantryRepository),
      purchaseHistoryRepositoryProvider.overrideWithValue(
        _FakePurchaseHistoryRepository(),
      ),
      consumptionHistoryRepositoryProvider.overrideWithValue(
        _FakeConsumptionHistoryRepository(),
      ),
      wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
      shoppingRepositoryProvider.overrideWithValue(shopping),
      shoppingCommandRepositoryProvider.overrideWithValue(shoppingCommands),
      shoppingAllocationCommandRepositoryProvider.overrideWithValue(
        shoppingCommands,
      ),
      shoppingScheduleRepositoryProvider.overrideWithValue(
        const _EmptyShoppingScheduleRepository(),
      ),
      recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
      idGeneratorProvider.overrideWithValue(
        FakeIdGenerator(['leftover-1', 'emergency-1', 'line-1']),
      ),
      clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 6, 20))),
    ],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: screen),
  );
}

void main() {
  testWidgets('DayViewScreen renders the day timeline and tonight actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: _FakeCalendarRepository(),
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monday 6'), findsOneWidget);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
    expect(find.text('Yogurt & berries'), findsNothing);
    expect(find.text('Leftover pad thai'), findsNothing);
    expect(find.text('Mark cooked'), findsOneWidget);
    expect(find.text('Servings'), findsOneWidget);
    expect(find.text('Merge 2 meals'), findsOneWidget);
    expect(find.text('Save leftovers'), findsNothing);
    expect(find.text('Schedule leftover'), findsNothing);
    expect(find.text('Mark eaten'), findsNothing);
    expect(find.text('Mark waste'), findsNothing);
    expect(find.text('Swap'), findsOneWidget);
    expect(find.text('Cook next'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Dinner · Comfort · Price 240.00'), findsOneWidget);
  });

  testWidgets(
    'DayViewScreen shows every persisted meal for the selected date',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          DayViewScreen(selectedDate: DateTime(2026, 7, 6)),
          calendarRepository: _FakeCalendarRepository(
            meals: [
              MealScheduleEntry(
                id: 'breakfast',
                recipeId: 'oats',
                date: DateTime(2026, 7, 6),
                mealLabel: 'Breakfast',
                servingSize: 2,
              ),
              MealScheduleEntry(
                id: 'lunch',
                recipeId: 'salad',
                date: DateTime(2026, 7, 6),
                mealLabel: 'Lunch',
                servingSize: 3,
              ),
              MealScheduleEntry(
                id: 'other-day',
                recipeId: 'braise',
                date: DateTime(2026, 7, 7),
                mealLabel: 'Dinner',
                servingSize: 4,
              ),
            ],
          ),
          pantryRepository: _FakePantryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overnight oats'), findsOneWidget);
      expect(find.text('Chickpea salad'), findsOneWidget);
      expect(find.text('Tomato & white bean braise'), findsNothing);
      expect(find.text('BREAKFAST · SCHEDULED'), findsOneWidget);
      expect(find.text('LUNCH · SCHEDULED'), findsOneWidget);
    },
  );

  testWidgets('DayViewScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        theme: AppTheme.dark(),
        calendarRepository: _FakeCalendarRepository(),
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('DayViewScreen mark cooked deducts pantry and updates calendar', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository();
    final pantry = _FakePantryRepository();
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: pantry,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark cooked'));
    await tester.pumpAndSettle();

    expect(pantry.quantities['pantry-tomato'], 200);
    expect(calendar.upserted?.state, ScheduledMealState.cooked);
  });

  testWidgets(
    'DayViewScreen creates emergency shopping when cooking is short',
    (tester) async {
      final calendar = _FakeCalendarRepository();
      final shopping = _FakeShoppingRepository();
      await tester.pumpWidget(
        _wrap(
          const DayViewScreen(),
          calendarRepository: calendar,
          pantryRepository: _FakePantryRepository(stockTomato: false),
          shoppingRepository: shopping,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark cooked'));
      await tester.pumpAndSettle();

      expect(calendar.upserted?.marking, ScheduledMealMarking.problem);
      expect(shopping.upserted, isNull);
      expect(find.text('Add missing items'), findsOneWidget);

      await tester.tap(find.text('Add missing items'));
      await tester.pumpAndSettle();

      expect(shopping.upserted?.type, ShoppingListType.emergency);
      expect(shopping.upserted?.items.single.ingredientId, 'tomato');
      expect(shopping.upserted?.items.single.quantityNeeded, 800);
      expect(find.text('Emergency shopping list created.'), findsOneWidget);
    },
  );

  testWidgets(
    'DayViewScreen keeps the problem state when emergency shopping is declined',
    (tester) async {
      final calendar = _FakeCalendarRepository();
      final shopping = _FakeShoppingRepository();
      await tester.pumpWidget(
        _wrap(
          const DayViewScreen(),
          calendarRepository: calendar,
          pantryRepository: _FakePantryRepository(stockTomato: false),
          shoppingRepository: shopping,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark cooked'));
      await tester.pumpAndSettle();

      expect(calendar.upserted?.marking, ScheduledMealMarking.problem);
      expect(shopping.upserted, isNull);
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(calendar.upserted?.marking, ScheduledMealMarking.problem);
      expect(shopping.upserted, isNull);
      expect(find.text('Missing pantry items'), findsNothing);
      expect(find.text('Emergency shopping list created.'), findsNothing);
    },
  );

  testWidgets('DayViewScreen saves leftovers and links them to the meal', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository(meals: [_cookedDinner]);
    final pantry = _FakePantryRepository();
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: pantry,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark cooked'), findsNothing);
    expect(find.text('Servings'), findsNothing);
    expect(find.text('Merge 2 meals'), findsNothing);
    expect(find.text('Swap'), findsNothing);
    expect(find.text('Cook next'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Save leftovers'), findsOneWidget);

    await tester.tap(find.text('Save leftovers'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Leftover servings'),
      '3',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(pantry.addedItems.single.section, PantrySection.leftover);
    expect(pantry.addedItems.single.relatedRecipeId, 'braise');
    expect(pantry.addedItems.single.leftoverServings, 3);
    expect(calendar.upserted?.state, ScheduledMealState.leftover);
    expect(calendar.upserted?.marking, ScheduledMealMarking.leftoverScheduled);
    expect(calendar.upserted?.linkedLeftoverId, 'leftover-1');
  });

  testWidgets('DayViewScreen schedules a linked leftover for a future date', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository(meals: [_leftoverDinner]);
    final pantry = _FakePantryRepository(items: [_leftoverPantryItem]);
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: pantry,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save leftovers'), findsNothing);
    expect(find.text('Schedule leftover'), findsOneWidget);
    expect(find.text('Mark eaten'), findsOneWidget);
    expect(find.text('Mark waste'), findsOneWidget);

    await tester.tap(find.text('Schedule leftover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(calendar.upserted?.id, 'leftover-meal-leftover-1');
    expect(calendar.upserted?.date, DateTime(2026, 7, 7));
    expect(calendar.upserted?.servingSize, 3);
    expect(calendar.upserted?.state, ScheduledMealState.leftover);
    expect(calendar.upserted?.marking, ScheduledMealMarking.leftoverScheduled);
  });

  testWidgets('DayViewScreen consumes a scheduled leftover', (tester) async {
    final calendar = _FakeCalendarRepository(meals: [_leftoverDinner]);
    final pantry = _FakePantryRepository(items: [_leftoverPantryItem]);
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: pantry,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark eaten'));
    await tester.pumpAndSettle();

    expect(pantry.updatedItem?.quantity, 0);
    expect(pantry.updatedItem?.leftoverServings, 0);
    expect(calendar.upserted?.state, ScheduledMealState.cooked);
  });

  testWidgets('DayViewScreen records a linked leftover as waste', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository(meals: [_leftoverDinner]);
    final pantry = _FakePantryRepository(items: [_leftoverPantryItem]);
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: pantry,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark waste'));
    await tester.pumpAndSettle();

    expect(pantry.wasteEvent?.pantryItemId, 'leftover-1');
    expect(pantry.wasteEvent?.quantity, 3);
    expect(pantry.wasteEvent?.reason, WasteReason.expired);
    expect(pantry.wasteRemainingQuantity, 0);
  });

  testWidgets('DayViewScreen hides lifecycle mutations for terminal meals', (
    tester,
  ) async {
    final cancelled = _scheduledDinner.copyWith(
      state: ScheduledMealState.cancelled,
    );
    final wasted = _leftoverDinner.copyWith(
      marking: ScheduledMealMarking.waste,
    );
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: _FakeCalendarRepository(meals: [cancelled, wasted]),
        pantryRepository: _FakePantryRepository(items: [_leftoverPantryItem]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('CANCELLED'), findsOneWidget);
    expect(find.textContaining('WASTE'), findsOneWidget);
    expect(find.text('Mark cooked'), findsNothing);
    expect(find.text('Servings'), findsNothing);
    expect(find.text('Merge 2 meals'), findsNothing);
    expect(find.text('Save leftovers'), findsNothing);
    expect(find.text('Schedule leftover'), findsNothing);
    expect(find.text('Mark eaten'), findsNothing);
    expect(find.text('Mark waste'), findsNothing);
    expect(find.text('Swap'), findsNothing);
    expect(find.text('Cook next'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('DayViewScreen serving action persists an override', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository();
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Servings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Servings'), '6');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(calendar.upserted?.servingSize, 6);
    expect(calendar.upserted?.mergedMealCount, 1);
  });

  testWidgets('DayViewScreen merge action stores merged meal sizing', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository();
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Merge 2 meals'));
    await tester.pumpAndSettle();

    expect(calendar.upserted?.servingSize, 4);
    expect(calendar.upserted?.mergedMealCount, 2);
    expect(calendar.upserted?.state, ScheduledMealState.scheduled);
  });

  testWidgets('DayViewScreen shows persisted merged meal ratio after reload', (
    tester,
  ) async {
    final merged = _scheduledDinner.copyWith(
      servingSize: 4,
      mergedMealCount: 2,
    );
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: _FakeCalendarRepository(meals: [merged]),
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Merged 2:1'), findsOneWidget);
    expect(find.text('serves 4'), findsOneWidget);
  });

  testWidgets('DayViewScreen swap action replaces the scheduled recipe', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository();
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pad Thai'));
    await tester.pumpAndSettle();

    expect(calendar.upserted?.recipeId, 'pad-thai');
    expect(calendar.upserted?.state, ScheduledMealState.scheduled);
  });

  testWidgets('DayViewScreen cook next action reschedules the meal', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository();
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cook next'));
    await tester.tap(find.text('Cook next'));
    await tester.pumpAndSettle();

    expect(calendar.upserted?.date, DateTime(2026, 7, 7));
    expect(calendar.upserted?.marking, ScheduledMealMarking.unused);
  });

  testWidgets('DayViewScreen cancel action marks the meal cancelled', (
    tester,
  ) async {
    final calendar = _FakeCalendarRepository();
    await tester.pumpWidget(
      _wrap(
        const DayViewScreen(),
        calendarRepository: calendar,
        pantryRepository: _FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(calendar.upserted?.state, ScheduledMealState.cancelled);
  });
}
