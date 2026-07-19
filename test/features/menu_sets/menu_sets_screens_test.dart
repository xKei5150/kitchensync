// SIZE_OK: menu set screen tests retain existing full UI scenario coverage.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_set_editor_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_sets_screen.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(
  Widget home, {
  ThemeData? theme,
  ActiveHouseholdContext activeHousehold = _activeHousehold,
  CalendarRepository? calendarRepository,
  MenuSetRepository? menuSetRepository,
  ShoppingRepository? shoppingRepository,
  RecipeRepository? recipeRepository,
  PantryRepository? pantryRepository,
  ShoppingScheduleRepository? shoppingScheduleRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      activeHouseholdContextProvider.overrideWithValue(activeHousehold),
      if (calendarRepository != null)
        calendarRepositoryProvider.overrideWithValue(calendarRepository),
      if (menuSetRepository != null)
        menuSetRepositoryProvider.overrideWithValue(menuSetRepository),
      if (shoppingRepository != null)
        shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
      if (shoppingRepository is _FakeShoppingRepository)
        shoppingCommandRepositoryProvider.overrideWithValue(
          shoppingRepository.commands,
        ),
      if (shoppingRepository is _FakeShoppingRepository)
        shoppingAllocationCommandRepositoryProvider.overrideWithValue(
          shoppingRepository.commands,
        ),
      recipeRepositoryProvider.overrideWithValue(
        recipeRepository ?? _FakeRecipeRepository(),
      ),
      pantryRepositoryProvider.overrideWithValue(
        pantryRepository ?? _FakePantryRepository(),
      ),
      shoppingScheduleRepositoryProvider.overrideWithValue(
        shoppingScheduleRepository ?? const _FakeShoppingScheduleRepository(),
      ),
    ],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: home),
  );
}

class _FakeRecipeRepository implements RecipeRepository {
  _FakeRecipeRepository({Map<String, Recipe>? recipes})
    : recipes = recipes ?? {'braise': _recipe('braise')};

  final Map<String, Recipe> recipes;

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value(recipes.values.toList(growable: false));

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
  }) async => recipes.values.take(limit).toList(growable: false);

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

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository();

  final List<PantryItem> items = const [];

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

class _FakeCalendarRepository
    implements CalendarRepository, CalendarMealBatchRepository {
  _FakeCalendarRepository({
    List<MealScheduleEntry>? meals,
    List<CalendarDaySettings>? settings,
  }) : meals = [...?meals],
       settings = [...?settings];

  final List<MealScheduleEntry> meals;
  final List<CalendarDaySettings> settings;
  final upserted = <MealScheduleEntry>[];
  final deleted = <String>[];
  int replacementCalls = 0;

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
    upserted.add(entry);
  }

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {
    deleted.add(entryId);
  }

  @override
  Future<void> replaceMeals({
    required String householdId,
    required Iterable<String> removedEntryIds,
    required Iterable<MealScheduleEntry> createdEntries,
  }) async {
    replacementCalls++;
    deleted.addAll(removedEntryIds);
    upserted.addAll(createdEntries);
  }

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.value(List.unmodifiable(settings));

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

class _FakeShoppingScheduleRepository implements ShoppingScheduleRepository {
  const _FakeShoppingScheduleRepository([this.schedule]);

  final ShoppingSchedule? schedule;

  @override
  Future<void> save(ShoppingSchedule schedule) async {}

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(schedule);
}

class _FakeShoppingRepository extends ShoppingRepository {
  _FakeShoppingRepository([
    Iterable<ShoppingListRecord> initialLists = const [],
  ]) : upserted = [...initialLists] {
    commands = _FakeShoppingCommandRepository(this);
  }

  final List<ShoppingListRecord> upserted;
  late final _FakeShoppingCommandRepository commands;

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.value(
        List.unmodifiable(
          upserted.where((list) => list.householdId == householdId),
        ),
      );

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(_findList(householdId: householdId, listId: listId));

  void store(ShoppingListRecord list) {
    upserted
      ..removeWhere((existing) => existing.id == list.id)
      ..add(list);
  }

  ShoppingListRecord? _findList({
    required String householdId,
    required String listId,
  }) {
    for (final list in upserted) {
      if (list.householdId == householdId && list.id == listId) return list;
    }
    return null;
  }
}

