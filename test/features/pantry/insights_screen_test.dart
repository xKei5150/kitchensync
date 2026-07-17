// SIZE_OK: insights screen tests cover existing dashboard state variations.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/insights_screen.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

PantryItem _item({
  required String id,
  required PantrySection section,
  DateTime? expiry,
}) {
  final now = DateTime.now();
  return PantryItem(
    id: id,
    householdId: 'h1',
    ingredientId: 'ing-$id',
    quantity: 1,
    unit: UnitId.piece,
    section: section,
    expiryDate: expiry,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pump(WidgetTester tester, List<PantryItem> items) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeHouseholdContextProvider.overrideWithValue(
          const ActiveHouseholdContext(
            id: 'solo-household',
            name: 'Test kitchen',
            role: HouseholdRole.admin,
            isJoint: true,
            hasPremium: true,
          ),
        ),
        pantryAllItemsStreamProvider.overrideWith((ref) => Stream.value(items)),
        wasteHistoryStreamProvider.overrideWith(
          (ref) => Stream.value(<WasteEvent>[]),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const InsightsScreen()),
    ),
  );
  await tester.pump();
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
    const listId = 'server-bulk-list';
    shopping.upserted = ShoppingListRecord(
      id: listId,
      householdId: command.intent.householdId,
      type: ShoppingListType.suggested,
      shoppingDate: command.intent.startDate,
      generatedForRangeStart: command.intent.startDate,
      generatedForRangeEnd: command.intent.endDate,
      status: ShoppingListStatus.pending,
      originId: 'bulk',
      createdAt: command.intent.startDate,
      updatedAt: command.intent.startDate,
      items: [
        const ShoppingListItemRecord(
          id: 'server-rice',
          shoppingListId: listId,
          ingredientId: 'rice',
          quantityNeeded: 2500,
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

class _EmptyCalendarRepository implements CalendarRepository {
  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(const []);

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
  ) => Stream.value(const []);

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

class _FakePantryRepository implements PantryRepository {
  const _FakePantryRepository(this.items);

  final List<PantryItem> items;

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => Stream.value(
    items.where((item) => item.section == section).toList(growable: false),
  );

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      Stream.value(null);

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async => null;

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
  Future<String> uploadPhoto(
    String householdId,
    String itemId,
    File file,
  ) async => '';

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) async {}

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required UnitId unit,
    required PantrySection section,
  }) async => null;
}

class _FakePurchaseHistoryRepository implements PurchaseHistoryRepository {
  const _FakePurchaseHistoryRepository(this.records);

  final List<PurchaseRecord> records;

  @override
  Stream<List<PurchaseRecord>> watchByHousehold(String householdId) =>
      Stream.value(records);

  @override
  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  ) => Stream.value(
    records
        .where((record) => record.ingredientId == ingredientId)
        .toList(growable: false),
  );

  @override
  Future<void> record(PurchaseRecord record) async {}
}

class _EmptyWasteRepository implements WasteRepository {
  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Future<void> log(WasteEvent event) async {}
}

