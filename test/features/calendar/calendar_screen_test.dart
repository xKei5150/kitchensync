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
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository(this.meals, {List<CalendarDaySettings>? settings})
    : settings = settings ?? [];

  final List<MealScheduleEntry> meals;
  final List<CalendarDaySettings> settings;
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
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.value(
    settings
        .where((setting) => setting.householdId == householdId)
        .where((setting) => setting.isActive)
        .toList(growable: false),
  );

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
    expect(grid.days[leadingPad + 9].status, CalendarDayStatus.empty);
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

  test('CalendarSettingsController rejects member default edits', () async {
    final repository = _FakeCalendarRepository(const []);
    final controller = CalendarSettingsController(
      repository: repository,
      householdId: 'solo-household',
      household: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Test kitchen',
        role: HouseholdRole.member,
        isJoint: true,
        hasPremium: true,
      ),
      idGenerator: FakeIdGenerator(['settings-1']),
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
    );
    expect(repository.settings, isEmpty);
  });
}
