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
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_leftover.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

void main() {
  test('recipe-to-waste product loop shares persisted records', () async {
    final now = DateTime(2026, 7, 6, 9);
    final cookTime = DateTime(2026, 7, 6, 20);
    final household = _premiumAdmin();
    final recipeRepository = _MemoryRecipeRepository();
    final calendarRepository = _MemoryCalendarRepository();
    final pantryRepository = _MemoryPantryRepository();
    final purchaseRepository = _MemoryPurchaseHistoryRepository();
    final wasteRepository = _MemoryWasteRepository(pantryRepository);
    final shoppingRepository = _MemoryShoppingRepository();

    final recipe = _recipe(now);
    await recipeRepository.upsert(recipe);

    final scheduledMeal = MealScheduleEntry(
      id: 'meal-1',
      recipeId: recipe.id,
      date: DateTime(2026, 7, 6),
      mealLabel: 'Dinner',
      servingSize: 2,
    );
    await calendarRepository.upsertMeal(
      householdId: household.id,
      entry: scheduledMeal,
    );
    await pantryRepository.add(
      _pantryItem(
        id: 'tomato-stock',
        ingredientId: 'tomato',
        quantity: 100,
        unit: Unit.g,
        section: PantrySection.food,
        now: now,
      ),
    );

    final shoppingController = ShoppingPlanningController(
      repository: shoppingRepository,
      calendarRepository: calendarRepository,
      pantryRepository: pantryRepository,
      purchaseHistoryRepository: purchaseRepository,
      wasteRepository: wasteRepository,
      recipeRepository: recipeRepository,
      householdId: household.id,
      household: household,
      idGenerator: FakeIdGenerator(const [
        'shop-now',
        'beans-line',
        'tomato-line',
        'tomato-pantry',
        'tomato-purchase',
        'pepper-pantry',
        'pepper-purchase',
      ]),
      clock: FakeClock(now),
    );

    final shoppingList = await shoppingController.generateAdaptiveList(
      type: ShoppingListType.emergency,
      startDate: DateTime(2026, 7, 6),
      endDate: DateTime(2026, 7, 6),
    );
    expect(shoppingList.items.map((item) => item.ingredientId), [
      'beans',
      'tomato',
    ]);
    expect(
      shoppingList.items
          .singleWhere((item) => item.ingredientId == 'tomato')
          .quantityNeeded,
      300,
    );
    expect(
      shoppingList.items
          .singleWhere((item) => item.ingredientId == 'tomato')
          .sourceMealLinks
          .single
          .mealEntryId,
      scheduledMeal.id,
    );

    await shoppingController.updateItemStatus(
      listId: shoppingList.id,
      itemId: 'beans-line',
      status: ShoppingListItemStatus.bought,
    );
    await shoppingController.updateItemStatus(
      listId: shoppingList.id,
      itemId: 'tomato-line',
      status: ShoppingListItemStatus.substituted,
      substituteIngredientId: 'pepper',
      substituteQuantity: 300,
      substituteUnit: Unit.g,
    );

    final readyList = await shoppingRepository
        .watchList(householdId: household.id, listId: shoppingList.id)
        .first;
    await shoppingController.completeList(readyList!);

    expect(
      shoppingRepository.lists[shoppingList.id]?.status,
      ShoppingListStatus.completed,
    );
    expect(pantryRepository.findQuantity('beans', Unit.piece), 2);
    expect(pantryRepository.findQuantity('pepper', Unit.g), 300);
    expect(pantryRepository.findQuantity('tomato', Unit.g), 100);
    expect(purchaseRepository.records.map((record) => record.ingredientId), [
      'beans',
      'pepper',
    ]);

    final overriddenMeal = await calendarRepository
        .watchMealsInRange(
          householdId: household.id,
          startDate: DateTime(2026, 7, 6),
          endDate: DateTime(2026, 7, 6),
        )
        .first
        .then((meals) => meals.single);
    expect(
      overriddenMeal.ingredientOverrides.single.substituteIngredientId,
      'pepper',
    );

    final cookingController = CookingLifecycleController(
      calendarRepository: calendarRepository,
      pantryRepository: pantryRepository,
      recipeRepository: recipeRepository,
      recordLeftover: RecordLeftover(
        pantryRepository,
        idGenerator: FakeIdGenerator(const ['leftover-1']),
        clock: FakeClock(cookTime),
      ),
      markAsWaste: MarkAsWaste(
        pantryRepository,
        idGenerator: FakeIdGenerator(const ['waste-1']),
        clock: FakeClock(cookTime),
      ),
      householdId: household.id,
      household: household,
    );

    await cookingController.markCooked(overriddenMeal);
    expect(pantryRepository.findQuantity('beans', Unit.piece), 0);
    expect(pantryRepository.findQuantity('pepper', Unit.g), 0);
    expect(pantryRepository.findQuantity('tomato', Unit.g), 100);
    expect(
      calendarRepository.meals[scheduledMeal.id]?.state,
      ScheduledMealState.cooked,
    );

    final leftover = await cookingController.saveLeftovers(
      meal: calendarRepository.meals[scheduledMeal.id]!,
      servings: 1,
    );
    expect(leftover.section, PantrySection.leftover);
    expect(
      calendarRepository.meals[scheduledMeal.id]?.linkedLeftoverId,
      leftover.id,
    );

    await cookingController.scheduleLeftoverMeal(
      leftover: leftover,
      date: DateTime(2026, 7, 7),
      mealLabel: 'Lunch',
    );
    expect(
      calendarRepository.meals['leftover-meal-leftover-1']?.state,
      ScheduledMealState.leftover,
    );

    await cookingController.markLeftoverSpoiled(leftover);
    expect(pantryRepository.items[leftover.id]?.quantity, 0);
    expect(wasteRepository.events.single.reason, WasteReason.expired);
    expect(wasteRepository.events.single.ingredientId, 'leftover-braise');

    final wasteVisibleToInsights = await wasteRepository
        .watchByHousehold(household.id)
        .first;
    expect(wasteVisibleToInsights.single.id, 'waste-1');

    final wasteVisibleToCalendar = await wasteRepository
        .watchByHousehold(household.id)
        .first
        .then(
          (events) => events.where(
            (event) =>
                event.date.year == cookTime.year &&
                event.date.month == cookTime.month &&
                event.date.day == cookTime.day,
          ),
        );
    expect(wasteVisibleToCalendar, isNotEmpty);
  });
}

