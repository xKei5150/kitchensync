// SIZE_OK: menu set screen tests retain existing full UI scenario coverage.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';
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
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
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
      recipeRepositoryProvider.overrideWithValue(
        recipeRepository ?? _FakeRecipeRepository(),
      ),
      pantryRepositoryProvider.overrideWithValue(
        pantryRepository ?? _FakePantryRepository(),
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

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository({List<MealScheduleEntry>? meals})
    : meals = meals ?? const [];

  final List<MealScheduleEntry> meals;
  final upserted = <MealScheduleEntry>[];
  final deleted = <String>[];

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
  }) async {
    deleted.add(entryId);
  }

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => const Stream.empty();

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

class _FakeShoppingRepository implements ShoppingRepository {
  final upserted = <ShoppingListRecord>[];

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.value(upserted);

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(_findList(listId));

  @override
  Future<void> upsertList(ShoppingListRecord list) async {
    upserted.add(list);
  }

  @override
  Future<void> updateItemStatus({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingListItemStatus status,
    String? substituteIngredientId,
    double? substituteQuantity,
    UnitId? substituteUnit,
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

  ShoppingListRecord? _findList(String listId) {
    for (final list in upserted) {
      if (list.id == listId) return list;
    }
    return null;
  }
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
    expect(find.text('Save this week as a set'), findsOneWidget);
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
      await tester.pumpWidget(
        await _wrap(
          const MenuSetsScreen(),
          menuSetRepository: menuSets,
          calendarRepository: calendarRepo,
          shoppingRepository: shoppingRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply to calendar'));
      await tester.pumpAndSettle();

      expect(calendarRepo.upserted, isNotEmpty);
      expect(calendarRepo.upserted.first.recipeId, 'braise');
      expect(shoppingRepo.upserted.single.type, ShoppingListType.scheduled);
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

    expect(menuSets.upserted, hasLength(1));
    final saved = menuSets.upserted.single;
    expect(saved.name, 'Last week');
    expect(saved.lengthInDays, 7);
    expect(saved.createdByUserId, 'demo-user');
    final recipeIds = [
      for (final day in saved.days)
        for (final entry in day.entries) entry.recipeId,
    ];
    expect(recipeIds, contains('braise'));
    expect(recipeIds, isNot(contains('soup')));
    expect(find.text('Created a menu set from last week.'), findsOneWidget);
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
    addTearDown(menuSets.dispose);

    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(),
        menuSetRepository: menuSets,
        calendarRepository: calendarRepo,
        shoppingRepository: shoppingRepo,
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
    expect(find.text('Apply · 28 meals'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Apply · 28 meals'));
    await tester.pumpAndSettle();

    expect(calendarRepo.upserted, isNotEmpty);
    expect(shoppingRepo.upserted.single.type, ShoppingListType.scheduled);
    expect(shoppingRepo.upserted.single.items, isNotEmpty);
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