class _FakeShoppingCommandRepository
    implements ShoppingAllocationCommandRepository {
  _FakeShoppingCommandRepository(this.shopping);

  final _FakeShoppingRepository shopping;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    final intent = command.intent;
    final (listId, type, shoppingDate) = switch (intent) {
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
        id: listId,
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
            id: 'server-item-$listId',
            shoppingListId: listId,
            ingredientId: 'server-ingredient',
            quantityNeeded: 1,
            unit: UnitId.piece,
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: const [],
          ),
        ],
      ),
    );
    return ShoppingCommandResult(
      listId: listId,
      status: ShoppingCommandStatus.pending,
      alreadyApplied: false,
      revision: 0,
    );
  }

  @override
  Future<ShoppingCommandResult> upsertList(
    ShoppingListUpsertCommand command,
  ) async {
    final existing = shopping._findList(
      householdId: command.householdId,
      listId: command.listId,
    );
    final nextRevision = switch ((existing, command.expectedRevision)) {
      (null, null) => 0,
      (final list?, final expected?) when list.revision == expected =>
        expected + 1,
      _ => throw const ShoppingCommandFailure(
        ShoppingCommandFailureKind.conflict,
      ),
    };
    final stored = _recordWithRevision(command.list, nextRevision);
    shopping.store(stored);
    return ShoppingCommandResult(
      listId: command.listId,
      status: _shoppingCommandStatus(stored.status),
      alreadyApplied: false,
      revision: nextRevision,
    );
  }

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) => throw UnimplementedError();

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      throw UnimplementedError();

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) =>
      throw UnimplementedError();
}

ShoppingCommandStatus _shoppingCommandStatus(ShoppingListStatus status) =>
    switch (status) {
      ShoppingListStatus.pending => ShoppingCommandStatus.pending,
      ShoppingListStatus.cancelled => ShoppingCommandStatus.cancelled,
      ShoppingListStatus.completed => ShoppingCommandStatus.completed,
    };

ShoppingListRecord _recordWithRevision(ShoppingListRecord list, int revision) =>
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

class _FakeCommandIdGenerator implements IdGenerator {
  var _next = 0;

  @override
  String newId() => 'shopping-command-${++_next}';
}

class _FakeMenuSetRepository implements MenuSetRepository {
  final upserted = <MenuSet>[];
  final deleted = <String>[];
  final _controller = StreamController<List<MenuSet>>.broadcast();

  void dispose() => _controller.close();

  @override
  Stream<List<MenuSet>> watchHouseholdMenuSets(String householdId) async* {
    yield List<MenuSet>.unmodifiable(upserted);
    yield* _controller.stream;
  }

  @override
  Stream<MenuSet?> watchById({
    required String householdId,
    required String menuSetId,
  }) => Stream.value(_find(menuSetId));

  @override
  Future<void> upsert(MenuSet menuSet) async {
    upserted
      ..removeWhere((current) => current.id == menuSet.id)
      ..add(menuSet);
    _controller.add(List<MenuSet>.unmodifiable(upserted));
  }

  @override
  Future<void> delete({
    required String householdId,
    required String menuSetId,
  }) async {
    deleted.add(menuSetId);
    upserted.removeWhere((current) => current.id == menuSetId);
    _controller.add(List<MenuSet>.unmodifiable(upserted));
  }

  MenuSet? _find(String id) {
    for (final set in upserted) {
      if (set.id == id) return set;
    }
    return null;
  }
}

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

const _memberHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.member,
  isJoint: true,
  hasPremium: true,
);

const _cookHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.cook,
  isJoint: true,
  hasPremium: true,
);

MenuSetDay _dayWithEntry(
  String dayId,
  int dayIndex,
  String entryId,
  String recipeId,
) => MenuSetDay(
  id: dayId,
  menuSetId: 'scoped-set',
  dayIndex: dayIndex,
  label: 'Day ${dayIndex + 1}',
  entries: [
    MenuSetEntry(
      id: entryId,
      menuSetDayId: dayId,
      mealSlot: 'Dinner',
      recipeId: recipeId,
      orderInSlot: 0,
    ),
  ],
);

