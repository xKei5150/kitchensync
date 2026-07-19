// SIZE_OK: calendar screen tests cover existing multi-state UI workflows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository(
    this.meals, {
    List<CalendarDaySettings>? settings,
    this.settingsDelay = Duration.zero,
  }) : settings = settings ?? [];

  final List<MealScheduleEntry> meals;
  final List<CalendarDaySettings> settings;
  final Duration settingsDelay;
  final watchedRanges = <({DateTime start, DateTime end})>[];

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    watchedRanges.add((start: startDate, end: endDate));
    return Stream.value(
      meals
          .where(
            (meal) =>
                !meal.date.isBefore(startDate) && !meal.date.isAfter(endDate),
          )
          .toList(growable: false),
    );
  }

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
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(String householdId) {
    final active = settings
        .where((setting) => setting.householdId == householdId)
        .where((setting) => setting.isActive)
        .toList(growable: false);
    if (settingsDelay == Duration.zero) return Stream.value(active);
    return Stream.fromFuture(Future.delayed(settingsDelay, () => active));
  }

  @override
  Future<void> upsertDaySettings(CalendarDaySettings next) async {
    settings
      ..removeWhere((setting) => setting.id == next.id)
      ..add(next);
  }
}

class _FakeRecipeRepository implements RecipeRepository {
  const _FakeRecipeRepository(this.recipes);

  final List<Recipe> recipes;

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value(recipes);

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
  }) async {
    throw UnimplementedError();
  }
}

class _FakeWasteRepository implements WasteRepository {
  const _FakeWasteRepository(this.events);

  final List<WasteEvent> events;

  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) {
    return Stream.value(
      events
          .where((event) => event.householdId == householdId)
          .take(limit)
          .toList(growable: false),
    );
  }

  @override
  Future<void> log(WasteEvent event) async {}
}

Recipe _recipe() {
  final now = DateTime(2026, 7);
  return Recipe(
    id: 'persisted-recipe',
    authorUserId: 'user-1',
    householdId: 'solo-household',
    name: 'Persisted aubergine stew',
    description: '',
    defaultServingSize: 3,
    mealTimeTags: const ['Dinner'],
    recipeTags: const [],
    location: '',
    visibility: RecipeVisibility.private,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: const [
      RecipeIngredient(
        id: 'ingredient-1',
        recipeId: 'persisted-recipe',
        ingredientId: 'aubergine',
        quantity: 2,
        unit: UnitId.piece,
      ),
    ],
    instructions: const [],
  );
}

WasteEvent _wasteEvent({
  required String id,
  required String householdId,
  required DateTime date,
}) {
  return WasteEvent(
    id: id,
    householdId: householdId,
    pantryItemId: 'pantry-$id',
    ingredientId: 'aubergine',
    quantity: 1,
    unit: UnitId.piece,
    reason: WasteReason.spoiled,
    date: date,
  );
}

List<Override> _calendarOverrides({
  CalendarRepository? calendarRepository,
  RecipeRepository? recipeRepository,
  WasteRepository wasteRepository = const _FakeWasteRepository([]),
  List<PantryItem> pantryItems = const [],
  ShoppingSchedule? shoppingSchedule,
  List<ShoppingListRecord> shoppingLists = const [],
  Clock? clock,
}) {
  return [
    activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
    calendarRepositoryProvider.overrideWithValue(
      calendarRepository ?? _FakeCalendarRepository(const []),
    ),
    wasteRepositoryProvider.overrideWithValue(wasteRepository),
    recipeRepositoryProvider.overrideWithValue(
      recipeRepository ?? _FakeRecipeRepository([_recipe()]),
    ),
    pantryAllItemsStreamProvider.overrideWith(
      (ref) => Stream.value(pantryItems),
    ),
    activeShoppingScheduleProvider.overrideWith(
      (ref) => Stream.value(shoppingSchedule),
    ),
    activeShoppingListsProvider.overrideWith(
      (ref) => Stream.value(shoppingLists),
    ),
    clockProvider.overrideWithValue(
      clock ?? FakeClock(DateTime(2026, 7, 6, 9)),
    ),
  ];
}

