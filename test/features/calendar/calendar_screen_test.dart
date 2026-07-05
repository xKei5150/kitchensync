import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
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
  _FakeCalendarRepository(this.meals);

  final List<MealScheduleEntry> meals;
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
  ) => const Stream.empty();

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
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
        unit: Unit.piece,
      ),
    ],
    instructions: const [],
  );
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
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
        ),
      ),
    );

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.byType(KsAlmanacGrid), findsOneWidget);
    // The legend reads the four reserved statuses.
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    // The selected-day peek surfaces today's plan.
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
    expect(find.text('Dinner · serves 4'), findsOneWidget);
  });

  testWidgets('CalendarScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
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
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          calendarRepositoryProvider.overrideWithValue(calendarRepository),
          recipeRepositoryProvider.overrideWithValue(
            _FakeRecipeRepository([_recipe()]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
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
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          calendarRepositoryProvider.overrideWithValue(calendarRepository),
          recipeRepositoryProvider.overrideWithValue(
            _FakeRecipeRepository([_recipe()]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
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
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          calendarRepositoryProvider.overrideWithValue(calendarRepository),
          recipeRepositoryProvider.overrideWithValue(
            _FakeRecipeRepository([_recipe()]),
          ),
        ],
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
}
