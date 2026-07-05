import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
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

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository({this.stockTomato = true});

  final bool stockTomato;
  final addedItems = <PantryItem>[];
  final quantities = <String, double>{};

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => const Stream.empty();

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      const Stream.empty();

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async => null;

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required Unit unit,
    required PantrySection section,
  }) async {
    if (!stockTomato) return null;
    if (ingredientId != 'tomato' || unit != Unit.g) return null;
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
  Future<void> update(PantryItem item) async {}

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
  }) async {}
}

class _FakeShoppingRepository implements ShoppingRepository {
  ShoppingListRecord? upserted;

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      const Stream.empty();

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => const Stream.empty();

  @override
  Future<void> upsertList(ShoppingListRecord list) async {
    upserted = list;
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
  }) async {}
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

class _FakeRecipeRepository implements RecipeRepository {
  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      const Stream.empty();

  @override
  Stream<Recipe?> watchById(String recipeId) {
    final now = DateTime(2026, 7);
    final name = switch (recipeId) {
      'oats' => 'Overnight oats',
      'salad' => 'Chickpea salad',
      _ => 'Tomato & white bean braise',
    };
    return Stream.value(
      Recipe(
        id: recipeId,
        authorUserId: 'user-1',
        householdId: 'solo-household',
        name: name,
        description: '',
        defaultServingSize: 2,
        mealTimeTags: const ['Dinner'],
        recipeTags: const [],
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
            unit: Unit.g,
          ),
        ],
        instructions: const [],
      ),
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
  return ProviderScope(
    overrides: [
      activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
      calendarRepositoryProvider.overrideWithValue(calendarRepository),
      pantryRepositoryProvider.overrideWithValue(pantryRepository),
      purchaseHistoryRepositoryProvider.overrideWithValue(
        _FakePurchaseHistoryRepository(),
      ),
      wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
      shoppingRepositoryProvider.overrideWithValue(shopping),
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
    expect(find.text('Leftovers'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);
    expect(find.text('Cook next'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
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
      expect(shopping.upserted?.type, ShoppingListType.emergency);
      expect(shopping.upserted?.items.single.ingredientId, 'tomato');
      expect(shopping.upserted?.items.single.quantityNeeded, 800);
      expect(find.text('Emergency shopping list created.'), findsOneWidget);
    },
  );

  testWidgets('DayViewScreen saves leftovers and links them to the meal', (
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

    await tester.tap(find.text('Leftovers'));
    await tester.pumpAndSettle();

    expect(pantry.addedItems.single.section, PantrySection.leftover);
    expect(pantry.addedItems.single.relatedRecipeId, 'braise');
    expect(pantry.addedItems.single.leftoverServings, 2);
    expect(calendar.upserted?.state, ScheduledMealState.leftover);
    expect(calendar.upserted?.marking, ScheduledMealMarking.leftoverScheduled);
    expect(calendar.upserted?.linkedLeftoverId, 'leftover-1');
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