ActiveHouseholdContext _premiumAdmin() {
  return const ActiveHouseholdContext(
    id: 'solo-household',
    name: 'Test kitchen',
    role: HouseholdRole.admin,
    isJoint: true,
    hasPremium: true,
  );
}

Recipe _recipe(DateTime now) {
  return Recipe(
    id: 'braise',
    authorUserId: 'user-1',
    householdId: 'solo-household',
    name: 'Tomato and white bean braise',
    description: 'Manual recipe with dictionary-linked ingredients.',
    defaultServingSize: 2,
    mealTimeTags: const ['Dinner'],
    recipeTags: const ['budget'],
    location: 'Home',
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
      RecipeIngredient(
        id: 'beans-line',
        recipeId: 'braise',
        ingredientId: 'beans',
        quantity: 2,
        unit: Unit.piece,
      ),
    ],
    instructions: const ['Simmer until saucy.'],
  );
}

PantryItem _pantryItem({
  required String id,
  required String ingredientId,
  required double quantity,
  required Unit unit,
  required PantrySection section,
  required DateTime now,
}) {
  return PantryItem(
    id: id,
    householdId: 'solo-household',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    section: section,
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryRecipeRepository implements RecipeRepository {
  final recipes = <String, Recipe>{};

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value(
        recipes.values
            .where((recipe) => recipe.householdId == householdId)
            .toList(growable: false),
      );

  @override
  Stream<Recipe?> watchById(String recipeId) => Stream.value(recipes[recipeId]);

  @override
  Future<void> upsert(Recipe recipe) async {
    recipes[recipe.id] = recipe;
  }

  @override
  Future<void> delete(String recipeId) async {
    recipes.remove(recipeId);
  }

  @override
  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  }) async => recipes.values
      .where((recipe) => recipe.visibility == RecipeVisibility.public)
      .take(limit)
      .toList(growable: false);

  @override
  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  }) async {
    throw UnimplementedError();
  }
}