class _EmptyRecipeRepository implements RecipeRepository {
  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value(const []);

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

void main() {
  testWidgets('Insights counts live items into the freshness donut', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pump(tester, [
      _item(
        id: '1',
        section: PantrySection.food,
        expiry: now.add(const Duration(days: 30)),
      ),
      _item(
        id: '2',
        section: PantrySection.food,
        expiry: now.add(const Duration(days: 1)),
      ),
      _item(
        id: '3',
        section: PantrySection.bulk,
        expiry: now.subtract(const Duration(days: 2)),
      ),
      _item(id: '4', section: PantrySection.leftover),
    ]);

    // Four items measured, named in the donut well.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('items'), findsOneWidget);
    // Freshness legend, each bucket labelled (never colour alone).
    expect(find.text('Fresh'), findsOneWidget);
    expect(find.text('Soon'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
  });

  testWidgets('Insights renders the section balance from live sections', (
    tester,
  ) async {
    await _pump(tester, [
      _item(id: '1', section: PantrySection.food),
      _item(id: '2', section: PantrySection.food),
      _item(id: '3', section: PantrySection.bulk),
      _item(id: '4', section: PantrySection.leftover),
    ]);

    expect(find.text('Section balance'.toUpperCase()), findsOneWidget);
    // 2/4 of the pantry is Food.
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('Insights keeps the premium veil over the working charts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(
            const ActiveHouseholdContext(
              id: 'solo-household',
              name: 'Test kitchen',
              role: HouseholdRole.admin,
              isJoint: true,
              hasPremium: false,
            ),
          ),
          pantryAllItemsStreamProvider.overrideWith(
            (ref) =>
                Stream.value([_item(id: '1', section: PantrySection.food)]),
          ),
          wasteHistoryStreamProvider.overrideWith(
            (ref) => Stream.value(<WasteEvent>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KsPremiumLock), findsOneWidget);
    expect(find.text('See your pantry, measured'), findsOneWidget);
  });

  testWidgets('Insights can add due bulk recommendation to shopping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shopping = _FakeShoppingRepository();
    final shoppingCommands = _FakeShoppingCommandRepository(shopping);
    final bulkItem = PantryItem(
      id: 'rice-stock',
      householdId: 'solo-household',
      ingredientId: 'rice',
      quantity: 0,
      unit: UnitId.g,
      section: PantrySection.bulk,
      lastPurchaseDate: DateTime(2026, 6),
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );
    final purchases = [
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
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(
            const ActiveHouseholdContext(
              id: 'solo-household',
              name: 'Test kitchen',
              role: HouseholdRole.admin,
              isJoint: true,
              hasPremium: true,
            ),
          ),
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.value([bulkItem]),
          ),
          wasteHistoryStreamProvider.overrideWith(
            (ref) => Stream.value(<WasteEvent>[]),
          ),
          purchaseHistoryStreamProvider.overrideWith(
            (ref) => Stream.value(purchases),
          ),
          pantryIngredientProvider('rice').overrideWith(
            (ref) async => Result.success(
              Ingredient(
                id: 'rice',
                name: 'jasmine rice',
                displayNames: const {'en': 'Jasmine Rice'},
                category: IngredientCategory.grain,
                defaultUnit: UnitId.g,
                allowedUnits: const [UnitId.g],
                scope: IngredientScope.global,
                createdAt: DateTime(2026, 7),
                updatedAt: DateTime(2026, 7),
              ),
            ),
          ),
          shoppingPlanningControllerProvider.overrideWithValue(
            ShoppingPlanningController(
              repository: shopping,
              writeCoordinator: ShoppingWriteCoordinator(
                repository: shoppingCommands,
                allocationRepository: shoppingCommands,
                householdId: 'solo-household',
                idGenerator: FakeIdGenerator(['bulk-write']),
              ),
              calendarRepository: _EmptyCalendarRepository(),
              pantryRepository: _FakePantryRepository([bulkItem]),
              purchaseHistoryRepository: _FakePurchaseHistoryRepository(
                purchases,
              ),
              wasteRepository: _EmptyWasteRepository(),
              recipeRepository: _EmptyRecipeRepository(),
              householdId: 'solo-household',
              household: const ActiveHouseholdContext(
                id: 'solo-household',
                name: 'Test kitchen',
                role: HouseholdRole.admin,
                isJoint: true,
                hasPremium: true,
              ),
              idGenerator: FakeIdGenerator(['bulk-list', 'rice-line']),
              clock: FakeClock(DateTime(2026, 7, 6, 9)),
              shoppingScheduleRepository:
                  const _EmptyShoppingScheduleRepository(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jasmine Rice'), findsOneWidget);
    expect(find.text('rice'), findsNothing);

    await tester.tap(find.byTooltip('Add to shopping'));
    await tester.pumpAndSettle();

    expect(shopping.upserted, isNotNull);
    expect(shopping.upserted!.type, ShoppingListType.suggested);
    expect(shopping.upserted!.items.single.ingredientId, 'rice');
    expect(shopping.upserted!.items.single.quantityNeeded, 2500);
    expect(find.text('Jasmine Rice added to shopping'), findsOneWidget);
  });

  testWidgets('Insights renders in dark theme without error', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(
            const ActiveHouseholdContext(
              id: 'solo-household',
              name: 'Test kitchen',
              role: HouseholdRole.admin,
              isJoint: true,
              hasPremium: true,
            ),
          ),
          pantryAllItemsStreamProvider.overrideWith(
            (ref) =>
                Stream.value([_item(id: '1', section: PantrySection.food)]),
          ),
          wasteHistoryStreamProvider.overrideWith(
            (ref) => Stream.value(<WasteEvent>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Insights'), findsOneWidget);
  });
}
