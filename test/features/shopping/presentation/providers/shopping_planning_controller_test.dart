// SIZE_OK: shopping planning tests cover existing controller state branches.
import 'dart:async';
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
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

class _FakeShoppingRepository extends ShoppingRepository {
  final lists = <ShoppingListRecord>[];
  ConsumeShoppingAllocationIntent? allocation;
  String? deletedListId;

  ShoppingListRecord? get upserted => lists.isEmpty ? null : lists.last;

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.value(List.unmodifiable(lists));

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(lists.where((record) => record.id == listId).firstOrNull);

  void store(ShoppingListRecord list) {
    final index = lists.indexWhere((existing) => existing.id == list.id);
    if (index == -1) {
      lists.add(list);
    } else {
      lists[index] = list;
    }
  }
}

class _FakeShoppingCommandRepository
    implements ShoppingAllocationCommandRepository {
  _FakeShoppingCommandRepository({
    this.shopping,
    this.completeResponses,
    this.mutationResponses,
  });

  final _FakeShoppingRepository? shopping;
  ShoppingCommandRequest? completed;
  ShoppingCommandRequest? deleted;
  final List<Future<ShoppingCommandResult> Function(ShoppingCommandRequest)>?
  completeResponses;
  final List<
    Future<ShoppingCommandResult> Function(ShoppingListItemMutationCommand)
  >?
  mutationResponses;
  final mutations = <ShoppingListItemMutationCommand>[];
  int completeCallCount = 0;
  int mutationCallCount = 0;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    shopping?.allocation = command;
    const listId = 'server-derived-allocation';
    shopping?.store(_serverRecord(command.intent, listId));
    return const ShoppingCommandResult(
      listId: listId,
      status: ShoppingCommandStatus.pending,
      revision: 0,
      alreadyApplied: false,
    );
  }

  ShoppingListRecord _serverRecord(ShoppingAllocationIntent intent, String id) {
    final (type, shoppingDate, originId) = switch (intent) {
      ScheduledShoppingAllocationIntent() => (
        ShoppingListType.scheduled,
        intent.occurrenceDate,
        intent.scheduleKey,
      ),
      SuggestedShoppingAllocationIntent() => (
        ShoppingListType.suggested,
        intent.startDate,
        intent.originId,
      ),
      EmergencyShoppingAllocationIntent() => (
        ShoppingListType.emergency,
        intent.startDate,
        null,
      ),
      ShopNowShoppingAllocationIntent() => (
        ShoppingListType.shopNow,
        intent.startDate,
        null,
      ),
    };
    return ShoppingListRecord(
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
      items: const [],
    );
  }

  @override
  Future<ShoppingCommandResult> upsertList(
    ShoppingListUpsertCommand command,
  ) async {
    final shopping = this.shopping;
    if (shopping == null) throw StateError('Shopping state is not configured.');
    ShoppingListRecord? existing;
    for (final list in shopping.lists) {
      if (list.id == command.listId) {
        existing = list;
        break;
      }
    }
    final revision = existing == null ? 0 : existing.revision + 1;
    shopping.store(_recordWithRevision(command.list, revision));
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
    mutations.add(command);
    final responses = mutationResponses;
    if (responses != null) {
      return responses[mutationCallCount++](command);
    }
    final shopping = this.shopping;
    if (shopping == null) throw StateError('Shopping state is not configured.');
    final list = shopping.lists.singleWhere(
      (candidate) => candidate.id == command.listId,
    );
    final revision = list.revision + 1;
    shopping.store(
      _recordWithItems(list, [
        for (final item in list.items)
          if (item.id == command.itemId)
            _applyMutation(item, command.mutation)
          else
            item,
      ], revision),
    );
    return ShoppingCommandResult(
      listId: command.listId,
      status: _commandStatus(list.status),
      revision: revision,
      alreadyApplied: false,
    );
  }

  @override
  Future<ShoppingCommandResult> completeList(
    ShoppingCommandRequest request,
  ) async {
    completed = request;
    final responses = completeResponses;
    if (responses != null) {
      return responses[completeCallCount++](request);
    }
    return ShoppingCommandResult(
      listId: request.listId,
      status: ShoppingCommandStatus.completed,
      alreadyApplied: false,
      completionId: request.commandId,
    );
  }

  @override
  Future<ShoppingCommandResult> deleteList(
    ShoppingCommandRequest request,
  ) async {
    deleted = request;
    shopping?.deletedListId = request.listId;
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

ShoppingListRecord _recordWithRevision(ShoppingListRecord list, int revision) =>
    _recordWithItems(list, list.items, revision);

ShoppingListRecord _recordWithItems(
  ShoppingListRecord list,
  List<ShoppingListItemRecord> items,
  int revision,
) => ShoppingListRecord(
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
  items: List.unmodifiable(items),
);

ShoppingListItemRecord _applyMutation(
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
    unit: item.unit,
    status: item.status,
    sourceMealLinks: item.sourceMealLinks,
    substituteIngredientId: item.substituteIngredientId,
    substituteQuantity: item.substituteQuantity,
    substituteUnit: item.substituteUnit,
    purchasedQuantity: mutation.purchasedQuantity,
  ),
  SetShoppingListItemStatusMutation() => ShoppingListItemRecord(
    id: item.id,
    shoppingListId: item.shoppingListId,
    ingredientId: item.ingredientId,
    quantityNeeded: item.quantityNeeded,
    unit: item.unit,
    status: mutation.status,
    sourceMealLinks: item.sourceMealLinks,
    substituteIngredientId: mutation.substituteIngredientId,
    substituteQuantity: mutation.substituteQuantity,
    substituteUnit: mutation.substituteUnit,
    purchasedQuantity: mutation.purchasedQuantity,
  ),
};

