import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCalendarRepository implements CalendarRepository {
  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return Stream.value([
      MealScheduleEntry(
        id: 'existing-dinner',
        recipeId: 'braise',
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
    ]);
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
  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      const Stream.empty();

  @override
  Stream<Recipe?> watchById(String recipeId) {
    final now = DateTime(2026, 7);
    return Stream.value(
      Recipe(
        id: recipeId,
        authorUserId: 'user-1',
        householdId: 'solo-household',
        name: 'Tomato & white bean braise',
        description: '',
        defaultServingSize: 4,
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
        ],
        instructions: const [],
      ),
    );
  }

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

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 6, 9))),
      calendarRepositoryProvider.overrideWithValue(_FakeCalendarRepository()),
      recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('tapping Recipe on the day view opens the recipe detail '
      'without colliding Navigator page keys', (tester) async {
    final router = await _pumpApp(tester);

    // Open the full-screen day view pushed over the shell.
    unawaited(router.push('/day'));
    await tester.pumpAndSettle();
    expect(find.text('Monday 6'), findsOneWidget);

    // Tapping "Recipe" pushes the recipe detail ("Closer Look") over the root
    // navigator. Both `/day` and `/recipe` are root-level full-screen routes,
    // so neither re-instantiates the shell as a second root page — the
    // page-key collision that previously crashed `push('/recipes')` (a shell
    // branch) cannot occur.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recipe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
  });

  testWidgets('pushing the full-screen /day route over the shell is fine', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    unawaited(router.push('/day'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Monday 6'), findsOneWidget);
  });

  testWidgets('invalid full-screen /day date redirects instead of previewing', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    router.go('/day/not-a-date');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Monday 6'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/calendar');
  });
}
