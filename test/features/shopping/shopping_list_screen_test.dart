// SIZE_OK: shopping list tests cover existing broad list UI workflows.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/wcag_contrast.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart';
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
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_list_screen.dart';

class _FakeShoppingRepository extends ShoppingRepository {
  _FakeShoppingRepository(this.lists);

  final List<ShoppingListRecord> lists;
  final _controller = StreamController<List<ShoppingListRecord>>.broadcast();

  void dispose() => _controller.close();

  void emit() => _controller.add(List.unmodifiable(lists));

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) async* {
    yield lists
        .where((list) => list.householdId == householdId)
        .toList(growable: false);
    yield* _controller.stream.map(
      (records) => records
          .where((list) => list.householdId == householdId)
          .toList(growable: false),
    );
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
}

class _FakeShoppingCommandRepository implements ShoppingCommandRepository {
  _FakeShoppingCommandRepository(
    this.repository, {
    this.completeResponses,
    this.mutationResponses,
  });

  final _FakeShoppingRepository repository;
  final List<Future<ShoppingCommandResult> Function(ShoppingCommandRequest)>?
  completeResponses;
  final List<
    Future<ShoppingCommandResult> Function(ShoppingListItemMutationCommand)
  >?
  mutationResponses;
  final upsertRequests = <ShoppingListUpsertCommand>[];
  final mutationRequests = <ShoppingListItemMutationCommand>[];
  final requests = <ShoppingCommandRequest>[];
  int callCount = 0;
  int mutationCallCount = 0;

  @override
  Future<ShoppingCommandResult> upsertList(
    ShoppingListUpsertCommand command,
  ) async {
    upsertRequests.add(command);
    return ShoppingCommandResult(
      listId: command.listId,
      status: ShoppingCommandStatus.pending,
      alreadyApplied: false,
    );
  }

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) async {
    mutationRequests.add(command);
    final responses = mutationResponses;
    if (responses != null) {
      return responses[mutationCallCount++](command);
    }
    final listIndex = repository.lists.indexWhere(
      (list) =>
          list.householdId == command.householdId && list.id == command.listId,
    );
    if (listIndex < 0) {
      throw StateError('Missing shopping list ${command.listId}.');
    }
    final list = repository.lists[listIndex];
    if (command.expectedRevision != list.revision) {
      throw StateError(
        'Expected revision ${command.expectedRevision}, '
        'found ${list.revision}.',
      );
    }
    final mutation = command.mutation;
    final itemIndex = list.items.indexWhere(
      (item) => item.id == command.itemId,
    );
    if (mutation is! AddShoppingListItemMutation && itemIndex < 0) {
      throw StateError('Missing shopping item ${command.itemId}.');
    }

    repository.lists[listIndex] = ShoppingListRecord(
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
      revision: list.revision + 1,
      createdAt: list.createdAt,
      updatedAt: list.updatedAt,
      items: _applyWidgetMutation(list, command.itemId, mutation),
    );
    repository.emit();
    return ShoppingCommandResult(
      listId: command.listId,
      status: ShoppingCommandStatus.pending,
      alreadyApplied: false,
      revision: list.revision + 1,
    );
  }

  @override
  Future<ShoppingCommandResult> completeList(
    ShoppingCommandRequest request,
  ) async {
    requests.add(request);
    final responses = completeResponses;
    if (responses != null) return responses[callCount++](request);
    callCount++;
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
  ) async => ShoppingCommandResult(
    listId: request.listId,
    status: ShoppingCommandStatus.deleted,
    alreadyApplied: false,
  );
}