class _MemoryCalendarRepository implements CalendarRepository {
  final meals = <String, MealScheduleEntry>{};
  final settings = <String, CalendarDaySettings>{};

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(
    meals.values
        .where(
          (meal) =>
              !meal.date.isBefore(startDate) && !meal.date.isAfter(endDate),
        )
        .toList(growable: false),
  );

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {
    meals[entry.id] = entry;
  }

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {
    meals.remove(entryId);
  }

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.value(
    settings.values
        .where(
          (setting) => setting.householdId == householdId && setting.isActive,
        )
        .toList(growable: false),
  );

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {
    this.settings[settings.id] = settings;
  }
}

class _MemoryPantryRepository implements PantryRepository {
  final items = <String, PantryItem>{};
  final wasteEvents = <WasteEvent>[];

  double? findQuantity(String ingredientId, Unit unit) {
    for (final item in items.values) {
      if (item.ingredientId == ingredientId && item.unit == unit) {
        return item.quantity;
      }
    }
    return null;
  }

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => Stream.value(
    items.values
        .where(
          (item) => item.householdId == householdId && item.section == section,
        )
        .toList(growable: false),
  );

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      Stream.value(
        items[itemId]?.householdId == householdId ? items[itemId] : null,
      );

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async {
    for (final item in items.values) {
      if (item.householdId == householdId &&
          item.ingredientId == ingredientId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required Unit unit,
    required PantrySection section,
  }) async {
    for (final item in items.values) {
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
    items[item.id] = item;
  }

  @override
  Future<void> update(PantryItem item) async {
    items[item.id] = item;
  }

  @override
  Future<void> setQuantity(
    String householdId,
    String itemId,
    double newQty,
  ) async {
    final item = items[itemId];
    if (item == null || item.householdId != householdId) return;
    items[itemId] = item.copyWith(quantity: newQty);
  }

  @override
  Future<void> delete(String householdId, String itemId) async {
    if (items[itemId]?.householdId == householdId) {
      items.remove(itemId);
    }
  }

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
    await setQuantity(householdId, pantryItemId, newPantryQuantity);
    wasteEvents.add(wasteEvent);
  }
}

class _MemoryPurchaseHistoryRepository implements PurchaseHistoryRepository {
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

class _MemoryWasteRepository implements WasteRepository {
  const _MemoryWasteRepository(this.pantryRepository);

  final _MemoryPantryRepository pantryRepository;

  List<WasteEvent> get events => pantryRepository.wasteEvents;

  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => Stream.value(
    events
        .where((event) => event.householdId == householdId)
        .take(limit)
        .toList(growable: false),
  );

  @override
  Future<void> log(WasteEvent event) async {
    pantryRepository.wasteEvents.add(event);
  }
}

class _MemoryShoppingRepository implements ShoppingRepository {
  final lists = <String, ShoppingListRecord>{};

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.value(
        lists.values
            .where((list) => list.householdId == householdId)
            .toList(growable: false),
      );

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(
    lists[listId]?.householdId == householdId ? lists[listId] : null,
  );

  @override
  Future<void> upsertList(ShoppingListRecord list) async {
    lists[list.id] = list;
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
  }) async {
    final list = lists[listId];
    if (list == null || list.householdId != householdId) return;
    lists[listId] = ShoppingListRecord(
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
      items: [
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
      ],
    );
  }

  @override
  Future<void> updateListStatus({
    required String householdId,
    required String listId,
    required ShoppingListStatus status,
  }) async {
    final list = lists[listId];
    if (list == null || list.householdId != householdId) return;
    lists[listId] = ShoppingListRecord(
      id: list.id,
      householdId: list.householdId,
      type: list.type,
      shoppingDate: list.shoppingDate,
      generatedForRangeStart: list.generatedForRangeStart,
      generatedForRangeEnd: list.generatedForRangeEnd,
      status: status,
      originId: list.originId,
      createdAt: list.createdAt,
      updatedAt: DateTime(2026, 7, 6, 9),
      items: list.items,
    );
  }

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
    if (lists[listId]?.householdId == householdId) {
      lists.remove(listId);
    }
  }
}
