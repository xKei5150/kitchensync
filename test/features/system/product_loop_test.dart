// SIZE_OK: product loop test intentionally drives the app workflow surface.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
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
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';
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
    final shoppingCommandRepository = _MemoryShoppingCommandRepository(
      shoppingRepository: shoppingRepository,
      pantryRepository: pantryRepository,
      purchaseRepository: purchaseRepository,
      calendarRepository: calendarRepository,
      now: now,
    );
    final writeCoordinator = ShoppingWriteCoordinator(
      repository: shoppingCommandRepository,
      allocationRepository: shoppingCommandRepository,
      householdId: household.id,
      idGenerator: FakeIdGenerator([
        'create-list-command',
        'add-rice-command',
        'edit-rice-command',
        'buy-rice-command',
        'purchased-rice-command',
        'remove-rice-command',
        'buy-beans-command',
        'substitute-tomato-command',
      ]),
    );

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
        unit: UnitId.g,
        section: PantrySection.food,
        now: now,
      ),
    );

    final shoppingController = ShoppingPlanningController(
      repository: shoppingRepository,
      writeCoordinator: writeCoordinator,
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
      shoppingScheduleRepository: const _MemoryShoppingScheduleRepository(),
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

    await shoppingController.addItem(
      listId: shoppingList.id,
      expectedRevision: 0,
      ingredientId: 'rice',
      quantityNeeded: 2,
      unit: UnitId.kg,
      itemId: 'rice-line',
    );
    await shoppingController.setItemNeededQuantity(
      listId: shoppingList.id,
      itemId: 'rice-line',
      expectedRevision: 1,
      quantityNeeded: 3,
    );
    await shoppingController.updateItemStatus(
      listId: shoppingList.id,
      itemId: 'rice-line',
      expectedRevision: 2,
      status: ShoppingListItemStatus.bought,
      purchasedQuantity: 4,
    );
    await shoppingController.setItemPurchasedQuantity(
      listId: shoppingList.id,
      itemId: 'rice-line',
      expectedRevision: 3,
      purchasedQuantity: 2.5,
    );
    await shoppingController.removeItem(
      listId: shoppingList.id,
      itemId: 'rice-line',
      expectedRevision: 4,
    );

    await shoppingController.updateItemStatus(
      listId: shoppingList.id,
      itemId: 'beans-line',
      expectedRevision: 5,
      status: ShoppingListItemStatus.bought,
      purchasedQuantity: 2,
    );
    await shoppingController.updateItemStatus(
      listId: shoppingList.id,
      itemId: 'tomato-line',
      expectedRevision: 6,
      status: ShoppingListItemStatus.substituted,
      substituteIngredientId: 'pepper',
      substituteQuantity: 300,
      substituteUnit: UnitId.g,
    );

    await ShoppingCommandController(
      repository: shoppingCommandRepository,
      householdId: household.id,
      household: household,
      idGenerator: FakeIdGenerator(['complete-command']),
    ).completeList(shoppingList.id);

    expect(
      shoppingRepository.lists[shoppingList.id]?.status,
      ShoppingListStatus.completed,
    );
    expect(pantryRepository.findQuantity('beans', UnitId.piece), 2);
    expect(pantryRepository.findQuantity('pepper', UnitId.g), 300);
    expect(pantryRepository.findQuantity('tomato', UnitId.g), 100);
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
    expect(pantryRepository.findQuantity('beans', UnitId.piece), 0);
    expect(pantryRepository.findQuantity('pepper', UnitId.g), 0);
    expect(pantryRepository.findQuantity('tomato', UnitId.g), 100);
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
    expect(wasteRepository.events.single.ingredientId, 'tomato');

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

  test('product loop supports custom informal pantry unit', () async {
    final now = DateTime(2026, 7, 6, 9);
    final household = _premiumAdmin();
    final calendarRepository = _MemoryCalendarRepository();
    final pantryRepository = _MemoryPantryRepository();
    final purchaseRepository = _MemoryPurchaseHistoryRepository();
    final shoppingRepository = _MemoryShoppingRepository();
    final tray = UnitId('tray');
    final list = ShoppingListRecord(
      id: 'shop-now',
      householdId: 'solo-household',
      type: ShoppingListType.shopNow,
      shoppingDate: DateTime(2026, 7, 6),
      generatedForRangeStart: DateTime(2026, 7, 6),
      generatedForRangeEnd: DateTime(2026, 7, 6),
      status: ShoppingListStatus.pending,
      createdAt: DateTime(2026, 7, 6, 9),
      updatedAt: DateTime(2026, 7, 6, 9),
      items: [
        ShoppingListItemRecord(
          id: 'platter-line',
          shoppingListId: 'shop-now',
          ingredientId: 'party-platter',
          quantityNeeded: 3,
          unit: tray,
          status: ShoppingListItemStatus.bought,
          sourceMealLinks: [],
        ),
      ],
    );
    shoppingRepository.store(list);

    await ShoppingCommandController(
      repository: _MemoryShoppingCommandRepository(
        shoppingRepository: shoppingRepository,
        pantryRepository: pantryRepository,
        purchaseRepository: purchaseRepository,
        calendarRepository: calendarRepository,
        now: now,
      ),
      householdId: household.id,
      household: household,
      idGenerator: FakeIdGenerator(['complete-command']),
    ).completeList(list.id);

    expect(
      shoppingRepository.lists[list.id]?.status,
      ShoppingListStatus.completed,
    );
    expect(pantryRepository.findQuantity('party-platter', tray), 3);
    expect(purchaseRepository.records.single.ingredientId, 'party-platter');
    expect(purchaseRepository.records.single.unit, tray);
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
        unit: UnitId.g,
      ),
      RecipeIngredient(
        id: 'beans-line',
        recipeId: 'braise',
        ingredientId: 'beans',
        quantity: 2,
        unit: UnitId.piece,
      ),
    ],
    instructions: const ['Simmer until saucy.'],
  );
}