List<ShoppingListItemRecord> _applyWidgetMutation(
  ShoppingListRecord list,
  String itemId,
  ShoppingListItemMutation mutation,
) => switch (mutation) {
  AddShoppingListItemMutation() => List.unmodifiable([
    ...list.items,
    ShoppingListItemRecord(
      id: itemId,
      shoppingListId: list.id,
      ingredientId: mutation.ingredientId,
      quantityNeeded: mutation.quantityNeeded,
      unit: mutation.unit,
      status: mutation.status,
      substituteIngredientId: mutation.substituteIngredientId,
      substituteQuantity: mutation.substituteQuantity,
      substituteUnit: mutation.substituteUnit,
      purchasedQuantity: mutation.purchasedQuantity,
      sourceMealLinks: const [],
    ),
  ]),
  RemoveShoppingListItemMutation() => List.unmodifiable(
    list.items.where((item) => item.id != itemId),
  ),
  SetShoppingListItemNeededQuantityMutation() => List.unmodifiable([
    for (final item in list.items)
      if (item.id == itemId)
        item.withQuantityNeeded(mutation.quantityNeeded)
      else
        item,
  ]),
  SetShoppingListItemPurchasedQuantityMutation() => List.unmodifiable([
    for (final item in list.items)
      if (item.id == itemId)
        _copyWidgetItem(item, purchasedQuantity: mutation.purchasedQuantity)
      else
        item,
  ]),
  SetShoppingListItemStatusMutation() => List.unmodifiable([
    for (final item in list.items)
      if (item.id == itemId)
        _copyWidgetItem(
          item,
          status: mutation.status,
          purchasedQuantity: mutation.purchasedQuantity,
          substituteIngredientId: mutation.substituteIngredientId,
          substituteQuantity: mutation.substituteQuantity,
          substituteUnit: mutation.substituteUnit,
        )
      else
        item,
  ]),
};

ShoppingListItemRecord _copyWidgetItem(
  ShoppingListItemRecord item, {
  ShoppingListItemStatus? status,
  double? purchasedQuantity,
  String? substituteIngredientId,
  double? substituteQuantity,
  UnitId? substituteUnit,
}) => ShoppingListItemRecord(
  id: item.id,
  shoppingListId: item.shoppingListId,
  ingredientId: item.ingredientId,
  quantityNeeded: item.quantityNeeded,
  unit: item.unit,
  status: status ?? item.status,
  substituteIngredientId: substituteIngredientId,
  substituteQuantity: substituteQuantity,
  substituteUnit: substituteUnit,
  purchasedQuantity: purchasedQuantity,
  sourceMealLinks: item.sourceMealLinks,
);

class _FakeShoppingScheduleRepository implements ShoppingScheduleRepository {
  const _FakeShoppingScheduleRepository();

  @override
  Future<void> save(ShoppingSchedule schedule) async {}

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(null);
}

ShoppingPlanningController _planningController(
  _FakeShoppingRepository repository,
  _FakeShoppingCommandRepository commands, {
  List<String> ids = const ['mutation-command-1'],
}) {
  final idGenerator = FakeIdGenerator(ids);
  return ShoppingPlanningController(
    repository: repository,
    writeCoordinator: ShoppingWriteCoordinator(
      repository: commands,
      householdId: 'solo-household',
      idGenerator: idGenerator,
    ),
    calendarRepository: _FakeCalendarRepository([]),
    pantryRepository: _FakePantryRepository([]),
    purchaseHistoryRepository: _FakePurchaseHistoryRepository(),
    wasteRepository: _FakeWasteRepository(),
    recipeRepository: _FakeRecipeRepository(),
    householdId: 'solo-household',
    household: _activeHousehold,
    idGenerator: idGenerator,
    clock: FakeClock(DateTime(2026, 7)),
    shoppingScheduleRepository: const _FakeShoppingScheduleRepository(),
  );
}

class _FakePurchaseHistoryRepository implements PurchaseHistoryRepository {
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
  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      const Stream.empty();

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

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(this.items);