class _FakeShoppingScheduleRepository implements ShoppingScheduleRepository {
  _FakeShoppingScheduleRepository(this.schedule);

  final ShoppingSchedule? schedule;

  @override
  Future<void> save(ShoppingSchedule schedule) async {}

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(schedule);
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
    required UnitId unit,
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
        unit: UnitId.g,
      ),
      RecipeIngredient(
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

PantryItem _pantryItem({
  required String id,
  required String ingredientId,
  required double quantity,
  required UnitId unit,
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
  ActiveHouseholdContext? household,
  ShoppingSchedule? shoppingSchedule,
  _FakeShoppingCommandRepository? commandRepository,
  List<String> writeIds = const ['write-command-1'],
}) {
  final purchases =
      purchaseHistoryRepository ??
      _FakePurchaseHistoryRepository([...purchaseHistory]);
  final commands =
      commandRepository ?? _FakeShoppingCommandRepository(shopping: shopping);
  return ShoppingPlanningController(
    repository: shopping,
    writeCoordinator: ShoppingWriteCoordinator(
      repository: commands,
      householdId: 'solo-household',
      idGenerator: FakeIdGenerator(writeIds),
    ),
    calendarRepository: _FakeCalendarRepository(meals),
    pantryRepository: pantryRepository,
    purchaseHistoryRepository: purchases,
    wasteRepository: _FakeWasteRepository(wasteHistory),
    recipeRepository: _FakeRecipeRepository({'braise': _recipe()}),
    householdId: 'solo-household',
    household: household,
    idGenerator: FakeIdGenerator(ids),
    clock: FakeClock(DateTime(2026, 7, 6, 9)),
    shoppingScheduleRepository: _FakeShoppingScheduleRepository(
      shoppingSchedule,
    ),
  );
}

void main() {
  test(
    'Shop Now preview and persistence use the same inclusive custom range',
    () async {
      final shopping = _FakeShoppingRepository();
      final sut = _controller(
        shopping: shopping,
        meals: [
          MealScheduleEntry(
            id: 'meal-1',
            recipeId: 'braise',
            date: DateTime(2026, 7, 8),
            mealLabel: 'Dinner',
            servingSize: 2,
          ),
        ],
        pantryRepository: _FakePantryRepository([]),
      );

      final preview = await sut.previewShopNowList(
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 8),
      );
      final persisted = await sut.persistShopNowPreview(preview);

      expect(preview.startDate, DateTime(2026, 7, 6));
      expect(preview.endDate, DateTime(2026, 7, 8));
      expect(preview.items, isNotEmpty);
      expect(persisted.generatedForRangeStart, preview.startDate);
      expect(persisted.generatedForRangeEnd, preview.endDate);
      expect(persisted.id, 'server-derived-allocation');
      expect(persisted.items, isEmpty);
    },
  );

  test(
    'Shop Now rejects ranges outside today through 28 inclusive days',
    () async {
      final sut = _controller(
        shopping: _FakeShoppingRepository(),
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
      );

      for (final range in [
        (DateTime(2026, 7, 5), DateTime(2026, 7, 6)),
        (DateTime(2026, 7, 6), DateTime(2026, 7, 5)),
        (DateTime(2026, 7, 6), DateTime(2026, 8, 3)),
      ]) {
        await expectLater(
          sut.previewShopNowList(startDate: range.$1, endDate: range.$2),
          throwsArgumentError,
        );
      }
    },
  );

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
            unit: UnitId.g,
            section: PantrySection.food,
          ),
          _pantryItem(
            id: 'bean-bulk',
            ingredientId: 'beans',
            quantity: 1,
            unit: UnitId.piece,
            section: PantrySection.bulk,
          ),
        ]),
      );

      final record = await sut.generateAdaptiveList(
        type: ShoppingListType.suggested,
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 8),
      );

      expect(
        shopping.allocation?.intent,
        isA<SuggestedShoppingAllocationIntent>(),
      );
      expect(record.id, 'server-derived-allocation');
      expect(record.type, ShoppingListType.suggested);
      expect(record.status, ShoppingListStatus.pending);
      expect(record.generatedForRangeStart, DateTime(2026, 7, 6));
      expect(record.generatedForRangeEnd, DateTime(2026, 7, 8));
      expect(record.items, isEmpty);
    },
  );

  test('reconcileScheduledLists persists the scheduled occurrence '
      'for its calendar window', () async {
    final shopping = _FakeShoppingRepository();
    final sut = _controller(
      shopping: shopping,
      meals: [
        MealScheduleEntry(
          id: 'meal-1',
          recipeId: 'braise',
          date: DateTime(2026, 7, 9),
          mealLabel: 'Dinner',
          servingSize: 2,
        ),
      ],
      pantryRepository: _FakePantryRepository([]),
      shoppingSchedule: ShoppingSchedule(
        householdId: 'solo-household',
        cadence: ShoppingScheduleCadence.weekly,
        isoWeekday: DateTime.saturday,
        effectiveFrom: DateTime(2026, 7, 4),
        isActive: true,
        createdAt: DateTime(2026, 7),
        updatedAt: DateTime(2026, 7),
        updatedByUserId: 'user-1',
      ),
    );

    await sut.reconcileScheduledLists([
      ScheduledShoppingRange(
        start: DateTime(2026, 7, 9),
        end: DateTime(2026, 7, 11),
      ),
    ]);

    final intent = shopping.allocation?.intent;
    expect(intent, isA<ScheduledShoppingAllocationIntent>());
    final scheduled = switch (intent) {
      final ScheduledShoppingAllocationIntent value => value,
      _ => throw StateError('Expected scheduled allocation.'),
    };
    expect(scheduled.startDate, DateTime(2026, 7, 5));
    expect(scheduled.endDate, DateTime(2026, 7, 11));
    expect(scheduled.occurrenceDate, DateTime(2026, 7, 11));
  });

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

    expect(record.id, 'server-derived-allocation');
    expect(record.type, ShoppingListType.emergency);
    expect(record.items, isEmpty);
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
            unit: UnitId.g,
          ),
        ],
      );

      final intent = shopping.allocation?.intent;
      expect(intent, isA<EmergencyShoppingAllocationIntent>());
      final emergency = switch (intent) {
        final EmergencyShoppingAllocationIntent value => value,
        _ => throw StateError('Expected emergency allocation.'),
      };
      expect(emergency.demands, hasLength(1));
      expect(emergency.demands.single.ingredientId, 'tomato');
      expect(emergency.demands.single.quantityNeeded, 300);
      expect(emergency.demands.single.unit, UnitId.g);
      expect(record.type, ShoppingListType.emergency);
      expect(record.generatedForRangeStart, DateTime(2026, 7, 6));
      expect(record.generatedForRangeEnd, DateTime(2026, 7, 6));
      expect(record.items, isEmpty);
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
          unit: UnitId.ml,
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
          unit: UnitId.ml,
          purchaseDate: DateTime(2026, 6),
          isBulk: true,
        ),
        PurchaseRecord(
          id: 'oil-july',
          householdId: 'solo-household',
          ingredientId: 'oil',
          quantity: 1000,
          unit: UnitId.ml,
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

    expect(record.type, ShoppingListType.suggested);
    expect(record.items, isEmpty);
  });

  test(
    'createSuggestedListFromBulkStatus persists one due bulk line',
    () async {
      final shopping = _FakeShoppingRepository();
      final status = BulkPantryStatus(
        item: _pantryItem(
          id: 'rice-stock',
          ingredientId: 'rice',
          quantity: 100,
          unit: UnitId.g,
          section: PantrySection.bulk,
          lastPurchaseDate: DateTime(2026, 6),
        ),
        estimatedConsumptionRatePerDay: 25,
        estimatedEmptyDate: DateTime(2026, 7, 8),
        recommendedPurchaseIntervalDays: 30,
        needsPurchaseSoon: true,
      );
      final sut = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        purchaseHistory: [
          PurchaseRecord(
            id: 'rice-june',
            householdId: 'solo-household',
            ingredientId: 'rice',
            quantity: 2000,
            unit: UnitId.g,
            purchaseDate: DateTime(2026, 6),
            isBulk: true,
          ),
          PurchaseRecord(
            id: 'rice-july',
            householdId: 'solo-household',
            ingredientId: 'rice',
            quantity: 3000,
            unit: UnitId.g,
            purchaseDate: DateTime(2026, 7),
            isBulk: true,
          ),
        ],
        ids: const ['suggested-rice', 'rice-line'],
        household: const ActiveHouseholdContext(
          id: 'solo-household',
          name: 'Test kitchen',
          role: HouseholdRole.admin,
          isJoint: true,
          hasPremium: true,
        ),
      );

      final record = await sut.createSuggestedListFromBulkStatus(status);

      expect(
        shopping.allocation?.intent,
        isA<SuggestedShoppingAllocationIntent>(),
      );
      expect(record.id, 'server-derived-allocation');
      expect(record.type, ShoppingListType.suggested);
      expect(record.generatedForRangeStart, DateTime(2026, 7, 6));
      expect(record.generatedForRangeEnd, DateTime(2026, 7, 6));
      expect(record.items, isEmpty);
    },
  );

  test(
    'createSuggestedListFromBulkStatus requires premium household',
    () async {
      final sut = _controller(
        shopping: _FakeShoppingRepository(),
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        household: const ActiveHouseholdContext(
          id: 'solo-household',
          name: 'Test kitchen',
          role: HouseholdRole.admin,
          isJoint: true,
          hasPremium: false,
        ),
      );

      expect(
        () => sut.createSuggestedListFromBulkStatus(
          BulkPantryStatus(
            item: _pantryItem(
              id: 'rice-stock',
              ingredientId: 'rice',
              quantity: 0,
              unit: UnitId.g,
              section: PantrySection.bulk,
            ),
            estimatedConsumptionRatePerDay: 1,
            estimatedEmptyDate: DateTime(2026, 7, 6),
            recommendedPurchaseIntervalDays: null,
            needsPurchaseSoon: true,
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'createSuggestedListFromBulkStatus reuses a pending duplicate line',
    () async {
      final shopping = _FakeShoppingRepository();
      final existing = ShoppingListRecord(
        id: 'pending-shop',
        householdId: 'solo-household',
        type: ShoppingListType.scheduled,
        shoppingDate: DateTime(2026, 7, 7),
        generatedForRangeStart: DateTime(2026, 7, 7),
        generatedForRangeEnd: DateTime(2026, 7, 7),
        status: ShoppingListStatus.pending,
        createdAt: DateTime(2026, 7, 6),
        updatedAt: DateTime(2026, 7, 6),
        items: const [
          ShoppingListItemRecord(
            id: 'rice-line',
            shoppingListId: 'pending-shop',
            ingredientId: 'rice',
            quantityNeeded: 2000,
            unit: UnitId.g,
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: [],
          ),
        ],
      );
      shopping.store(existing);
      final commands = _FakeShoppingCommandRepository(shopping: shopping);
      final sut = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        commandRepository: commands,
        household: const ActiveHouseholdContext(
          id: 'solo-household',
          name: 'Test kitchen',
          role: HouseholdRole.admin,
          isJoint: true,
          hasPremium: true,
        ),
      );

      final record = await sut.createSuggestedListFromBulkStatus(
        BulkPantryStatus(
          item: _pantryItem(
            id: 'rice-stock',
            ingredientId: 'rice',
            quantity: 100,
            unit: UnitId.g,
            section: PantrySection.bulk,
          ),
          estimatedConsumptionRatePerDay: 25,
          estimatedEmptyDate: DateTime(2026, 7, 8),
          recommendedPurchaseIntervalDays: 30,
          needsPurchaseSoon: true,
        ),
      );

      expect(record, same(existing));
      expect(shopping.allocation, isNull);
      expect(shopping.lists, hasLength(1));
    },
  );

  test('reconcileShoppingSuggestions writes the bounded core recovery through '
      'the trusted upsert', () async {
    final shopping = _FakeShoppingRepository();
    final sut = _controller(
      shopping: shopping,
      meals: [
        MealScheduleEntry(
          id: 'near-term-meal',
          recipeId: 'braise',
          date: DateTime(2026, 7, 10),
          mealLabel: 'Dinner',
          servingSize: 2,
        ),
      ],
      pantryRepository: _FakePantryRepository([]),
    );

    await sut.reconcileShoppingSuggestions();

    final intent = shopping.allocation?.intent;
    expect(intent, isA<SuggestedShoppingAllocationIntent>());
    final suggestion = switch (intent) {
      final SuggestedShoppingAllocationIntent value => value,
      _ => throw StateError('Expected suggested allocation.'),
    };
    expect(suggestion.originId, 'recovery:core:v1');
    expect(suggestion.startDate, DateTime(2026, 7, 6));
    expect(suggestion.endDate, DateTime(2026, 7, 12));
  });

  test(
    'reconcileShoppingSuggestions cancels its obsolete core recovery through '
    'the trusted upsert',
    () async {
      final shopping = _FakeShoppingRepository()
        ..store(
          ShoppingListRecord(
            id: 'suggested_recovery_20260706_20260712',
            householdId: 'solo-household',
            type: ShoppingListType.suggested,
            shoppingDate: DateTime(2026, 7, 6),
            generatedForRangeStart: DateTime(2026, 7, 6),
            generatedForRangeEnd: DateTime(2026, 7, 12),
            status: ShoppingListStatus.pending,
            originId: 'recovery:core:v1',
            revision: 4,
            createdAt: DateTime(2026, 7, 6),
            updatedAt: DateTime(2026, 7, 6),
            items: const [],
          ),
        );
      final sut = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
      );

      await sut.reconcileShoppingSuggestions();

      expect(shopping.deletedListId, 'suggested_recovery_20260706_20260712');
    },
  );

  test(
    'reconcileShoppingSuggestions denies a member before any trusted write',
    () {
      final shopping = _FakeShoppingRepository();
      final sut = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        household: const ActiveHouseholdContext(
          id: 'solo-household',
          name: 'Test kitchen',
          role: HouseholdRole.member,
          isJoint: true,
          hasPremium: false,
        ),
      );

      expect(sut.reconcileShoppingSuggestions, throwsStateError);
      expect(shopping.lists, isEmpty);
    },
  );

  test(
    'checklist mutations use trusted variants and stable retry ids',
    () async {
      final shopping = _FakeShoppingRepository();
      final commands = _FakeShoppingCommandRepository(
        shopping: shopping,
        mutationResponses: [
          (_) => Future.error(
            const ShoppingCommandFailure(
              ShoppingCommandFailureKind.unavailable,
            ),
          ),
          (request) async => ShoppingCommandResult(
            listId: request.listId,
            status: ShoppingCommandStatus.pending,
            revision: request.expectedRevision + 1,
            alreadyApplied: true,
          ),
        ],
      );
      final sut = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        commandRepository: commands,
        ids: const ['manual-line'],
      );

      await expectLater(
        sut.addItem(
          listId: 'list-1',
          expectedRevision: 3,
          ingredientId: 'rice',
          quantityNeeded: 2,
          unit: UnitId.kg,
        ),
        throwsA(isA<ShoppingCommandFailure>()),
      );
      await sut.addItem(
        listId: 'list-1',
        expectedRevision: 3,
        ingredientId: 'rice',
        quantityNeeded: 2,
        unit: UnitId.kg,
      );

      expect(commands.mutations, hasLength(2));
      expect(commands.mutations[0].commandId, 'write-command-1');
      expect(commands.mutations[1].commandId, 'write-command-1');
      expect(commands.mutations[0].itemId, 'manual-line');
      expect(commands.mutations[1].itemId, 'manual-line');
      final add = commands.mutations[0].mutation as AddShoppingListItemMutation;
      expect(add.ingredientId, 'rice');
      expect(add.quantityNeeded, 2);
      expect(add.unit, UnitId.kg);
      expect(add.status, ShoppingListItemStatus.unchecked);
      expect(add.purchasedQuantity, isNull);
      expect(add.substituteIngredientId, isNull);
    },
  );

  test('checklist edit variants carry exact quantities and item ids', () async {
    final shopping = _FakeShoppingRepository();
    final commands = _FakeShoppingCommandRepository(
      shopping: shopping,
      mutationResponses: [
        for (var revision = 5; revision <= 7; revision++)
          (request) async => ShoppingCommandResult(
            listId: request.listId,
            status: ShoppingCommandStatus.pending,
            revision: revision,
            alreadyApplied: false,
          ),
      ],
    );
    final sut = _controller(
      shopping: shopping,
      meals: const [],
      pantryRepository: _FakePantryRepository([]),
      commandRepository: commands,
      writeIds: const [
        'needed-command-1',
        'purchased-command-1',
        'remove-command-1',
      ],
    );

    await sut.setItemNeededQuantity(
      listId: 'list-1',
      itemId: 'line-1',
      expectedRevision: 4,
      quantityNeeded: 3.5,
    );
    await sut.setItemPurchasedQuantity(
      listId: 'list-1',
      itemId: 'line-1',
      expectedRevision: 5,
      purchasedQuantity: 5,
    );
    await sut.removeItem(
      listId: 'list-1',
      itemId: 'line-1',
      expectedRevision: 6,
    );

    expect(
      (commands.mutations[0].mutation
              as SetShoppingListItemNeededQuantityMutation)
          .quantityNeeded,
      3.5,
    );
    expect(
      (commands.mutations[1].mutation
              as SetShoppingListItemPurchasedQuantityMutation)
          .purchasedQuantity,
      5,
    );
    expect(
      commands.mutations[2].mutation,
      isA<RemoveShoppingListItemMutation>(),
    );
    expect(
      commands.mutations.map((request) => request.itemId),
      everyElement('line-1'),
    );
  });

  test(
    'invalid checklist input and denied roles make no trusted write',
    () async {
      final shopping = _FakeShoppingRepository();
      final commands = _FakeShoppingCommandRepository(shopping: shopping);
      final admin = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        commandRepository: commands,
      );
      final member = _controller(
        shopping: shopping,
        meals: const [],
        pantryRepository: _FakePantryRepository([]),
        commandRepository: commands,
        household: const ActiveHouseholdContext(
          id: 'solo-household',
          name: 'Test kitchen',
          role: HouseholdRole.member,
          isJoint: true,
          hasPremium: true,
        ),
      );

      expect(
        () => admin.setItemNeededQuantity(
          listId: 'list-1',
          itemId: 'line-1',
          expectedRevision: 0,
          quantityNeeded: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => member.removeItem(
          listId: 'list-1',
          itemId: 'line-1',
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      expect(commands.mutations, isEmpty);
    },
  );

  test('command controller keeps id stable across retry', () async {
    final commands = _FakeShoppingCommandRepository(
      completeResponses: [
        (_) => Future.error(
          const ShoppingCommandFailure(ShoppingCommandFailureKind.unavailable),
        ),
        (request) async => ShoppingCommandResult(
          listId: request.listId,
          status: ShoppingCommandStatus.completed,
          alreadyApplied: true,
          completionId: request.commandId,
        ),
      ],
    );
    final sut = ShoppingCommandController(
      repository: commands,
      householdId: 'solo-household',
      household: null,
      idGenerator: FakeIdGenerator(['complete-command-1']),
    );

    await expectLater(
      sut.completeList('list-1'),
      throwsA(
        isA<ShoppingCommandFailure>().having(
          (failure) => failure.kind,
          'kind',
          ShoppingCommandFailureKind.unavailable,
        ),
      ),
    );
    final result = await sut.completeList('list-1');

    expect(commands.completed?.householdId, 'solo-household');
    expect(commands.completed?.listId, 'list-1');
    expect(commands.completed?.commandId, 'complete-command-1');
    expect(sut.completionCommandIdFor('list-1'), 'complete-command-1');
    expect(result?.alreadyApplied, isTrue);
  });

  test(
    'command controller triggers recovery only after trusted completion',
    () async {
      final commands = _FakeShoppingCommandRepository();
      var recoveryCalls = 0;
      final sut = ShoppingCommandController(
        repository: commands,
        householdId: 'solo-household',
        household: null,
        idGenerator: FakeIdGenerator([
          'complete-command-1',
          'delete-command-1',
        ]),
        onShoppingCompleted: () async => recoveryCalls++,
      );

      await sut.completeList('list-1');
      await sut.deleteList('list-2');

      expect(recoveryCalls, 1);
    },
  );

  test(
    'command controller suppresses duplicate in-flight completion',
    () async {
      final pending = Completer<ShoppingCommandResult>();
      final commands = _FakeShoppingCommandRepository(
        completeResponses: [(_) => pending.future],
      );
      final sut = ShoppingCommandController(
        repository: commands,
        householdId: 'solo-household',
        household: null,
        idGenerator: FakeIdGenerator(['complete-command-1']),
      );

      final first = sut.completeList('list-1');
      final duplicate = await sut.completeList('list-1');

      expect(duplicate, isNull);
      expect(sut.isCompletionInFlight('list-1'), isTrue);
      expect(commands.completeCallCount, 1);
      pending.complete(
        const ShoppingCommandResult(
          listId: 'list-1',
          status: ShoppingCommandStatus.completed,
          alreadyApplied: false,
        ),
      );
      await first;
      expect(sut.isCompletionInFlight('list-1'), isFalse);
    },
  );

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

  test('command controller rejects member role at boundary', () async {
    final sut = ShoppingCommandController(
      repository: _FakeShoppingCommandRepository(),
      householdId: 'solo-household',
      household: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Test kitchen',
        role: HouseholdRole.member,
        isJoint: true,
        hasPremium: true,
      ),
      idGenerator: FakeIdGenerator(['command-1']),
    );

    expect(() => sut.completeList('list-1'), throwsStateError);
    expect(() => sut.deleteList('suggested-1'), throwsStateError);
  });
}