PantryItem _pantryItem({
  required String id,
  required String ingredientId,
  required double quantity,
  required UnitId unit,
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

class _MemoryShoppingScheduleRepository implements ShoppingScheduleRepository {
  const _MemoryShoppingScheduleRepository();

  @override
  Future<void> save(ShoppingSchedule schedule) async {}

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(null);
}

class _MemoryShoppingCommandRepository
    implements ShoppingAllocationCommandRepository {
  const _MemoryShoppingCommandRepository({
    required this.shoppingRepository,
    required this.pantryRepository,
    required this.purchaseRepository,
    required this.calendarRepository,
    required this.now,
  });

  final _MemoryShoppingRepository shoppingRepository;
  final _MemoryPantryRepository pantryRepository;
  final _MemoryPurchaseHistoryRepository purchaseRepository;
  final _MemoryCalendarRepository calendarRepository;
  final DateTime now;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    const listId = 'server-derived-list';
    shoppingRepository.store(
      ShoppingListRecord(
        id: listId,
        householdId: command.intent.householdId,
        type: ShoppingListType.shopNow,
        shoppingDate: command.intent.startDate,
        generatedForRangeStart: command.intent.startDate,
        generatedForRangeEnd: command.intent.endDate,
        status: ShoppingListStatus.pending,
        createdAt: now,
        updatedAt: now,
        items: [
          const ShoppingListItemRecord(
            id: 'beans-line',
            shoppingListId: listId,
            ingredientId: 'beans',
            quantityNeeded: 2,
            unit: UnitId.piece,
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: [],
          ),
          ShoppingListItemRecord(
            id: 'tomato-line',
            shoppingListId: listId,
            ingredientId: 'tomato',
            quantityNeeded: 300,
            unit: UnitId.g,
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: [
              MealSourceLink(
                mealEntryId: 'meal-1',
                recipeId: 'recipe-1',
                date: DateTime(2026, 7, 6),
                quantity: 300,
              ),
            ],
          ),
        ],
      ),
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
    final current = shoppingRepository.lists[command.listId];
    final revision = current == null ? 0 : current.revision + 1;
    shoppingRepository.store(
      _shoppingListWith(
        command.list,
        revision: revision,
        items: command.list.items,
      ),
    );
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
    final list = shoppingRepository.lists[command.listId]!;
    final revision = list.revision + 1;
    final items = switch (command.mutation) {
      final AddShoppingListItemMutation mutation => [
        ...list.items,
        ShoppingListItemRecord(
          id: command.itemId,
          shoppingListId: command.listId,
          ingredientId: mutation.ingredientId,
          quantityNeeded: mutation.quantityNeeded,
          purchasedQuantity: mutation.purchasedQuantity,
          unit: mutation.unit,
          status: mutation.status,
          substituteIngredientId: mutation.substituteIngredientId,
          substituteQuantity: mutation.substituteQuantity,
          substituteUnit: mutation.substituteUnit,
          sourceMealLinks: const [],
        ),
      ],
      RemoveShoppingListItemMutation() => [
        for (final item in list.items)
          if (item.id != command.itemId) item,
      ],
      _ => [
        for (final item in list.items)
          if (item.id == command.itemId)
            _mutatedItem(item, command.mutation)
          else
            item,
      ],
    };
    shoppingRepository.store(
      _shoppingListWith(list, revision: revision, items: items),
    );
    return ShoppingCommandResult(
      listId: command.listId,
      status: _commandStatus(list.status),
      revision: revision,
      alreadyApplied: false,
    );
  }

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      _complete(request);

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) {
    throw UnimplementedError();
  }

  Future<ShoppingCommandResult> _complete(
    ShoppingCommandRequest request,
  ) async {
    final listId = request.listId;
    final list = shoppingRepository.lists[listId]!;
    for (final item in list.items) {
      if (item.status != ShoppingListItemStatus.bought &&
          item.status != ShoppingListItemStatus.substituted) {
        continue;
      }
      final ingredientId = item.substituteIngredientId ?? item.ingredientId;
      final quantity = item.substituteQuantity ?? item.quantityNeeded;
      final unit = item.substituteUnit ?? item.unit;
      final existing = await pantryRepository.findByIngredientUnit(
        householdId: list.householdId,
        ingredientId: ingredientId,
        unit: unit,
        section: PantrySection.food,
      );
      if (existing == null) {
        await pantryRepository.add(
          PantryItem(
            id: '$listId-${item.id}-pantry',
            householdId: list.householdId,
            ingredientId: ingredientId,
            quantity: quantity,
            unit: unit,
            section: PantrySection.food,
            lastPurchaseDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await pantryRepository.update(
          existing.copyWith(
            quantity: existing.quantity + quantity,
            lastPurchaseDate: now,
            updatedAt: now,
          ),
        );
      }
      await purchaseRepository.record(
        PurchaseRecord(
          id: '$listId-${item.id}-purchase',
          householdId: list.householdId,
          ingredientId: ingredientId,
          quantity: quantity,
          unit: unit,
          purchaseDate: now,
          sourceShoppingListId: list.id,
        ),
      );
      if (item.status == ShoppingListItemStatus.substituted) {
        for (final link in item.sourceMealLinks) {
          final meal = calendarRepository.meals[link.mealEntryId];
          if (meal == null) continue;
          await calendarRepository.upsertMeal(
            householdId: list.householdId,
            entry: meal.copyWith(
              ingredientOverrides: [
                MealIngredientOverride(
                  originalIngredientId: item.ingredientId,
                  originalUnit: item.unit,
                  substituteIngredientId: item.substituteIngredientId!,
                  substituteQuantity: item.substituteQuantity!,
                  substituteUnit: item.substituteUnit!,
                ),
              ],
            ),
          );
        }
      }
    }
    shoppingRepository.store(
      _shoppingListWith(
        list,
        revision: list.revision,
        items: list.items,
        status: ShoppingListStatus.completed,
        updatedAt: now,
      ),
    );
    return ShoppingCommandResult(
      listId: listId,
      status: ShoppingCommandStatus.completed,
      alreadyApplied: false,
      completionId: request.commandId,
    );
  }
}

class _MemoryPantryRepository implements PantryRepository {
  final items = <String, PantryItem>{};
  final wasteEvents = <WasteEvent>[];

  double? findQuantity(String ingredientId, UnitId unit) {
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
    required UnitId unit,
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

class _MemoryShoppingRepository extends ShoppingRepository {
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

  void store(ShoppingListRecord list) {
    lists[list.id] = list;
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
  required List<ShoppingListItemRecord> items,
  ShoppingListStatus? status,
  DateTime? updatedAt,
}) => ShoppingListRecord(
  id: list.id,
  householdId: list.householdId,
  type: list.type,
  shoppingDate: list.shoppingDate,
  generatedForRangeStart: list.generatedForRangeStart,
  generatedForRangeEnd: list.generatedForRangeEnd,
  status: status ?? list.status,
  originId: list.originId,
  completionId: list.completionId,
  completedAt: list.completedAt,
  completedByUserId: list.completedByUserId,
  schemaVersion: list.schemaVersion,
  revision: revision,
  createdAt: list.createdAt,
  updatedAt: updatedAt ?? list.updatedAt,
  items: List.unmodifiable(items),
);

ShoppingListItemRecord _mutatedItem(
  ShoppingListItemRecord item,
  ShoppingListItemMutation mutation,
) => switch (mutation) {
  AddShoppingListItemMutation() => item,
  RemoveShoppingListItemMutation() => item,
  SetShoppingListItemNeededQuantityMutation() => item.withQuantityNeeded(
    mutation.quantityNeeded,
  ),
  SetShoppingListItemPurchasedQuantityMutation() => ShoppingListItemRecord(
    id: item.id,
    shoppingListId: item.shoppingListId,
    ingredientId: item.ingredientId,
    quantityNeeded: item.quantityNeeded,
    purchasedQuantity: mutation.purchasedQuantity,
    unit: item.unit,
    status: item.status,
    substituteIngredientId: item.substituteIngredientId,
    substituteQuantity: item.substituteQuantity,
    substituteUnit: item.substituteUnit,
    sourceMealLinks: item.sourceMealLinks,
  ),
  SetShoppingListItemStatusMutation() => ShoppingListItemRecord(
    id: item.id,
    shoppingListId: item.shoppingListId,
    ingredientId: item.ingredientId,
    quantityNeeded: item.quantityNeeded,
    purchasedQuantity: mutation.purchasedQuantity,
    unit: item.unit,
    status: mutation.status,
    substituteIngredientId: mutation.substituteIngredientId,
    substituteQuantity: mutation.substituteQuantity,
    substituteUnit: mutation.substituteUnit,
    sourceMealLinks: item.sourceMealLinks,
  ),
};
