import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
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
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

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

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository(this.meals);

  final List<MealScheduleEntry> meals;

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(
    meals
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

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(this.items);

  final List<PantryItem> items;
  final added = <PantryItem>[];
  final updated = <PantryItem>[];

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
    final index = items.indexWhere(
      (item) =>
          item.householdId == householdId &&
          item.ingredientId == ingredientId &&
          item.unit == unit &&
          item.section == section,
    );
    return index == -1 ? null : items[index];
  }

  @override
  Future<void> add(PantryItem item) async {
    added.add(item);
    items.add(item);
  }

  @override
  Future<void> update(PantryItem item) async {
    updated.add(item);
    final index = items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
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
  _FakePurchaseHistoryRepository(this.records);

  final List<PurchaseRecord> records;
  final recorded = <PurchaseRecord>[];

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
    recorded.add(record);
    records.add(record);
  }
}

class _FakeWasteRepository implements WasteRepository {
  const _FakeWasteRepository(this.events);

  final List<WasteEvent> events;

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
  Future<void> log(WasteEvent event) async {}
}

class _FakeRecipeRepository implements RecipeRepository {
  _FakeRecipeRepository(this.recipes);

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

Recipe _recipe() {
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
    ingredients: const [
      RecipeIngredient(
        id: 'tomato-line',
        recipeId: 'braise',
        ingredientId: 'tomato',
        quantity: 400,
        unit: Unit.g,
      ),
      RecipeIngredient(
        id: 'bean-line',
        recipeId: 'braise',
        ingredientId: 'beans',
        quantity: 2,
        unit: Unit.piece,
      ),
    ],
    instructions: const [],
  );
}

PantryItem _pantryItem({
  required String id,
  required String ingredientId,
  required double quantity,
  required Unit unit,
  required PantrySection section,
  DateTime? lastPurchaseDate,
}) {
  final now = DateTime(2026, 7);
  return PantryItem(
    id: id,
    householdId: 'solo-household',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    section: section,
    lastPurchaseDate: lastPurchaseDate,
    createdAt: now,
    updatedAt: now,
  );
}

ShoppingPlanningController _controller({
  required _FakeShoppingRepository shopping,
  required List<MealScheduleEntry> meals,
  required _FakePantryRepository pantryRepository,
  _FakePurchaseHistoryRepository? purchaseHistoryRepository,
  List<PurchaseRecord> purchaseHistory = const [],
  List<WasteEvent> wasteHistory = const [],
  List<String> ids = const ['list-1', 'item-1', 'item-2'],
}) {
  final purchases =
      purchaseHistoryRepository ??
      _FakePurchaseHistoryRepository([...purchaseHistory]);
  return ShoppingPlanningController(
    repository: shopping,
    calendarRepository: _FakeCalendarRepository(meals),
    pantryRepository: pantryRepository,
    purchaseHistoryRepository: purchases,
    wasteRepository: _FakeWasteRepository(wasteHistory),
    recipeRepository: _FakeRecipeRepository({'braise': _recipe()}),
    householdId: 'solo-household',
    idGenerator: FakeIdGenerator(ids),
    clock: FakeClock(DateTime(2026, 7, 6, 9)),
  );
}

