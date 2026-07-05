import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/planning_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_set_editor_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_sets_screen.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(
  Widget home, {
  ThemeData? theme,
  CalendarRepository? calendarRepository,
  MenuSetRepository? menuSetRepository,
  ShoppingRepository? shoppingRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (calendarRepository != null)
        calendarRepositoryProvider.overrideWithValue(calendarRepository),
      if (menuSetRepository != null)
        menuSetRepositoryProvider.overrideWithValue(menuSetRepository),
      if (shoppingRepository != null)
        shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
    ],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: home),
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

  @override
  Stream<List<MenuSet>> watchHouseholdMenuSets(String householdId) =>
      Stream.value(upserted);

  @override
  Stream<MenuSet?> watchById({
    required String householdId,
    required String menuSetId,
  }) => Stream.value(_find(menuSetId));

  @override
  Future<void> upsert(MenuSet menuSet) async {
    upserted.add(menuSet);
  }

  @override
  Future<void> delete({
    required String householdId,
    required String menuSetId,
  }) async {
    deleted.add(menuSetId);
  }

  MenuSet? _find(String id) {
    for (final set in upserted) {
      if (set.id == id) return set;
    }
    return null;
  }
}

void main() {
  testWidgets('MenuSetsScreen shows the premium deck and save CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const MenuSetsScreen()));

    expect(find.text('A deck of weeks'), findsOneWidget);
    expect(find.text('Cosy autumn week'), findsOneWidget);
    expect(find.byType(KsMenuSetCard), findsWidgets);
    expect(find.text('Save this week as a set'), findsOneWidget);
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

    await tester.pumpWidget(
      await _wrap(
        const MenuSetEditorScreen(),
        calendarRepository: calendarRepo,
        shoppingRepository: shoppingRepo,
      ),
    );

    expect(find.byType(KsMenuSlotEditor), findsOneWidget);
    expect(find.text('Drop here'), findsOneWidget);

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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MenuSetEditorScreen)),
    );
    await tester.tap(find.text('Apply · 28 meals'));
    await tester.pumpAndSettle();

    final planning = container.read(planningControllerProvider);
    expect(planning.lastMenuSetApplication, isNotNull);
    expect(planning.activeShoppingList, isNotNull);
    expect(planning.schedule.length, greaterThan(1));
    expect(calendarRepo.upserted, isNotEmpty);
    expect(calendarRepo.deleted, contains('existing-dinner'));
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
    expect(menuSets.upserted.single.name, 'Cosy autumn week');
    expect(menuSets.upserted.single.days, hasLength(7));

    await tester.tap(find.text('Orzo'));
    await tester.pumpAndSettle();
    final added = menuSets.upserted.last.dayAt(2)!.entries;
    expect(added.map((entry) => entry.recipeId), contains('orzo'));

    await tester.tap(find.text('Remove Lentil dal'));
    await tester.pumpAndSettle();
    final remainingIds = [
      for (final day in menuSets.upserted.last.days)
        for (final entry in day.entries) entry.id,
    ];
    expect(remainingIds, isNot(contains('menu-entry-0')));
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
