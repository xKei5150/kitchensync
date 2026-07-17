// SIZE_OK: lifecycle controller tests keep broad state-transition coverage.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_leftover.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';

class _FakeCalendarRepository implements CalendarRepository {
  MealScheduleEntry? upserted;

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

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(this.items);

  final List<PantryItem> items;
  final addedItems = <PantryItem>[];
  final quantities = <String, double>{};
  WasteEvent? wasteEvent;
  double? wasteQuantity;

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => Stream.value(const []);

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) {
    for (final item in [...items, ...addedItems]) {
      if (item.householdId == householdId && item.id == itemId) {
        return Stream.value(item);
      }
    }
    return Stream.value(null);
  }

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
    for (final item in items) {
      if (item.householdId == householdId &&
          item.ingredientId == ingredientId &&
          item.unit == unit &&
          item.section == section) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> add(PantryItem item) async {
    addedItems.add(item);
  }

  @override
  Future<void> update(PantryItem item) async {
    quantities[item.id] = item.quantity;
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
    wasteQuantity = newPantryQuantity;
  }
}

class _FakeRecipeRepository implements RecipeRepository {
  const _FakeRecipeRepository(this.recipe);

  final Recipe? recipe;

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      const Stream.empty();

  @override
  Stream<Recipe?> watchById(String recipeId) => Stream.value(recipe);

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

Recipe _recipe({bool duplicateTomato = false}) {
  final now = DateTime(2026, 7);
  return Recipe(
    id: 'braise',
    authorUserId: 'user-1',
    householdId: 'solo-household',
    name: 'Tomato & white bean braise',
    description: '',
    defaultServingSize: 2,
    mealTimeTags: const ['Dinner'],
    recipeTags: const [],
    location: '',
    visibility: RecipeVisibility.private,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: [
      const RecipeIngredient(
        id: 'tomato-line',
        recipeId: 'braise',
        ingredientId: 'tomato',
        quantity: 400,
        unit: UnitId.g,
      ),
      if (duplicateTomato)
        const RecipeIngredient(
          id: 'tomato-line-2',
          recipeId: 'braise',
          ingredientId: 'tomato',
          quantity: 100,
          unit: UnitId.g,
        ),
      const RecipeIngredient(
        id: 'bean-line',
        recipeId: 'braise',
        ingredientId: 'beans',
        quantity: 2,
        unit: UnitId.piece,
      ),
    ],
    instructions: const [],
  );
}

PantryItem _pantryItem() {
  final now = DateTime(2026, 7);
  return PantryItem(
    id: 'pantry-tomato',
    householdId: 'solo-household',
    ingredientId: 'tomato',
    quantity: 1000,
    unit: UnitId.g,
    section: PantrySection.food,
    createdAt: now,
    updatedAt: now,
  );
}

PantryItem _beanPantryItem() {
  final now = DateTime(2026, 7);
  return PantryItem(
    id: 'pantry-beans',
    householdId: 'solo-household',
    ingredientId: 'beans',
    quantity: 8,
    unit: UnitId.piece,
    section: PantrySection.food,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const premiumAdmin = ActiveHouseholdContext(
    id: 'solo-household',
    name: 'Test kitchen',
    role: HouseholdRole.admin,
    isJoint: true,
    hasPremium: true,
  );

  CookingLifecycleController controller({
    required _FakeCalendarRepository calendar,
    required _FakePantryRepository pantry,
    required Recipe? recipe,
    List<String> leftoverIds = const ['leftover-1'],
    List<String> wasteIds = const ['waste-1'],
    ActiveHouseholdContext? household = premiumAdmin,
  }) {
    final clock = FakeClock(DateTime(2026, 7, 6, 20));
    return CookingLifecycleController(
      calendarRepository: calendar,
      pantryRepository: pantry,
      recipeRepository: _FakeRecipeRepository(recipe),
      recordLeftover: RecordLeftover(
        pantry,
        idGenerator: FakeIdGenerator(leftoverIds),
        clock: clock,
      ),
      markAsWaste: MarkAsWaste(
        pantry,
        idGenerator: FakeIdGenerator(wasteIds),
        clock: clock,
      ),
      householdId: 'solo-household',
      household: household,
    );
  }

  test(
    'markCooked deducts scaled pantry quantities and persists cooked state',
    () async {
      final calendar = _FakeCalendarRepository();
      final pantry = _FakePantryRepository([_pantryItem(), _beanPantryItem()]);
      final sut = controller(
        calendar: calendar,
        pantry: pantry,
        recipe: _recipe(),
      );

      await sut.markCooked(
        MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
      );

      expect(pantry.quantities['pantry-tomato'], 200);
      expect(pantry.quantities['pantry-beans'], 4);
      expect(calendar.upserted?.state, ScheduledMealState.cooked);
      expect(calendar.upserted?.id, 'meal-1');
    },
  );

  test(
    'markCooked deducts substituted pantry items for meal overrides',
    () async {
      final calendar = _FakeCalendarRepository();
      final tomato = _pantryItem();
      final pepper = PantryItem(
        id: 'pantry-pepper',
        householdId: 'solo-household',
        ingredientId: 'pepper',
        quantity: 500,
        unit: UnitId.g,
        section: PantrySection.food,
        createdAt: DateTime(2026, 7),
        updatedAt: DateTime(2026, 7),
      );
      final pantry = _FakePantryRepository([tomato, pepper, _beanPantryItem()]);
      final sut = controller(
        calendar: calendar,
        pantry: pantry,
        recipe: _recipe(),
      );

      await sut.markCooked(
        MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
          ingredientOverrides: const [
            MealIngredientOverride(
              originalIngredientId: 'tomato',
              originalUnit: UnitId.g,
              substituteIngredientId: 'pepper',
              substituteQuantity: 300,
              substituteUnit: UnitId.g,
            ),
          ],
        ),
      );

      expect(pantry.quantities['pantry-pepper'], 200);
      expect(pantry.quantities['pantry-beans'], 4);
      expect(pantry.quantities.containsKey('pantry-tomato'), isFalse);
      expect(calendar.upserted?.state, ScheduledMealState.cooked);
    },
  );

  test(
    'markCooked combines duplicate recipe ingredient requirements',
    () async {
      final recipe = _recipe(duplicateTomato: true);
      final calendar = _FakeCalendarRepository();
      final pantry = _FakePantryRepository([_pantryItem(), _beanPantryItem()]);

      await controller(
        calendar: calendar,
        pantry: pantry,
        recipe: recipe,
      ).markCooked(
        MealScheduleEntry(
          id: 'meal-duplicate',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 2,
        ),
      );

      expect(pantry.quantities['pantry-tomato'], 500);
    },
  );

  test(
    'markCooked marks problem and reports missing ingredients before cooking',
    () async {
      final calendar = _FakeCalendarRepository();
      final pantry = _FakePantryRepository([_pantryItem()]);
      final sut = controller(
        calendar: calendar,
        pantry: pantry,
        recipe: _recipe(),
      );

      final call = sut.markCooked(
        MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
      );

      await expectLater(call, throwsA(isA<MissingMealIngredientsException>()));
      expect(calendar.upserted?.marking, ScheduledMealMarking.problem);
      expect(calendar.upserted?.state, ScheduledMealState.scheduled);
      expect(pantry.quantities, isEmpty);
    },
  );

  test('markCooked fails when the scheduled recipe is missing', () async {
    final sut = controller(
      calendar: _FakeCalendarRepository(),
      pantry: _FakePantryRepository([]),
      recipe: null,
    );

    expect(
      () => sut.markCooked(
        MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'missing',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'saveLeftovers creates a leftover pantry item and links the meal',
    () async {
      final calendar = _FakeCalendarRepository();
      final pantry = _FakePantryRepository([]);
      final sut = controller(
        calendar: calendar,
        pantry: pantry,
        recipe: _recipe(),
      );

      final leftover = await sut.saveLeftovers(
        meal: MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
        servings: 2,
      );

      expect(leftover.id, 'leftover-1');
      expect(leftover.section, PantrySection.leftover);
      expect(leftover.relatedRecipeId, 'braise');
      expect(leftover.leftoverServings, 2);
      expect(leftover.quantity, 2);
      expect(leftover.unit, UnitId.serving);
      expect(pantry.addedItems.single, leftover);
      expect(calendar.upserted?.state, ScheduledMealState.leftover);
      expect(
        calendar.upserted?.marking,
        ScheduledMealMarking.leftoverScheduled,
      );
      expect(calendar.upserted?.linkedLeftoverId, 'leftover-1');
    },
  );

  test('changeServingSize persists the scheduled serving override', () async {
    final calendar = _FakeCalendarRepository();
    final sut = controller(
      calendar: calendar,
      pantry: _FakePantryRepository([]),
      recipe: _recipe(),
    );

    await sut.changeServingSize(
      MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'braise',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
      6,
    );

    expect(calendar.upserted?.servingSize, 6);
    expect(calendar.upserted?.mergedMealCount, 1);
    expect(calendar.upserted?.recipeId, 'braise');
  });

  test(
    'mergeMeals scales servings from recipe default and stores count',
    () async {
      final calendar = _FakeCalendarRepository();
      final sut = controller(
        calendar: calendar,
        pantry: _FakePantryRepository([]),
        recipe: _recipe(),
      );

      await sut.mergeMeals(
        meal: MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
          state: ScheduledMealState.cancelled,
          marking: ScheduledMealMarking.waste,
        ),
        mealCount: 3,
      );

      expect(calendar.upserted?.id, 'meal-1');
      expect(calendar.upserted?.servingSize, 6);
      expect(calendar.upserted?.mergedMealCount, 3);
      expect(calendar.upserted?.state, ScheduledMealState.scheduled);
      expect(calendar.upserted?.marking, ScheduledMealMarking.none);
    },
  );

  test('mergeMeals requires more than one meal', () async {
    final sut = controller(
      calendar: _FakeCalendarRepository(),
      pantry: _FakePantryRepository([]),
      recipe: _recipe(),
    );

    expect(
      () => sut.mergeMeals(
        meal: MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
        mealCount: 1,
      ),
      throwsArgumentError,
    );
  });

  test('mergeMeals fails when the scheduled recipe is missing', () async {
    final sut = controller(
      calendar: _FakeCalendarRepository(),
      pantry: _FakePantryRepository([]),
      recipe: null,
    );

    expect(
      () => sut.mergeMeals(
        meal: MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'missing',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
        mealCount: 2,
      ),
      throwsStateError,
    );
  });

  test('mergeMeals requires a premium household', () async {
    final calendar = _FakeCalendarRepository();
    final sut = controller(
      calendar: calendar,
      pantry: _FakePantryRepository([]),
      recipe: _recipe(),
      household: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Test kitchen',
        role: HouseholdRole.admin,
        isJoint: true,
        hasPremium: false,
      ),
    );

    expect(
      () => sut.mergeMeals(
        meal: MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
        mealCount: 2,
      ),
      throwsStateError,
    );
    expect(calendar.upserted, isNull);
  });

  test('mergeMeals rejects read-only household members', () async {
    final calendar = _FakeCalendarRepository();
    final sut = controller(
      calendar: calendar,
      pantry: _FakePantryRepository([]),
      recipe: _recipe(),
      household: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Test kitchen',
        role: HouseholdRole.member,
        isJoint: true,
        hasPremium: true,
      ),
    );

    expect(
      () => sut.mergeMeals(
        meal: MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
        mealCount: 2,
      ),
      throwsStateError,
    );
    expect(calendar.upserted, isNull);
  });

  test('member role cannot run persisted cooking lifecycle actions', () async {
    final calendar = _FakeCalendarRepository();
    final pantry = _FakePantryRepository([_pantryItem(), _beanPantryItem()]);
    final sut = controller(
      calendar: calendar,
      pantry: pantry,
      recipe: _recipe(),
      household: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Test kitchen',
        role: HouseholdRole.member,
        isJoint: true,
        hasPremium: true,
      ),
    );
    final meal = MealScheduleEntry(
      id: 'meal-1',
      recipeId: 'braise',
      date: DateTime(2026, 7, 6),
      mealLabel: 'Dinner',
      servingSize: 4,
    );
    final leftover = PantryItem(
      id: 'leftover-1',
      householdId: 'solo-household',
      ingredientId: 'leftover-braise',
      quantity: 3,
      unit: UnitId.piece,
      section: PantrySection.leftover,
      relatedRecipeId: 'braise',
      leftoverServings: 3,
      createdAt: DateTime(2026, 7, 6),
      updatedAt: DateTime(2026, 7, 6),
    );
    final leftoverMeal = meal.copyWith(
      state: ScheduledMealState.leftover,
      linkedLeftoverId: leftover.id,
    );

    await expectLater(sut.markCooked(meal), throwsStateError);
    await expectLater(
      sut.saveLeftovers(meal: meal, servings: 2),
      throwsStateError,
    );
    expect(() => sut.changeServingSize(meal, 6), throwsStateError);
    expect(
      () => sut.swapRecipe(meal: meal, recipeId: 'pad-thai', servingSize: 3),
      throwsStateError,
    );
    expect(() => sut.cancelMeal(meal), throwsStateError);
    expect(() => sut.rescheduleCookNext(meal), throwsStateError);
    expect(
      () => sut.scheduleLeftoverMeal(
        leftover: leftover,
        date: DateTime(2026, 7, 8),
        mealLabel: 'Lunch',
      ),
      throwsStateError,
    );
    await expectLater(sut.consumeLeftoverMeal(leftoverMeal), throwsStateError);
    await expectLater(sut.markLeftoverSpoiled(leftover), throwsStateError);

    expect(calendar.upserted, isNull);
    expect(pantry.quantities, isEmpty);
    expect(pantry.addedItems, isEmpty);
    expect(pantry.wasteEvent, isNull);
  });