void main() {
  test(
    'generateAdaptiveList persists a suggested list from upcoming deficits',
    () async {
      final shopping = _FakeShoppingRepository();
      final sut = _controller(
        shopping: shopping,
        meals: [
          MealScheduleEntry(
            id: 'meal-1',
            recipeId: 'braise',
            date: DateTime(2026, 7, 6),
            mealLabel: 'Dinner',
            servingSize: 4,
          ),
        ],
        pantryRepository: _FakePantryRepository([
          _pantryItem(
            id: 'tomato-stock',
            ingredientId: 'tomato',
            quantity: 300,
            unit: Unit.g,
            section: PantrySection.food,
          ),
          _pantryItem(
            id: 'bean-bulk',
            ingredientId: 'beans',
            quantity: 1,
            unit: Unit.piece,
            section: PantrySection.bulk,
          ),
        ]),
      );

      final record = await sut.generateAdaptiveList(
        type: ShoppingListType.suggested,
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 8),
      );

      expect(record, same(shopping.upserted));
      expect(record.id, 'list-1');
      expect(record.type, ShoppingListType.suggested);
      expect(record.status, ShoppingListStatus.pending);
      expect(record.generatedForRangeStart, DateTime(2026, 7, 6));
      expect(record.generatedForRangeEnd, DateTime(2026, 7, 8));
      expect(record.items.map((item) => item.ingredientId), [
        'beans',
        'tomato',
      ]);
      expect(record.items.first.quantityNeeded, 3);
      expect(record.items.last.quantityNeeded, 500);
      expect(record.items.last.sourceMealLinks.single.mealEntryId, 'meal-1');
    },
  );

  test('generateAdaptiveList can persist emergency lists', () async {
    final shopping = _FakeShoppingRepository();
    final sut = _controller(
      shopping: shopping,
      meals: [
        MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 2,
        ),
      ],
      pantryRepository: _FakePantryRepository([]),
      ids: const ['emergency-1', 'item-1', 'item-2'],
    );

    final record = await sut.generateAdaptiveList(
      type: ShoppingListType.emergency,
      startDate: DateTime(2026, 7, 6),
      endDate: DateTime(2026, 7, 6),
    );

    expect(record.id, 'emergency-1');
    expect(record.type, ShoppingListType.emergency);
    expect(record.items, hasLength(2));
  });

  test(
    'createEmergencyListFromMissing persists explicit missing items',
    () async {
      final shopping = _FakeShoppingRepository();
      final sut = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        ids: const ['emergency-1', 'tomato-line'],
      );

      final record = await sut.createEmergencyListFromMissing(
        date: DateTime(2026, 7, 6, 20),
        missingIngredients: const [
          CookingIngredientRequirement(
            ingredientId: 'tomato',
            quantity: 300,
            unit: Unit.g,
          ),
        ],
      );

      expect(record, same(shopping.upserted));
      expect(record.type, ShoppingListType.emergency);
      expect(record.generatedForRangeStart, DateTime(2026, 7, 6));
      expect(record.generatedForRangeEnd, DateTime(2026, 7, 6));
      expect(record.items.single.ingredientId, 'tomato');
      expect(record.items.single.quantityNeeded, 300);
      expect(record.items.single.sourceMealLinks, isEmpty);
    },
  );

  test('generateAdaptiveList adds due bulk replenishments', () async {
    final shopping = _FakeShoppingRepository();
    final sut = _controller(
      shopping: shopping,
      meals: const [],
      pantryRepository: _FakePantryRepository([
        _pantryItem(
          id: 'oil-stock',
          ingredientId: 'oil',
          quantity: 100,
          unit: Unit.ml,
          section: PantrySection.bulk,
          lastPurchaseDate: DateTime(2026, 6),
        ),
      ]),
      purchaseHistory: [
        PurchaseRecord(
          id: 'oil-june',
          householdId: 'solo-household',
          ingredientId: 'oil',
          quantity: 750,
          unit: Unit.ml,
          purchaseDate: DateTime(2026, 6),
          isBulk: true,
        ),
        PurchaseRecord(
          id: 'oil-july',
          householdId: 'solo-household',
          ingredientId: 'oil',
          quantity: 1000,
          unit: Unit.ml,
          purchaseDate: DateTime(2026, 7),
          isBulk: true,
        ),
      ],
      ids: const ['suggested-1', 'oil-line'],
    );

    final record = await sut.generateAdaptiveList(
      type: ShoppingListType.suggested,
      startDate: DateTime(2026, 7, 6),
      endDate: DateTime(2026, 7, 8),
    );

    expect(record.items, hasLength(1));
    expect(record.items.single.ingredientId, 'oil');
    expect(record.items.single.quantityNeeded, 875);
    expect(record.items.single.unit, Unit.ml);
    expect(record.items.single.sourceMealLinks, isEmpty);
  });

  test('completeList updates existing bulk pantry stock', () async {
    final shopping = _FakeShoppingRepository();
    final pantry = _FakePantryRepository([
      _pantryItem(
        id: 'rice-stock',
        ingredientId: 'rice',
        quantity: 2000,
        unit: Unit.g,
        section: PantrySection.bulk,
      ),
    ]);
    final purchases = _FakePurchaseHistoryRepository([]);
    final sut = _controller(
      shopping: shopping,
      meals: const [],
      pantryRepository: pantry,
      purchaseHistoryRepository: purchases,
      ids: const ['purchase-1'],
    );

    await sut.completeList(
      ShoppingListRecord(
        id: 'list-1',
        householdId: 'solo-household',
        type: ShoppingListType.suggested,
        shoppingDate: DateTime(2026, 7, 6),
        generatedForRangeStart: DateTime(2026, 7, 6),
        generatedForRangeEnd: DateTime(2026, 7, 8),
        status: ShoppingListStatus.pending,
        createdAt: DateTime(2026, 7, 6),
        updatedAt: DateTime(2026, 7, 6),
        items: const [
          ShoppingListItemRecord(
            id: 'rice-line',
            shoppingListId: 'list-1',
            ingredientId: 'rice',
            quantityNeeded: 1000,
            unit: Unit.g,
            status: ShoppingListItemStatus.bought,
            sourceMealLinks: [],
          ),
        ],
      ),
    );

    expect(pantry.added, isEmpty);
    expect(pantry.updated.single.section, PantrySection.bulk);
    expect(pantry.updated.single.quantity, 3000);
    expect(purchases.recorded.single.id, 'purchase-1');
    expect(purchases.recorded.single.sourceShoppingListId, 'list-1');
    expect(purchases.recorded.single.isBulk, isTrue);
    expect(purchases.recorded.single.isNonFood, isFalse);
  });

  test('generateAdaptiveList rejects non-adaptive list types', () async {
    final sut = _controller(
      shopping: _FakeShoppingRepository(),
      meals: const [],
      pantryRepository: _FakePantryRepository([]),
    );

    expect(
      () => sut.generateAdaptiveList(
        type: ShoppingListType.shopNow,
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 6),
      ),
      throwsArgumentError,
    );
  });
}