  final List<PantryItem> items;

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
      Stream.value(_find((item) => item.id == itemId));

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async => _find(
    (item) =>
        item.householdId == householdId && item.ingredientId == ingredientId,
  );

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required UnitId unit,
    required PantrySection section,
  }) async => _find(
    (item) =>
        item.householdId == householdId &&
        item.ingredientId == ingredientId &&
        item.unit == unit &&
        item.section == section,
  );

  @override
  Future<void> add(PantryItem item) async {
    items.add(item);
  }

  @override
  Future<void> update(PantryItem item) async {
    items
      ..removeWhere((current) => current.id == item.id)
      ..add(item);
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
  Future<String> uploadPhoto(String householdId, String itemId, File file) =>
      throw UnimplementedError();

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) async {}

  PantryItem? _find(bool Function(PantryItem item) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository(this.meals);

  final List<MealScheduleEntry> meals;
  final upserted = <MealScheduleEntry>[];

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
    upserted.add(entry);
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

class _FakeIngredientRepository implements IngredientRepository {
  _FakeIngredientRepository(this.ingredients);

  final List<Ingredient> ingredients;

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) => Stream.value(
    ingredients
        .where((ingredient) => ids.contains(ingredient.id))
        .toList(growable: false),
  );

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async {
    for (final ingredient in ingredients) {
      if (ingredient.id == id) {
        return ingredient;
      }
    }
    return null;
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  }) async => ingredients
      .where((ingredient) => ingredient.name.contains(query))
      .take(limit)
      .toList(growable: false);

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<void> createCustom(Ingredient ingredient) async {}

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      Stream.value(const []);
}

Ingredient _ingredientWithLocalUnit() {
  final now = DateTime(2026, 7, 5, 12);
  return Ingredient(
    id: 'pepper',
    name: 'pepper',
    displayNames: const {'en': 'Pepper'},
    category: IngredientCategory.produce,
    defaultUnit: UnitId('bundle'),
    allowedUnits: [UnitId('bundle'), UnitId.g],
    localUnitDefinitions: [
      UnitDefinition(
        id: UnitId('bundle'),
        label: 'Bundle',
        pluralLabel: 'Bundles',
        dimension: UnitDimension.informal,
        family: UnitSystemFamily.local,
      ),
    ],
    scope: IngredientScope.householdCustom,
    householdId: 'solo-household',
    createdAt: now,
    updatedAt: now,
  );
}

Ingredient _basicIngredient(String id, UnitId unit) {
  final now = DateTime(2026, 7, 5, 12);
  return Ingredient(
    id: id,
    name: id,
    displayNames: {'en': _displayNameForId(id)},
    category: IngredientCategory.produce,
    defaultUnit: unit,
    allowedUnits: [unit],
    scope: IngredientScope.householdCustom,
    householdId: 'solo-household',
    createdAt: now,
    updatedAt: now,
  );
}

String _displayNameForId(String id) => id
    .split(RegExp('[-_]'))
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

ShoppingListRecord _record() {
  final now = DateTime(2026, 7, 5, 12);
  return ShoppingListRecord(
    id: 'persisted-shop',
    householdId: 'solo-household',
    type: ShoppingListType.shopNow,
    shoppingDate: now,
    generatedForRangeStart: DateTime(2026, 7, 6),
    generatedForRangeEnd: DateTime(2026, 7, 12),
    status: ShoppingListStatus.pending,
    createdAt: now,
    updatedAt: now,
    items: const [
      ShoppingListItemRecord(
        id: 'item-beans',
        shoppingListId: 'persisted-shop',
        ingredientId: 'beans',
        quantityNeeded: 2,
        unit: UnitId.piece,
        status: ShoppingListItemStatus.unchecked,
        sourceMealLinks: [],
      ),
      ShoppingListItemRecord(
        id: 'item-tomato',
        shoppingListId: 'persisted-shop',
        ingredientId: 'tomato',
        quantityNeeded: 500,
        unit: UnitId.g,
        status: ShoppingListItemStatus.bought,
        sourceMealLinks: [],
      ),
    ],
  );
}

ShoppingListRecord _recordWith({
  ShoppingListStatus status = ShoppingListStatus.pending,
  List<ShoppingListItemRecord>? items,
}) {
  final record = _record();
  return ShoppingListRecord(
    id: record.id,
    householdId: record.householdId,
    type: record.type,
    shoppingDate: record.shoppingDate,
    generatedForRangeStart: record.generatedForRangeStart,
    generatedForRangeEnd: record.generatedForRangeEnd,
    status: status,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    items: items ?? record.items,
  );
}