  test('swapRecipe replaces only the scheduled instance recipe', () async {
    final calendar = _FakeCalendarRepository();
    final sut = controller(
      calendar: calendar,
      pantry: _FakePantryRepository([]),
      recipe: _recipe(),
    );

    await sut.swapRecipe(
      meal: MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'braise',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
        state: ScheduledMealState.cancelled,
        marking: ScheduledMealMarking.waste,
      ),
      recipeId: 'pad-thai',
      servingSize: 3,
    );

    expect(calendar.upserted?.id, 'meal-1');
    expect(calendar.upserted?.recipeId, 'pad-thai');
    expect(calendar.upserted?.servingSize, 3);
    expect(calendar.upserted?.state, ScheduledMealState.scheduled);
    expect(calendar.upserted?.marking, ScheduledMealMarking.none);
  });

  test('cancelMeal persists cancelled state', () async {
    final calendar = _FakeCalendarRepository();
    final sut = controller(
      calendar: calendar,
      pantry: _FakePantryRepository([]),
      recipe: _recipe(),
    );

    await sut.cancelMeal(
      MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'braise',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
    );

    expect(calendar.upserted?.state, ScheduledMealState.cancelled);
  });

  test('rescheduleCookNext moves the meal to the next day', () async {
    final calendar = _FakeCalendarRepository();
    final sut = controller(
      calendar: calendar,
      pantry: _FakePantryRepository([]),
      recipe: _recipe(),
    );

    await sut.rescheduleCookNext(
      MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'braise',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
    );

    expect(calendar.upserted?.date, DateTime(2026, 7, 7));
    expect(calendar.upserted?.state, ScheduledMealState.scheduled);
    expect(calendar.upserted?.marking, ScheduledMealMarking.unused);
  });

  test(
    'scheduleLeftoverMeal creates a future calendar entry linked to pantry',
    () async {
      final calendar = _FakeCalendarRepository();
      final sut = controller(
        calendar: calendar,
        pantry: _FakePantryRepository([]),
        recipe: _recipe(),
      );

      await sut.scheduleLeftoverMeal(
        leftover: PantryItem(
          id: 'leftover-1',
          householdId: 'solo-household',
          ingredientId: 'leftover-braise',
          quantity: 2,
          unit: UnitId.piece,
          section: PantrySection.leftover,
          relatedRecipeId: 'braise',
          leftoverServings: 2,
          createdAt: DateTime(2026, 7, 6),
          updatedAt: DateTime(2026, 7, 6),
        ),
        date: DateTime(2026, 7, 8, 15),
        mealLabel: 'Lunch',
      );

      expect(calendar.upserted?.id, 'leftover-meal-leftover-1');
      expect(calendar.upserted?.recipeId, 'braise');
      expect(calendar.upserted?.date, DateTime(2026, 7, 8));
      expect(calendar.upserted?.mealLabel, 'Lunch');
      expect(calendar.upserted?.servingSize, 2);
      expect(calendar.upserted?.state, ScheduledMealState.leftover);
      expect(calendar.upserted?.linkedLeftoverId, 'leftover-1');
    },
  );

  test(
    'consumeLeftoverMeal deducts leftover servings and marks meal cooked',
    () async {
      final calendar = _FakeCalendarRepository();
      final pantry = _FakePantryRepository([
        PantryItem(
          id: 'leftover-1',
          householdId: 'solo-household',
          ingredientId: 'leftover-braise',
          quantity: 3,
          unit: UnitId.piece,
          section: PantrySection.leftover,
          relatedRecipeId: 'braise',
          leftoverServings: 3,
          createdAt: DateTime(2026, 7, 6),
          updatedAt: DateTime(2026, 7, 6),
        ),
      ]);
      final sut = controller(
        calendar: calendar,
        pantry: pantry,
        recipe: _recipe(),
      );

      await sut.consumeLeftoverMeal(
        MealScheduleEntry(
          id: 'leftover-meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 8),
          mealLabel: 'Lunch',
          servingSize: 2,
          state: ScheduledMealState.leftover,
          linkedLeftoverId: 'leftover-1',
        ),
      );

      expect(pantry.quantities['leftover-1'], 1);
      expect(calendar.upserted?.state, ScheduledMealState.cooked);
    },
  );

  test(
    'markLeftoverSpoiled records waste and clears leftover quantity',
    () async {
      final calendar = _FakeCalendarRepository();
      final leftover = PantryItem(
        id: 'leftover-1',
        householdId: 'solo-household',
        ingredientId: 'leftover-braise',
        quantity: 3,
        unit: UnitId.piece,
        section: PantrySection.leftover,
        relatedRecipeId: 'braise',
        leftoverServings: 3,
        createdAt: DateTime(2026, 7, 6),
        updatedAt: DateTime(2026, 7, 6),
      );
      final pantry = _FakePantryRepository([leftover]);
      final sut = controller(
        calendar: calendar,
        pantry: pantry,
        recipe: _recipe(),
      );

      await sut.markLeftoverSpoiled(leftover);

      expect(pantry.wasteQuantity, 0);
      expect(pantry.wasteEvent?.id, 'waste-1');
      expect(pantry.wasteEvent?.pantryItemId, 'leftover-1');
      expect(pantry.wasteEvent?.quantity, 3);
      expect(pantry.wasteEvent?.reason, WasteReason.expired);
    },
  );
}