MenuSet _menuSet() {
  return const MenuSet(
    id: 'set-1',
    householdId: 'solo-household',
    name: 'Persisted week',
    lengthInDays: 7,
    days: [
      MenuSetDay(
        id: 'day-1',
        menuSetId: 'set-1',
        dayIndex: 0,
        label: 'Day 1',
        entries: [
          MenuSetEntry(
            id: 'entry-1',
            menuSetDayId: 'day-1',
            mealSlot: 'Dinner',
            recipeId: 'braise',
            orderInSlot: 0,
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('Admin 21-day Saturday apply creates three deterministic lists and '
      'preserves history', () async {
    final completed = ShoppingListRecord(
      id: 'scheduled_weekly_20260711',
      householdId: 'solo-household',
      type: ShoppingListType.scheduled,
      shoppingDate: DateTime(2026, 7, 11),
      generatedForRangeStart: DateTime(2026, 7, 5),
      generatedForRangeEnd: DateTime(2026, 7, 11),
      status: ShoppingListStatus.completed,
      createdAt: DateTime(2026, 7, 11, 8),
      updatedAt: DateTime(2026, 7, 11, 20),
      items: const [],
    );
    final calendar = _FakeCalendarRepository();
    final shopping = _FakeShoppingRepository([completed]);
    final schedule = ShoppingSchedule(
      householdId: 'solo-household',
      cadence: ShoppingScheduleCadence.weekly,
      isoWeekday: DateTime.saturday,
      effectiveFrom: DateTime(2026, 7, 6),
      isActive: true,
      createdAt: DateTime(2026, 7, 6),
      updatedAt: DateTime(2026, 7, 6),
      updatedByUserId: 'user-1',
    );
    final controller = MenuSetApplyPersistenceController(
      calendarRepository: calendar,
      shoppingRepository: shopping,
      writeCoordinator: ShoppingWriteCoordinator(
        repository: shopping.commands,
        householdId: 'solo-household',
        idGenerator: _FakeCommandIdGenerator(),
      ),
      recipeRepository: _FakeRecipeRepository(),
      pantryRepository: _FakePantryRepository(),
      shoppingScheduleRepository: _FakeShoppingScheduleRepository(schedule),
      householdId: 'solo-household',
      household: _activeHousehold,
      idGenerator: FakeIdGenerator([
        for (var index = 0; index < 6; index++) 'meal-$index',
      ]),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );

    await controller.applyPersistedMenuSet(
      menuSet: _menuSet(),
      startDate: DateTime(2026, 7, 5),
      endDate: DateTime(2026, 7, 25),
      mode: MenuSetApplyMode.fillEmpty,
    );
    await controller.applyPersistedMenuSet(
      menuSet: _menuSet(),
      startDate: DateTime(2026, 7, 5),
      endDate: DateTime(2026, 7, 25),
      mode: MenuSetApplyMode.fillEmpty,
    );

    expect(shopping.upserted.map((list) => list.id).toSet(), {
      'scheduled_weekly_20260711',
      'scheduled_weekly_20260718',
      'scheduled_weekly_20260725',
    });
    expect(shopping.upserted, hasLength(3));
    final preserved = shopping.upserted.singleWhere(
      (list) => list.id == completed.id,
    );
    expect(preserved.status, ShoppingListStatus.completed);
    expect(preserved.updatedAt, completed.updatedAt);
    expect(preserved.items, same(completed.items));
  });

  test('Menu-set apply uses persisted calendar serving defaults', () async {
    final calendar = _FakeCalendarRepository(
      settings: [
        CalendarDaySettings(
          id: 'eight-servings',
          householdId: 'solo-household',
          dateRangeStart: DateTime(2026, 7, 6),
          dateRangeEnd: DateTime(2026, 7, 12),
          defaultServingSize: 8,
          mealsPerDay: 3,
          dishesPerMeal: 1,
          mealModeName: 'Family week',
          isActive: true,
        ),
      ],
    );
    final shopping = _FakeShoppingRepository();
    final controller = MenuSetApplyPersistenceController(
      calendarRepository: calendar,
      shoppingRepository: shopping,
      writeCoordinator: ShoppingWriteCoordinator(
        repository: shopping.commands,
        householdId: 'solo-household',
        idGenerator: _FakeCommandIdGenerator(),
      ),
      recipeRepository: _FakeRecipeRepository(),
      pantryRepository: _FakePantryRepository(),
      shoppingScheduleRepository: const _FakeShoppingScheduleRepository(),
      householdId: 'solo-household',
      household: _activeHousehold,
      idGenerator: FakeIdGenerator(['meal-with-default']),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );

    await controller.applyPersistedMenuSet(
      menuSet: _menuSet(),
      startDate: DateTime(2026, 7, 6),
      endDate: DateTime(2026, 7, 12),
      mode: MenuSetApplyMode.fillEmpty,
    );

    expect(calendar.upserted.single.servingSize, 8);
  });

  test('scratch-created menu sets persist their author identity', () async {
    final menuSets = _FakeMenuSetRepository();
    final controller = MenuSetEditorController(
      calendarRepository: _FakeCalendarRepository(),
      menuSetRepository: menuSets,
      householdId: 'solo-household',
      household: _activeHousehold,
      userId: 'author-1',
      idGenerator: FakeIdGenerator([
        'set-authored',
        for (var index = 0; index < 7; index++) 'day-$index',
      ]),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );

    final saved = await controller.saveDraft();

    expect(saved.createdByUserId, 'author-1');
    expect(menuSets.upserted.single.createdByUserId, 'author-1');
  });

  test('scratch-created menu sets use the requested name and length', () async {
    final menuSets = _FakeMenuSetRepository();
    final controller = MenuSetEditorController(
      calendarRepository: _FakeCalendarRepository(),
      menuSetRepository: menuSets,
      householdId: 'solo-household',
      household: _activeHousehold,
      userId: 'author-1',
      idGenerator: FakeIdGenerator([
        'set-custom',
        for (var index = 0; index < 3; index++) 'custom-day-$index',
      ]),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );

    final saved = await controller.saveDraft(
      name: '  Workweek light  ',
      lengthInDays: 3,
    );

    expect(saved.name, 'Workweek light');
    expect(saved.lengthInDays, 3);
    expect(saved.days, hasLength(3));
    expect(saved.days.map((day) => day.label), ['Day 1', 'Day 2', 'Day 3']);
  });

  test('menu set editor supports day and entry structure mutations', () async {
    final menuSets = _FakeMenuSetRepository();
    final controller = MenuSetEditorController(
      calendarRepository: _FakeCalendarRepository(),
      menuSetRepository: menuSets,
      householdId: 'solo-household',
      household: _activeHousehold,
      userId: 'author-1',
      idGenerator: FakeIdGenerator(['duplicated-day', 'duplicated-entry']),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );
    const secondEntry = MenuSetEntry(
      id: 'second-entry',
      menuSetDayId: 'set-1-day-0',
      mealSlot: 'Dinner',
      recipeId: 'soup',
      orderInSlot: 1,
    );
    final draft = MenuSet(
      id: 'set-1',
      householdId: 'solo-household',
      name: 'Structure test',
      lengthInDays: 2,
      days: [
        MenuSetDay(
          id: 'set-1-day-0',
          menuSetId: 'set-1',
          dayIndex: 0,
          label: 'Day 1',
          entries: [..._menuSet().days.first.entries, secondEntry],
        ),
        const MenuSetDay(
          id: 'set-1-day-1',
          menuSetId: 'set-1',
          dayIndex: 1,
          label: 'Day 2',
          entries: [],
        ),
      ],
    );

    final renamed = await controller.renameDay(
      draft: draft,
      dayIndex: 0,
      label: 'Workout day',
    );
    expect(renamed.dayAt(0)!.label, 'Workout day');

    final moved = await controller.moveEntry(
      draft: renamed,
      sourceDayId: renamed.dayAt(0)!.id,
      entryId: renamed.dayAt(0)!.entries.first.id,
      targetDayIndex: 1,
      targetMealSlot: 'Lunch',
      targetOrder: 0,
    );
    expect(moved.dayAt(0)!.entries, hasLength(1));
    expect(moved.dayAt(1)!.entries.single.mealSlot, 'Lunch');
    expect(moved.dayAt(1)!.entries.single.orderInSlot, 0);

    final duplicated = await controller.duplicateDay(draft: moved, dayIndex: 1);
    expect(duplicated.lengthInDays, 3);
    expect(duplicated.days, hasLength(3));
    expect(duplicated.dayAt(2)!.entries.single.id, 'duplicated-entry');

    final cleared = await controller.clearDay(draft: duplicated, dayIndex: 2);
    expect(cleared.dayAt(2)!.entries, isEmpty);
  });

  test('move entry uses day-scoped entry identity', () async {
    final menuSets = _FakeMenuSetRepository();
    final controller = MenuSetEditorController(
      calendarRepository: _FakeCalendarRepository(),
      menuSetRepository: menuSets,
      householdId: 'solo-household',
      household: _activeHousehold,
      userId: 'author-1',
      idGenerator: FakeIdGenerator([]),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );
    const sharedEntryId = 'day-scoped-entry';
    final draft = MenuSet(
      id: 'scoped-set',
      householdId: 'solo-household',
      name: 'Scoped entries',
      lengthInDays: 2,
      days: [
        _dayWithEntry('source-day', 0, sharedEntryId, 'source-recipe'),
        _dayWithEntry('other-day', 1, sharedEntryId, 'other-recipe'),
      ],
    );

    final moved = await controller.moveEntry(
      draft: draft,
      sourceDayId: 'source-day',
      entryId: sharedEntryId,
      targetDayIndex: 1,
      targetMealSlot: 'Lunch',
      targetOrder: 1,
    );

    expect(moved.dayAt(0)!.entries, isEmpty);
    expect(moved.dayAt(1)!.entries, hasLength(2));
    expect(moved.dayAt(1)!.entries.first.recipeId, 'other-recipe');
    expect(moved.dayAt(1)!.entries.last.recipeId, 'source-recipe');
  });

  test('duplicate day preserves sparse cycle and Rules field limits', () async {
    final menuSets = _FakeMenuSetRepository();
    final controller = MenuSetEditorController(
      calendarRepository: _FakeCalendarRepository(),
      menuSetRepository: menuSets,
      householdId: 'solo-household',
      household: _activeHousehold,
      userId: 'author-1',
      idGenerator: FakeIdGenerator(['duplicate-day', 'duplicate-entry']),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );
    final longLabel = List.filled(80, 'A').join();
    final draft = MenuSet(
      id: 'sparse-set',
      householdId: 'solo-household',
      name: 'Sparse week',
      lengthInDays: 7,
      days: [
        MenuSetDay(
          id: 'day-0',
          menuSetId: 'sparse-set',
          dayIndex: 0,
          label: longLabel,
          entries: const [
            MenuSetEntry(
              id: 'entry-0',
              menuSetDayId: 'day-0',
              mealSlot: 'Dinner',
              recipeId: 'braise',
              orderInSlot: 0,
            ),
          ],
        ),
        const MenuSetDay(
          id: 'day-6',
          menuSetId: 'sparse-set',
          dayIndex: 6,
          label: 'Day 7',
          entries: [],
        ),
      ],
    );

    final duplicated = await controller.duplicateDay(draft: draft, dayIndex: 0);

    expect(duplicated.lengthInDays, 8);
    expect(duplicated.days.map((day) => day.dayIndex), [0, 1, 7]);
    expect(duplicated.dayAt(1)!.label, hasLength(80));
    expect(duplicated.dayAt(1)!.entries.single.id, 'duplicate-entry');
  });

  test(
    'menu set edits validate persisted field bounds before writing',
    () async {
      final menuSets = _FakeMenuSetRepository();
      final controller = MenuSetEditorController(
        calendarRepository: _FakeCalendarRepository(),
        menuSetRepository: menuSets,
        householdId: 'solo-household',
        household: _activeHousehold,
        userId: 'author-1',
        idGenerator: FakeIdGenerator([]),
        clock: FakeClock(DateTime(2026, 7, 6, 9)),
      );

      await expectLater(
        controller.saveDraft(description: List.filled(1001, 'x').join()),
        throwsArgumentError,
      );
      await expectLater(
        controller.moveEntry(
          draft: _menuSet(),
          sourceDayId: 'day-1',
          entryId: 'entry-1',
          targetDayIndex: 0,
          targetMealSlot: List.filled(81, 'x').join(),
          targetOrder: 0,
        ),
        throwsArgumentError,
      );
      expect(menuSets.upserted, isEmpty);
    },
  );

  test(
    'scratch-created menu sets defensively freeze supplied structure',
    () async {
      final menuSets = _FakeMenuSetRepository();
      final entries = <MenuSetEntry>[];
      final days = <MenuSetDay>[
        MenuSetDay(
          id: 'provided-day',
          menuSetId: 'provided-set',
          dayIndex: 0,
          entries: entries,
        ),
      ];
      final controller = MenuSetEditorController(
        calendarRepository: _FakeCalendarRepository(),
        menuSetRepository: menuSets,
        householdId: 'solo-household',
        household: _activeHousehold,
        userId: 'author-1',
        idGenerator: FakeIdGenerator(['provided-set']),
        clock: FakeClock(DateTime(2026, 7, 6, 9)),
      );

      final saved = await controller.saveDraft(name: 'Frozen', days: days);
      days.clear();
      entries.add(
        const MenuSetEntry(
          id: 'late-entry',
          menuSetDayId: 'provided-day',
          mealSlot: 'Dinner',
          recipeId: 'braise',
          orderInSlot: 0,
        ),
      );

      expect(saved.days, hasLength(1));
      expect(saved.days.single.entries, isEmpty);
      expect(() => saved.days.add(saved.days.single), throwsUnsupportedError);
      expect(
        () => saved.days.single.entries.add(entries.single),
        throwsUnsupportedError,
      );
    },
  );

  test('scratch-created menu sets reject invalid setup values', () async {
    final menuSets = _FakeMenuSetRepository();
    final controller = MenuSetEditorController(
      calendarRepository: _FakeCalendarRepository(),
      menuSetRepository: menuSets,
      householdId: 'solo-household',
      household: _activeHousehold,
      userId: 'author-1',
      idGenerator: FakeIdGenerator(['unused']),
      clock: FakeClock(DateTime(2026, 7, 6, 9)),
    );

    await expectLater(
      controller.saveDraft(name: '   ', lengthInDays: 3),
      throwsArgumentError,
    );
    await expectLater(
      controller.saveDraft(name: 'Valid', lengthInDays: 0),
      throwsArgumentError,
    );
    await expectLater(
      controller.saveDraft(name: 'Valid', lengthInDays: 366),
      throwsArgumentError,
    );
    expect(menuSets.upserted, isEmpty);
  });

  test(
    'Cook menu-set apply persists calendar with zero Shopping writes',
    () async {
      final calendar = _FakeCalendarRepository();
      final shopping = _FakeShoppingRepository();
      final controller = MenuSetApplyPersistenceController(
        calendarRepository: calendar,
        shoppingRepository: shopping,
        writeCoordinator: ShoppingWriteCoordinator(
          repository: shopping.commands,
          householdId: 'solo-household',
          idGenerator: _FakeCommandIdGenerator(),
        ),
        recipeRepository: _FakeRecipeRepository(),
        pantryRepository: _FakePantryRepository(),
        shoppingScheduleRepository: _FakeShoppingScheduleRepository(
          ShoppingSchedule(
            householdId: 'solo-household',
            cadence: ShoppingScheduleCadence.weekly,
            isoWeekday: DateTime.saturday,
            effectiveFrom: DateTime(2026, 7, 6),
            isActive: true,
            createdAt: DateTime(2026, 7, 6),
            updatedAt: DateTime(2026, 7, 6),
            updatedByUserId: 'user-1',
          ),
        ),
        householdId: 'solo-household',
        household: _cookHousehold,
        idGenerator: FakeIdGenerator(['cook-meal-1']),
        clock: FakeClock(DateTime(2026, 7, 6, 9)),
      );

      await expectLater(
        controller.applyPersistedMenuSet(
          menuSet: _menuSet(),
          startDate: DateTime(2026, 7, 6),
          endDate: DateTime(2026, 7, 12),
          mode: MenuSetApplyMode.fillEmpty,
        ),
        completes,
      );

      expect(calendar.upserted, hasLength(1));
      expect(calendar.upserted.single.recipeId, 'braise');
      expect(calendar.replacementCalls, 1);
      expect(shopping.upserted, isEmpty);
    },
  );

  testWidgets('MenuSetsScreen shows the premium deck and save CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuSets = _FakeMenuSetRepository()..upserted.add(_menuSet());
    await tester.pumpWidget(
      await _wrap(const MenuSetsScreen(), menuSetRepository: menuSets),
    );
    await tester.pumpAndSettle();

    expect(find.text('A deck of weeks'), findsOneWidget);
    expect(find.text('Persisted week'), findsOneWidget);
    expect(find.byType(KsMenuSetCard), findsOneWidget);
    expect(find.text('Create Menu Set'), findsOneWidget);
    expect(find.text('Save this week as a set'), findsOneWidget);
    expect(find.byTooltip('View or edit'), findsOneWidget);
  });

  testWidgets('MenuSetsScreen duplicates and deletes persisted sets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuSets = _FakeMenuSetRepository()..upserted.add(_menuSet());
    await tester.pumpWidget(
      await _wrap(const MenuSetsScreen(), menuSetRepository: menuSets),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(menuSets.upserted.last.name, 'Persisted week copy');
    expect(
      menuSets.upserted.last.days.single.entries.single.recipeId,
      'braise',
    );

    await tester.tap(find.text('Delete selected set'));
    await tester.pumpAndSettle();
    expect(menuSets.deleted, contains('set-1'));
  });

  testWidgets(
    'MenuSetsScreen applies persisted sets to calendar and shopping',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final menuSets = _FakeMenuSetRepository()..upserted.add(_menuSet());
      final calendarRepo = _FakeCalendarRepository();
      final shoppingRepo = _FakeShoppingRepository();
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
      await tester.pumpWidget(
        await _wrap(
          const MenuSetsScreen(),
          menuSetRepository: menuSets,
          calendarRepository: calendarRepo,
          shoppingRepository: shoppingRepo,
          shoppingScheduleRepository: _FakeShoppingScheduleRepository(schedule),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply to calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Apply to the calendar'), findsOneWidget);
      expect(calendarRepo.upserted, isEmpty);
      await tester.tap(find.text('Replace'));
      await tester.tap(find.text('Apply · 4 meals'));
      await tester.pumpAndSettle();

      expect(calendarRepo.upserted, isNotEmpty);
      expect(calendarRepo.upserted.first.recipeId, 'braise');
      expect(
        shoppingRepo.upserted.where(
          (list) => list.type == ShoppingListType.scheduled,
        ),
        hasLength(4),
      );
      expect(
        find.text('Applied Persisted week to the calendar.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('MenuSetsScreen blocks persisted apply for read-only members', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuSets = _FakeMenuSetRepository()..upserted.add(_menuSet());
    final calendarRepo = _FakeCalendarRepository();
    final shoppingRepo = _FakeShoppingRepository();
    await tester.pumpWidget(
      await _wrap(
        const MenuSetsScreen(),
        activeHousehold: _memberHousehold,
        menuSetRepository: menuSets,
        calendarRepository: calendarRepo,
        shoppingRepository: shoppingRepo,
      ),
    );
    await tester.pumpAndSettle();

    final applyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply to calendar'),
    );
    expect(applyButton.onPressed, isNull);
    expect(calendarRepo.upserted, isEmpty);
    expect(shoppingRepo.upserted, isEmpty);
  });

  testWidgets('MenuSetsScreen creates a menu set from a past calendar range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final yesterday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    final calendarRepo = _FakeCalendarRepository(
      meals: [
        MealScheduleEntry(
          id: 'past-dinner',
          recipeId: 'braise',
          date: yesterday,
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
        MealScheduleEntry(
          id: 'cancelled-lunch',
          recipeId: 'soup',
          date: yesterday,
          mealLabel: 'Lunch',
          servingSize: 2,
          state: ScheduledMealState.cancelled,
        ),
      ],
    );
    final menuSets = _FakeMenuSetRepository();

    await tester.pumpWidget(
      await _wrap(
        const MenuSetsScreen(),
        calendarRepository: calendarRepo,
        menuSetRepository: menuSets,
      ),
    );

    await tester.tap(find.text('Save this week as a set'));
    await tester.pumpAndSettle();

    // The sheet opens with preset ranges, a name field, and a live review.
    expect(find.byKey(const Key('past-calendar-sheet')), findsOneWidget);
    expect(find.text('Last week'), findsWidgets);
    expect(find.text('This month'), findsWidgets);
    // Review reflects the normalized structure (cancelled meals excluded).
    expect(find.byKey(const Key('past-calendar-review')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('past-calendar-name-field')),
      'Promoted week',
    );
    await tester.tap(find.byKey(const Key('past-calendar-save')));
    await tester.pumpAndSettle();

    expect(menuSets.upserted, hasLength(1));
    final saved = menuSets.upserted.single;
    expect(saved.name, 'Promoted week');
    expect(saved.lengthInDays, 7);
    expect(saved.createdByUserId, 'demo-user');
    final recipeIds = [
      for (final day in saved.days)
        for (final entry in day.entries) entry.recipeId,
    ];
    expect(recipeIds, contains('braise'));
    expect(recipeIds, isNot(contains('soup')));
    expect(
      find.text('Created “Promoted week” — review and edit any day.'),
      findsOneWidget,
    );
  });

  testWidgets('MenuSet apply action stays reachable on a compact viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuSets = _FakeMenuSetRepository()..upserted.add(_menuSet());
    addTearDown(menuSets.dispose);
    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(menuSetId: 'set-1'),
        menuSetRepository: menuSets,
        calendarRepository: _FakeCalendarRepository(),
        shoppingRepository: _FakeShoppingRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final openApplyButton = find.widgetWithText(
      FilledButton,
      'Apply to calendar',
    );
    await tester.ensureVisible(openApplyButton);
    await tester.tap(openApplyButton);
    await tester.pumpAndSettle();

    expect(find.text('Apply · 4 meals').hitTestable(), findsOneWidget);
  });

  testWidgets('MenuSetEditorScreen selects the requested persisted set', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const requested = MenuSet(
      id: 'set-requested',
      householdId: 'solo-household',
      name: 'Requested rotation',
      lengthInDays: 3,
      days: [],
    );
    final menuSets = _FakeMenuSetRepository()
      ..upserted.add(_menuSet())
      ..upserted.add(requested);
    addTearDown(menuSets.dispose);
    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(menuSetId: 'set-requested'),
        menuSetRepository: menuSets,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Requested rotation'), findsOneWidget);
    expect(find.byKey(const Key('menu-set-name-field')), findsNothing);
  });

  testWidgets('MenuSetEditorScreen opens the Apply sheet and toggles mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calendarRepo = _FakeCalendarRepository();
    final shoppingRepo = _FakeShoppingRepository();
    final menuSets = _FakeMenuSetRepository()..upserted.add(_menuSet());
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
    addTearDown(menuSets.dispose);

    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(menuSetId: 'set-1'),
        menuSetRepository: menuSets,
        calendarRepository: calendarRepo,
        shoppingRepository: shoppingRepo,
        shoppingScheduleRepository: _FakeShoppingScheduleRepository(schedule),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KsMenuSlotEditor), findsOneWidget);
    expect(find.text('Braise'), findsWidgets);

    // The first "Apply to calendar" is the screen CTA; opening the sheet shows
    // the date range + mode toggle.
    await tester.tap(find.text('Apply to calendar').first);
    await tester.pumpAndSettle();

    expect(find.text('Apply to the calendar'), findsOneWidget);
    expect(find.text('Fill empty'), findsOneWidget);
    expect(find.text('Apply · 4 meals'), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-set-date-range-start')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Apply · 4 meals'));
    await tester.pumpAndSettle();

    expect(calendarRepo.upserted, isNotEmpty);
    expect(
      shoppingRepo.upserted.where(
        (list) => list.type == ShoppingListType.scheduled,
      ),
      hasLength(4),
    );
    expect(shoppingRepo.upserted.first.items, isNotEmpty);
  });

  testWidgets('MenuSetEditorScreen saves requested name and day count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuSets = _FakeMenuSetRepository();
    addTearDown(menuSets.dispose);
    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(),
        menuSetRepository: menuSets,
        calendarRepository: _FakeCalendarRepository(),
        shoppingRepository: _FakeShoppingRepository(),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('menu-set-name-field')),
      'Workweek light',
    );
    await tester.enterText(find.byKey(const Key('menu-set-length-field')), '3');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(menuSets.upserted.single.name, 'Workweek light');
    expect(menuSets.upserted.single.days, hasLength(3));
    expect(find.text('Workweek light'), findsOneWidget);
  });

  testWidgets('MenuSetEditorScreen persists save add and remove edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuSets = _FakeMenuSetRepository();
    addTearDown(menuSets.dispose);

    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(),
        menuSetRepository: menuSets,
        calendarRepository: _FakeCalendarRepository(),
        shoppingRepository: _FakeShoppingRepository(),
      ),
    );

    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(menuSets.upserted.single.name, 'New menu set');
    expect(menuSets.upserted.single.days, hasLength(7));

    await tester.tap(find.text('Braise'));
    await tester.pumpAndSettle();
    final added = menuSets.upserted.last.dayAt(2)!.entries;
    expect(added.map((entry) => entry.recipeId), contains('braise'));

    await tester.tap(find.text('Remove first recipe'));
    await tester.pumpAndSettle();
    final remainingIds = [
      for (final day in menuSets.upserted.last.days)
        for (final entry in day.entries) entry.id,
    ];
    expect(remainingIds, isEmpty);
  });

  testWidgets('MenuSetEditorScreen edits day structure via controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuSets = _FakeMenuSetRepository();
    addTearDown(menuSets.dispose);
    await menuSets.upsert(
      const MenuSet(
        id: 'editable-set',
        householdId: 'solo-household',
        name: 'Editable week',
        lengthInDays: 2,
        days: [
          MenuSetDay(
            id: 'edit-day-0',
            menuSetId: 'editable-set',
            dayIndex: 0,
            label: 'Day 1',
            entries: [
              MenuSetEntry(
                id: 'edit-entry-0',
                menuSetDayId: 'edit-day-0',
                mealSlot: 'Dinner',
                recipeId: 'braise',
                orderInSlot: 0,
              ),
            ],
          ),
          MenuSetDay(
            id: 'edit-day-1',
            menuSetId: 'editable-set',
            dayIndex: 1,
            label: 'Day 2',
            entries: [],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(menuSetId: 'editable-set'),
        menuSetRepository: menuSets,
        calendarRepository: _FakeCalendarRepository(),
        shoppingRepository: _FakeShoppingRepository(),
      ),
    );
    await tester.pumpAndSettle();

    // Move the only recipe from Day 1 to Day 2, preserving slot.
    await tester.tap(find.byKey(const Key('menu-set-move-day-0')));
    await tester.pumpAndSettle();
    var latest = menuSets.upserted.last;
    expect(latest.dayAt(0)!.entries, isEmpty);
    expect(latest.dayAt(1)!.entries.single.recipeId, 'braise');

    // Duplicate Day 2 (now holding the moved recipe).
    await tester.tap(find.byKey(const Key('menu-set-duplicate-day-1')));
    await tester.pumpAndSettle();
    latest = menuSets.upserted.last;
    expect(latest.days, hasLength(3));
    expect(latest.dayAt(2)!.entries.single.recipeId, 'braise');

    // Clear the duplicated day.
    await tester.tap(find.byKey(const Key('menu-set-clear-day-2')));
    await tester.pumpAndSettle();
    expect(menuSets.upserted.last.dayAt(2)!.entries, isEmpty);

    // Rename Day 1 through the dialog.
    await tester.tap(find.byKey(const Key('menu-set-rename-day-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('menu-set-rename-field')),
      'Rest day',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(menuSets.upserted.last.dayAt(0)!.label, 'Rest day');
  });

  testWidgets('Menu Sets screens render in dark theme without error', (
    tester,
  ) async {
    final calendarRepo = _FakeCalendarRepository();
    final shoppingRepo = _FakeShoppingRepository();
    await tester.pumpWidget(
      await _wrap(
        const MenuSetsScreen(),
        theme: AppTheme.dark(),
        calendarRepository: calendarRepo,
        shoppingRepository: shoppingRepo,
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(),
        theme: AppTheme.dark(),
        calendarRepository: calendarRepo,
        shoppingRepository: shoppingRepo,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