GoRouter _shoppingListRouter() => GoRouter(
  initialLocation: '/list',
  routes: [
    GoRoute(
      path: '/list',
      builder: (_, __) => const ShoppingListScreen(listId: 'persisted-shop'),
    ),
    GoRoute(
      path: '/ingredient/pick',
      builder: (_, __) => const IngredientPickerScreen(),
    ),
  ],
);

void main() {
  testWidgets('ShoppingListScreen without a list id shows an empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(),
        ),
      ),
    );

    expect(find.text('No shopping list selected'), findsOneWidget);
    expect(find.byType(KsChecklistRow), findsNothing);
  });

  testWidgets('ShoppingListScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ShoppingListScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ShoppingListScreen renders persisted shopping records by id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('White beans'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(KsChecklistRow), findsNWidgets(2));
    expect(
      find.textContaining('IN STORE · SUN 5 JUL · 6 JUL-12 JUL'),
      findsOneWidget,
    );
    expect(find.text('Shop Now'), findsOneWidget);
    expect(find.text('In-store · Fri 27'), findsNothing);
    expect(find.text('Weekly shop'), findsNothing);
    expect(find.byType(KsMemberAvatar), findsNothing);
  });

  testWidgets('routed list header clears an iPhone top safe area', (
    tester,
  ) async {
    const topInset = 59.0;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    final router = _shoppingListRouter();
    addTearDown(repo.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: topInset),
          viewPadding: EdgeInsets.only(top: topInset),
        ),
        child: ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
            activeHouseholdIdProvider.overrideWithValue('solo-household'),
            shoppingRepositoryProvider.overrideWithValue(repo),
            shoppingPlanningControllerProvider.overrideWithValue(
              _planningController(repo, commands),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerTop = tester.getTopLeft(find.byType(KsFolioHeader)).dy;
    // SafeArea consumes the 59px system inset; the list retains its 8px token.
    expect(headerTop, greaterThanOrEqualTo(topInset + 8));
  });

  testWidgets('adds a dictionary ingredient with a trusted stable item id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    final router = _shoppingListRouter();
    addTearDown(repo.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([_basicIngredient('rice', UnitId.kg)]),
          ),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(
              repo,
              commands,
              ids: const ['manual-rice', 'add-command-1'],
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add ingredient'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(KsSearchField), 'rice');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shopping-quantity-field')),
      '2.5',
    );
    await tester.tap(find.text('Add to list'));
    await tester.pumpAndSettle();

    final request = commands.mutationRequests.single;
    expect(request.itemId, 'manual-rice');
    expect(request.commandId, 'add-command-1');
    final mutation = request.mutation as AddShoppingListItemMutation;
    expect(mutation.ingredientId, 'rice');
    expect(mutation.quantityNeeded, 2.5);
    expect(mutation.unit, UnitId.kg);
    expect(find.text('Rice'), findsOneWidget);
  });

  testWidgets('edits needed and purchased quantities below and above needed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([
              _basicIngredient('beans', UnitId.piece),
              _basicIngredient('tomato', UnitId.g),
            ]),
          ),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(
              repo,
              commands,
              ids: const ['needed-command', 'purchased-command'],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(KsChecklistRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit needed quantity'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shopping-quantity-field')),
      '3',
    );
    await tester.tap(find.text('Save needed quantity'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(KsChecklistRow).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit purchased quantity'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shopping-quantity-field')),
      '250',
    );
    await tester.tap(find.text('Save purchased quantity'));
    await tester.pumpAndSettle();

    expect(
      (commands.mutationRequests[0].mutation
              as SetShoppingListItemNeededQuantityMutation)
          .quantityNeeded,
      3,
    );
    expect(
      (commands.mutationRequests[1].mutation
              as SetShoppingListItemPurchasedQuantityMutation)
          .purchasedQuantity,
      250,
    );
    expect(repo.lists.single.items.last.purchasedQuantity, 250);
    expect(find.textContaining('partial'), findsOneWidget);
  });

  testWidgets('item actions remain reachable on a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([
              _basicIngredient('beans', UnitId.piece),
              _basicIngredient('tomato', UnitId.g),
            ]),
          ),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(KsChecklistRow).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Remove item'),
      100,
      scrollable: find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Remove item'));
    await tester.pumpAndSettle();

    expect(
      commands.mutationRequests.single.mutation,
      isA<RemoveShoppingListItemMutation>(),
    );
  });

  testWidgets('checklist exposes item actions with a visible control', (
    tester,
  ) async {
    final repo = _FakeShoppingRepository([_record()]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([
              _basicIngredient('beans', UnitId.piece),
            ]),
          ),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, _FakeShoppingCommandRepository(repo)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More item actions').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit needed quantity'), findsOneWidget);
    expect(find.text('Record substitution'), findsOneWidget);
  });

  testWidgets(
    'bought item keeps purchased edit after needed quantity changes',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakeShoppingRepository([_record()]);
      final commands = _FakeShoppingCommandRepository(repo);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
            activeHouseholdIdProvider.overrideWithValue('solo-household'),
            ingredientRepositoryProvider.overrideWithValue(
              _FakeIngredientRepository([
                _basicIngredient('beans', UnitId.piece),
                _basicIngredient('tomato', UnitId.g),
              ]),
            ),
            shoppingRepositoryProvider.overrideWithValue(repo),
            shoppingPlanningControllerProvider.overrideWithValue(
              _planningController(
                repo,
                commands,
                ids: const ['needed-command'],
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ShoppingListScreen(listId: 'persisted-shop'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(KsChecklistRow).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit needed quantity'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('shopping-quantity-field')),
        '600',
      );
      await tester.tap(find.text('Save needed quantity'));
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(KsChecklistRow).last);
      await tester.pumpAndSettle();

      expect(
        find.text('Edit purchased quantity', skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('purchased quantity above needed renders as extra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = _record();
    final bought = base.items.last;
    final repo = _FakeShoppingRepository([
      _recordWith(
        items: [
          base.items.first,
          _copyWidgetItem(bought, purchasedQuantity: 750),
        ],
      ),
    ]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([
              _basicIngredient('beans', UnitId.piece),
              _basicIngredient('tomato', UnitId.g),
            ]),
          ),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('extra'), findsOneWidget);
    expect(find.textContaining('750 g bought'), findsOneWidget);
  });

  testWidgets('remove failure preserves the row and retry id', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(
      repo,
      mutationResponses: [
        (_) => Future.error(
          const ShoppingCommandFailure(
            ShoppingCommandFailureKind.permissionDenied,
          ),
        ),
        (request) async {
          final list = repo.lists.single;
          repo.lists[0] = ShoppingListRecord(
            id: list.id,
            householdId: list.householdId,
            type: list.type,
            shoppingDate: list.shoppingDate,
            generatedForRangeStart: list.generatedForRangeStart,
            generatedForRangeEnd: list.generatedForRangeEnd,
            status: list.status,
            revision: 1,
            createdAt: list.createdAt,
            updatedAt: list.updatedAt,
            items: list.items,
          );
          repo.emit();
          return ShoppingCommandResult(
            listId: request.listId,
            status: ShoppingCommandStatus.pending,
            revision: 1,
            alreadyApplied: true,
          );
        },
      ],
    );
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.longPress(find.byType(KsChecklistRow).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove item'));
      await tester.pumpAndSettle();
      expect(find.text('White beans'), findsOneWidget);
    }
    expect(commands.mutationRequests, hasLength(2));
    expect(commands.mutationRequests[0].commandId, 'mutation-command-1');
    expect(commands.mutationRequests[1].commandId, 'mutation-command-1');
  });

  testWidgets('empty pending list shows Nothing to buy with add action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeShoppingRepository([_recordWith(items: const [])]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing to buy'), findsOneWidget);
    expect(find.text('Add an ingredient when needed.'), findsOneWidget);
    expect(find.text('Add ingredient'), findsWidgets);
    expect(find.byType(KsChecklistRow), findsNothing);
  });

  for (final status in [
    ShoppingListStatus.completed,
    ShoppingListStatus.cancelled,
  ]) {
    testWidgets('${status.name} list detail is immutable', (tester) async {
      final repo = _FakeShoppingRepository([_recordWith(status: status)]);
      final commands = _FakeShoppingCommandRepository(repo);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
            activeHouseholdIdProvider.overrideWithValue('solo-household'),
            shoppingRepositoryProvider.overrideWithValue(repo),
            shoppingPlanningControllerProvider.overrideWithValue(
              _planningController(repo, commands),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ShoppingListScreen(listId: 'persisted-shop'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add ingredient'), findsNothing);
      expect(find.text('Done shopping'), findsNothing);
      if (status == ShoppingListStatus.completed) {
        expect(
          find.textContaining('Completed by Household member'),
          findsOneWidget,
        );
        expect(find.textContaining('Shop Now'), findsWidgets);
      }
      await tester.longPress(find.byType(KsChecklistRow).first);
      await tester.pumpAndSettle();
      expect(find.text('Remove item'), findsNothing);
      expect(commands.mutationRequests, isEmpty);
    });
  }

  testWidgets('ShoppingListScreen persists checklist item status changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShoppingListScreen(listId: 'persisted-shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More item actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark bought'));
    await tester.pumpAndSettle();

    final request = commands.mutationRequests.single;
    expect(request.householdId, 'solo-household');
    expect(request.listId, 'persisted-shop');
    expect(request.itemId, 'item-beans');
    expect(request.commandId, 'mutation-command-1');
    expect(request.expectedRevision, 0);
    final mutation = request.mutation as SetShoppingListItemStatusMutation;
    expect(mutation.status, ShoppingListItemStatus.bought);
    expect(mutation.purchasedQuantity, 2);
    expect(mutation.substituteIngredientId, isNull);
    expect(mutation.substituteQuantity, isNull);
    expect(mutation.substituteUnit, isNull);
    expect(repo.lists.single.revision, 1);
    expect(repo.lists.single.items.first.status, ShoppingListItemStatus.bought);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets(
    'ShoppingListScreen records substitution status from row actions',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeShoppingRepository([_record()]);
      final commands = _FakeShoppingCommandRepository(repo);
      addTearDown(repo.dispose);
      final router = _shoppingListRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
            activeHouseholdIdProvider.overrideWithValue('solo-household'),
            ingredientRepositoryProvider.overrideWithValue(
              _FakeIngredientRepository([
                _basicIngredient('pepper', UnitId.piece),
              ]),
            ),
            recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
            shoppingRepositoryProvider.overrideWithValue(repo),
            shoppingPlanningControllerProvider.overrideWithValue(
              _planningController(repo, commands),
            ),
            pantryRepositoryProvider.overrideWithValue(
              _FakePantryRepository([]),
            ),
            purchaseHistoryRepositoryProvider.overrideWithValue(
              _FakePurchaseHistoryRepository(),
            ),
            wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
            calendarRepositoryProvider.overrideWithValue(
              _FakeCalendarRepository([]),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(KsChecklistRow).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record substitution'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(KsSearchField), 'pep');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pepper'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('substitution-quantity-field')),
        '3',
      );
      await tester.tap(find.text('Save substitution'));
      await tester.pumpAndSettle();

      final request = commands.mutationRequests.single;
      expect(request.householdId, 'solo-household');
      expect(request.listId, 'persisted-shop');
      expect(request.itemId, 'item-beans');
      expect(request.commandId, 'mutation-command-1');
      expect(request.expectedRevision, 0);
      final mutation = request.mutation as SetShoppingListItemStatusMutation;
      expect(mutation.status, ShoppingListItemStatus.substituted);
      expect(mutation.purchasedQuantity, isNull);
      expect(mutation.substituteIngredientId, 'pepper');
      expect(mutation.substituteQuantity, 3);
      expect(mutation.substituteUnit, UnitId.piece);
      expect(repo.lists.single.revision, 1);
      expect(
        repo.lists.single.items.first.status,
        ShoppingListItemStatus.substituted,
      );
      expect(find.textContaining('Pepper'), findsOneWidget);
    },
  );

  testWidgets('records substitution with local informal unit', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);
    final router = _shoppingListRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([_ingredientWithLocalUnit()]),
          ),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(KsChecklistRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record substitution'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(KsSearchField), 'pep');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pepper'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('substitution-unit-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bundle').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('substitution-quantity-field')),
      '3',
    );
    await tester.tap(find.text('Save substitution'));
    await tester.pumpAndSettle();

    final request = commands.mutationRequests.single;
    expect(request.householdId, 'solo-household');
    expect(request.listId, 'persisted-shop');
    expect(request.itemId, 'item-beans');
    expect(request.commandId, 'mutation-command-1');
    expect(request.expectedRevision, 0);
    final mutation = request.mutation as SetShoppingListItemStatusMutation;
    expect(mutation.status, ShoppingListItemStatus.substituted);
    expect(mutation.purchasedQuantity, isNull);
    expect(mutation.substituteIngredientId, 'pepper');
    expect(mutation.substituteQuantity, 3);
    expect(mutation.substituteUnit, UnitId('bundle'));
    expect(repo.lists.single.revision, 1);
    expect(find.textContaining('Pepper'), findsOneWidget);
    expect(find.textContaining('3 Bundles'), findsOneWidget);
  });

  testWidgets('requires valid substitution quantity and unit', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(repo);
    addTearDown(repo.dispose);
    final router = _shoppingListRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          activeHouseholdIdProvider.overrideWithValue('solo-household'),
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([_ingredientWithLocalUnit()]),
          ),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingPlanningControllerProvider.overrideWithValue(
            _planningController(repo, commands),
          ),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(KsChecklistRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record substitution'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(KsSearchField), 'pep');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pepper'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('substitution-quantity-field')),
      '0',
    );
    await tester.tap(find.text('Save substitution'));
    await tester.pumpAndSettle();

    expect(commands.mutationRequests, isEmpty);
    expect(repo.lists.single.revision, 0);
    expect(find.text('Record substitution'), findsOneWidget);
  });

  testWidgets('ShoppingListScreen completes through trusted callable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final commands = _FakeShoppingCommandRepository(
      repo,
      completeResponses: [
        (request) async => ShoppingCommandResult(
          listId: request.listId,
          status: ShoppingCommandStatus.completed,
          alreadyApplied: true,
          completionId: request.commandId,
        ),
      ],
    );
    addTearDown(repo.dispose);
    final router = GoRouter(
      initialLocation: '/list/persisted-shop',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Done')),
          routes: [
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
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingCommandRepositoryProvider.overrideWithValue(commands),
          idGeneratorProvider.overrideWithValue(
            FakeIdGenerator(['complete-command-1']),
          ),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish anyway'));
    await tester.pumpAndSettle();

    expect(commands.requests.single.householdId, 'solo-household');
    expect(commands.requests.single.listId, 'persisted-shop');
    expect(commands.requests.single.commandId, 'complete-command-1');
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('ShoppingListScreen disables duplicate completion and retries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeShoppingRepository([_record()]);
    final first = Completer<ShoppingCommandResult>();
    final commands = _FakeShoppingCommandRepository(
      repo,
      completeResponses: [
        (_) => first.future,
        (request) async => ShoppingCommandResult(
          listId: request.listId,
          status: ShoppingCommandStatus.completed,
          alreadyApplied: true,
          completionId: request.commandId,
        ),
      ],
    );
    addTearDown(repo.dispose);
    final router = GoRouter(
      initialLocation: '/list/persisted-shop',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Done')),
          routes: [
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
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingCommandRepositoryProvider.overrideWithValue(commands),
          idGeneratorProvider.overrideWithValue(
            FakeIdGenerator(['complete-command-1']),
          ),
          pantryRepositoryProvider.overrideWithValue(_FakePantryRepository([])),
          purchaseHistoryRepositoryProvider.overrideWithValue(
            _FakePurchaseHistoryRepository(),
          ),
          wasteRepositoryProvider.overrideWithValue(_FakeWasteRepository()),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository([]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(FilledButton);
    final enabledButton = tester.widget<FilledButton>(buttonFinder);
    final enabledTheme = Theme.of(tester.element(buttonFinder));
    final enabledThemeStyle = enabledTheme.filledButtonTheme.style!;
    expect(enabledButton.style, isNull);
    expect(
      enabledThemeStyle.backgroundColor?.resolve(const <WidgetState>{}),
      enabledTheme.colorScheme.primary,
    );
    expect(
      enabledThemeStyle.foregroundColor?.resolve(const <WidgetState>{}),
      enabledTheme.colorScheme.onPrimary,
    );
    final enabledRect = tester.getRect(buttonFinder);

    await tester.tap(find.text('Done shopping'));
    await tester.pump();
    await tester.tap(find.text('Finish anyway'));
    await tester.pump();
    expect(find.text('Finishing shop...'), findsOneWidget);
    final pendingButton = tester.widget<FilledButton>(buttonFinder);
    expect(pendingButton.onPressed, isNull);
    expect(tester.getRect(buttonFinder), enabledRect);
    final pendingStates = <WidgetState>{WidgetState.disabled};
    final pendingForeground = pendingButton.style?.foregroundColor?.resolve(
      pendingStates,
    );
    final pendingBackground = pendingButton.style?.backgroundColor?.resolve(
      pendingStates,
    );
    expect(pendingForeground, isNotNull);
    expect(pendingBackground, isNotNull);
    expect(
      contrastRatio(pendingForeground!, pendingBackground!),
      greaterThanOrEqualTo(4.5),
    );
    await tester.tap(find.text('Finishing shop...'));
    expect(commands.callCount, 1);

    first.completeError(
      const ShoppingCommandFailure(ShoppingCommandFailureKind.unavailable),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The shopping service is temporarily unavailable. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Done shopping'), findsOneWidget);
    expect(find.text('Done'), findsNothing);

    await tester.tap(find.text('Done shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish anyway'));
    await tester.pumpAndSettle();

    expect(commands.requests, hasLength(2));
    expect(commands.requests[0].commandId, 'complete-command-1');
    expect(commands.requests[1].commandId, 'complete-command-1');
    expect(find.text('Done'), findsOneWidget);
  });

  for (final failure in <(ShoppingCommandFailureKind, String)>[
    (
      ShoppingCommandFailureKind.permissionDenied,
      'You do not have permission to update this shopping list.',
    ),
    (
      ShoppingCommandFailureKind.resourceExhausted,
      'This shopping list is too large to finish at once.',
    ),
  ]) {
    testWidgets('ShoppingListScreen keeps list open for ${failure.$1.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeShoppingRepository([_record()]);
      final commands = _FakeShoppingCommandRepository(
        repo,
        completeResponses: [
          (_) => Future.error(ShoppingCommandFailure(failure.$1)),
        ],
      );
      addTearDown(repo.dispose);
      final router = GoRouter(
        initialLocation: '/list/persisted-shop',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Done')),
            routes: [
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
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
            activeHouseholdIdProvider.overrideWithValue('solo-household'),
            shoppingRepositoryProvider.overrideWithValue(repo),
            shoppingCommandRepositoryProvider.overrideWithValue(commands),
            idGeneratorProvider.overrideWithValue(
              FakeIdGenerator(['complete-command-1']),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done shopping'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish anyway'));
      await tester.pumpAndSettle();

      expect(find.text(failure.$2), findsOneWidget);
      expect(find.text('Done shopping'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });
  }
}