void main() {
  testWidgets('CalendarScreen renders the month grid, legend and peek', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(
          calendarRepository: _FakeCalendarRepository([
            MealScheduleEntry(
              id: 'meal-1',
              recipeId: 'persisted-recipe',
              date: DateTime(2026, 7, 6),
              mealLabel: 'Dinner',
              servingSize: 3,
            ),
          ]),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalendarScreen(
              initialMonth: DateTime(2026, 7),
              initialSelectedDate: DateTime(2026, 7, 6),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.byType(KsAlmanacGrid), findsOneWidget);
    // The legend reads the four reserved statuses.
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    // The selected-day peek surfaces today's plan.
    expect(find.text('Persisted aubergine stew'), findsOneWidget);
    expect(find.text('Dinner · serves 3'), findsOneWidget);
  });

  testWidgets('CalendarScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const CalendarScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(KsAlmanacGrid), findsOneWidget);
  });

  testWidgets('CalendarScreen prefers persisted meals and recipes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calendarRepository = _FakeCalendarRepository([
      MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 3,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(calendarRepository: calendarRepository),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      calendarRepository.watchedRanges,
      contains((start: DateTime(2026, 7), end: DateTime(2026, 7, 31))),
    );
    expect(find.text('Persisted aubergine stew'), findsOneWidget);
    expect(find.text('Dinner · serves 3'), findsOneWidget);
    expect(find.text('Tomato & white bean braise'), findsNothing);
  });

  testWidgets('CalendarScreen navigates months and refreshes visible meals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calendarRepository = _FakeCalendarRepository([
      MealScheduleEntry(
        id: 'july-meal',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 3,
      ),
      MealScheduleEntry(
        id: 'august-meal',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 8, 6),
        mealLabel: 'Lunch',
        servingSize: 2,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(calendarRepository: calendarRepository),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('Dinner · serves 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();

    expect(find.text('August 2026'), findsOneWidget);
    expect(
      calendarRepository.watchedRanges,
      contains((start: DateTime(2026, 8), end: DateTime(2026, 8, 31))),
    );
    expect(find.text('Lunch · serves 2'), findsOneWidget);
    expect(find.text('Dinner · serves 3'), findsNothing);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(
      calendarRepository.watchedRanges,
      contains((start: DateTime(2026, 7), end: DateTime(2026, 7, 31))),
    );
    expect(find.text('Dinner · serves 3'), findsOneWidget);
  });

  testWidgets('CalendarScreen toggles to cross-month weeks and advances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calendarRepository = _FakeCalendarRepository([
      MealScheduleEntry(
        id: 'july-meal',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 7),
        mealLabel: 'Dinner',
        servingSize: 3,
      ),
      MealScheduleEntry(
        id: 'next-week-meal',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 7, 8),
        mealLabel: 'Lunch',
        servingSize: 2,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(calendarRepository: calendarRepository),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalendarScreen(initialSelectedDate: DateTime(2026, 7)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.text('29 June-5 July 2026'), findsOneWidget);
    expect(find.byTooltip('Next week'), findsOneWidget);
    expect(
      calendarRepository.watchedRanges,
      contains((start: DateTime(2026, 6, 29), end: DateTime(2026, 7, 5))),
    );
    final firstWeek = tester.widget<KsAlmanacGrid>(find.byType(KsAlmanacGrid));
    expect(
      firstWeek.days.map((day) => day.dayNumber),
      orderedEquals([29, 30, 1, 2, 3, 4, 5]),
    );
    expect(find.text('Dinner · serves 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();

    expect(find.text('6-12 July 2026'), findsOneWidget);
    expect(
      calendarRepository.watchedRanges,
      contains((start: DateTime(2026, 7, 6), end: DateTime(2026, 7, 12))),
    );
    expect(find.text('Lunch · serves 2'), findsOneWidget);
    expect(find.text('Dinner · serves 3'), findsNothing);
  });

  testWidgets('CalendarScreen marks household waste dates as problem days', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calendarRepository = _FakeCalendarRepository(const []);
    final wasteRepository = _FakeWasteRepository([
      _wasteEvent(
        id: 'active-waste',
        householdId: 'solo-household',
        date: DateTime(2026, 7, 9, 17),
      ),
      _wasteEvent(
        id: 'other-waste',
        householdId: 'other-household',
        date: DateTime(2026, 7, 10, 17),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(
          calendarRepository: calendarRepository,
          wasteRepository: wasteRepository,
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<KsAlmanacGrid>(find.byType(KsAlmanacGrid));
    final leadingPad = DateTime(2026, 7).weekday - DateTime.monday;

    expect(grid.days[leadingPad + 8].status, CalendarDayStatus.problem);
    expect(
      grid.days[leadingPad + 8].markers,
      contains(CalendarDayMarker.waste),
    );
    expect(grid.days[leadingPad + 9].status, CalendarDayStatus.problem);
    expect(grid.days[leadingPad + 9].markers, isEmpty);
  });

  testWidgets('CalendarScreen renders pantry and shopping status precedence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 7, 10, 9);
    final created = DateTime(2026, 7);
    final calendarRepository = _FakeCalendarRepository([
      MealScheduleEntry(
        id: 'covered-meal',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 3,
      ),
      MealScheduleEntry(
        id: 'depleted-meal',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 7, 7),
        mealLabel: 'Dinner',
        servingSize: 3,
      ),
    ]);
    final pantry = PantryItem(
      id: 'aubergine-stock',
      householdId: 'solo-household',
      ingredientId: 'aubergine',
      quantity: 3,
      unit: UnitId.piece,
      section: PantrySection.food,
      createdAt: created,
      updatedAt: created,
    );
    final shoppingSchedule = ShoppingSchedule(
      householdId: 'solo-household',
      cadence: ShoppingScheduleCadence.weekly,
      isoWeekday: DateTime.wednesday,
      effectiveFrom: DateTime(2026, 7),
      isActive: true,
      createdAt: created,
      updatedAt: created,
      updatedByUserId: 'user-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(
          calendarRepository: calendarRepository,
          pantryItems: [pantry],
          shoppingSchedule: shoppingSchedule,
          clock: FakeClock(now),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<KsAlmanacGrid>(find.byType(KsAlmanacGrid));
    final leadingPad = DateTime(2026, 7).weekday - DateTime.monday;
    CalendarDayStatus statusFor(int day) =>
        grid.days[leadingPad + day - 1].status!;

    expect(statusFor(6), CalendarDayStatus.planned);
    expect(statusFor(7), CalendarDayStatus.problem);
    expect(statusFor(8), CalendarDayStatus.missed);
    expect(statusFor(15), CalendarDayStatus.shopping);
  });

  testWidgets('CalendarScreen date cell tap opens the selected day route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calendarRepository = _FakeCalendarRepository([
      MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'persisted-recipe',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 3,
      ),
    ]);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
        ),
        GoRoute(
          path: '/day/:date',
          builder: (context, state) =>
              Text('day ${state.pathParameters['date']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(calendarRepository: calendarRepository),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, '6').first);
    await tester.pumpAndSettle();

    expect(find.text('day 2026-07-06'), findsOneWidget);
  });

  testWidgets('CalendarScreen opens the shopping schedule from the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => CalendarScreen(
            initialMonth: DateTime(2026, 7),
            initialSelectedDate: DateTime(2026, 7, 6),
          ),
        ),
        GoRoute(
          path: '/calendar/shopping-schedule',
          builder: (context, state) =>
              const Scaffold(body: Text('shopping schedule sentinel')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _calendarOverrides(),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Shopping schedule'), findsOneWidget);

    await tester.tap(find.byTooltip('Shopping schedule'));
    await tester.pumpAndSettle();

    expect(find.text('shopping schedule sentinel'), findsOneWidget);
  });

  testWidgets('CalendarScreen saves active calendar defaults', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calendarRepository = _FakeCalendarRepository(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          calendarRepositoryProvider.overrideWithValue(calendarRepository),
          wasteRepositoryProvider.overrideWithValue(
            const _FakeWasteRepository([]),
          ),
          idGeneratorProvider.overrideWithValue(
            FakeIdGenerator(['settings-1']),
          ),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 5, 9))),
          recipeRepositoryProvider.overrideWithValue(
            const _FakeRecipeRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calendar defaults'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Default serving size'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Meals per day'),
      '4',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Dishes per meal'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Meal mode'),
      'Batch',
    );
    await tester.tap(find.text('Save defaults'));
    await tester.pumpAndSettle();

    expect(calendarRepository.settings, hasLength(1));
    expect(calendarRepository.settings.single.id, 'settings-1');
    expect(calendarRepository.settings.single.householdId, 'solo-household');
    expect(
      calendarRepository.settings.single.dateRangeStart,
      DateTime(2026, 7),
    );
    expect(
      calendarRepository.settings.single.dateRangeEnd,
      DateTime(2026, 7, 31),
    );
    expect(calendarRepository.settings.single.defaultServingSize, 6);
    expect(calendarRepository.settings.single.mealsPerDay, 4);
    expect(calendarRepository.settings.single.dishesPerMeal, 2);
    expect(calendarRepository.settings.single.mealModeName, 'Batch');
  });

  testWidgets(
    'CalendarScreen creates a new default when selected date matches no range',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final unrelated = CalendarDaySettings(
        id: 'august-defaults',
        householdId: 'solo-household',
        dateRangeStart: DateTime(2026, 8),
        dateRangeEnd: DateTime(2026, 8, 31),
        defaultServingSize: 9,
        mealsPerDay: 2,
        dishesPerMeal: 3,
        mealModeName: 'August batch',
        isActive: true,
      );
      final calendarRepository = _FakeCalendarRepository(
        const [],
        settings: [unrelated],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
            calendarRepositoryProvider.overrideWithValue(calendarRepository),
            wasteRepositoryProvider.overrideWithValue(
              const _FakeWasteRepository([]),
            ),
            idGeneratorProvider.overrideWithValue(
              FakeIdGenerator(['july-defaults']),
            ),
            clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 5, 9))),
            recipeRepositoryProvider.overrideWithValue(
              const _FakeRecipeRepository([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Calendar defaults'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Start date'))
            .controller
            ?.text,
        '2026-07-01',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'End date'))
            .controller
            ?.text,
        '2026-07-31',
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Default serving size'),
            )
            .controller
            ?.text,
        '4',
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Default serving size'),
        '5',
      );
      await tester.tap(find.text('Save defaults'));
      await tester.pumpAndSettle();

      expect(calendarRepository.settings, hasLength(2));
      expect(
        calendarRepository.settings.singleWhere(
          (setting) => setting.id == unrelated.id,
        ),
        same(unrelated),
      );
      final created = calendarRepository.settings.singleWhere(
        (setting) => setting.id == 'july-defaults',
      );
      expect(created.dateRangeStart, DateTime(2026, 7));
      expect(created.dateRangeEnd, DateTime(2026, 7, 31));
      expect(created.defaultServingSize, 5);
    },
  );

  testWidgets(
    'CalendarScreen awaits persisted defaults during initial reload',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calendarRepository = _FakeCalendarRepository(
        const [],
        settings: [
          CalendarDaySettings(
            id: 'specific-defaults',
            householdId: 'solo-household',
            dateRangeStart: DateTime(2026, 7, 6),
            dateRangeEnd: DateTime(2026, 7, 6),
            defaultServingSize: 8,
            mealsPerDay: 2,
            dishesPerMeal: 2,
            mealModeName: 'Specific day',
            isActive: true,
          ),
        ],
        settingsDelay: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _calendarOverrides(calendarRepository: calendarRepository),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Calendar defaults'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Start date'))
            .controller
            ?.text,
        '2026-07-06',
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Default serving size'),
            )
            .controller
            ?.text,
        '8',
      );
    },
  );

  testWidgets('joint non-admin roles do not see Calendar defaults', (
    tester,
  ) async {
    for (final role in [
      HouseholdRole.cook,
      HouseholdRole.shopper,
      HouseholdRole.member,
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(
              ActiveHouseholdContext(
                id: 'joint-household',
                name: 'Joint kitchen',
                role: role,
                isJoint: true,
                hasPremium: true,
              ),
            ),
            calendarRepositoryProvider.overrideWithValue(
              _FakeCalendarRepository(const []),
            ),
            wasteRepositoryProvider.overrideWithValue(
              const _FakeWasteRepository([]),
            ),
            recipeRepositoryProvider.overrideWithValue(
              const _FakeRecipeRepository([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CalendarScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('calendar-defaults-action')),
        findsNothing,
        reason: '${role.label} must not receive an Admin-only control.',
      );
    }
  });

  test('CalendarSettingsController rejects joint non-admin default edits', () {
    for (final role in [
      HouseholdRole.cook,
      HouseholdRole.shopper,
      HouseholdRole.member,
    ]) {
      final repository = _FakeCalendarRepository(const []);
      final controller = CalendarSettingsController(
        repository: repository,
        householdId: 'joint-household',
        household: ActiveHouseholdContext(
          id: 'joint-household',
          name: 'Joint kitchen',
          role: role,
          isJoint: true,
          hasPremium: true,
        ),
        idGenerator: FakeIdGenerator(['settings-${role.name}']),
        clock: FakeClock(DateTime(2026, 7, 5, 9)),
      );

      expect(
        controller.saveDefaults(
          dateRangeStart: DateTime(2026, 7),
          dateRangeEnd: DateTime(2026, 7, 31),
          defaultServingSize: 4,
          mealsPerDay: 3,
          dishesPerMeal: 1,
          mealModeName: 'Standard',
        ),
        throwsStateError,
        reason: '${role.label} must not persist Admin-only defaults.',
      );
      expect(repository.settings, isEmpty);
    }
  });
}
