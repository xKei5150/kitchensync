import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device guard for the Navigator page-key collision that crashed the day
/// view: tapping "Recipe" used to `push('/recipes')` — a StatefulShellRoute
/// branch — which re-instantiated the shell as a second root page and tripped
/// `!keyReservation.contains(key)`. The button now opens the recipe detail
/// ("Closer Look") via the root-level `/recipe` route, so no shell is
/// re-instantiated. Runs the real widgets and real taps on the simulator; no
/// Firebase needed since these screens are presentational.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today → Start cooking → Recipe navigates without crashing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final date = DateTime(2026, 6, 25);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(FakeClock(date)),
        calendarRepositoryProvider.overrideWithValue(
          _RecipeNavigationCalendarRepository(date),
        ),
        recipeRepositoryProvider.overrideWithValue(
          _RecipeNavigationRecipeRepository(date),
        ),
        ingredientRepositoryProvider.overrideWithValue(
          const _EmptyIngredientRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Today → day view (full-screen route pushed over the shell).
    await tester.tap(find.text('Start cooking'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Recipe'), findsOneWidget);

    // Day view → recipe detail. Previously crashed here.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recipe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
  });
}

class _RecipeNavigationCalendarRepository implements CalendarRepository {
  const _RecipeNavigationCalendarRepository(this.date);

  final DateTime date;

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value([
    MealScheduleEntry(
      id: 'meal-braise',
      recipeId: 'braise',
      date: date,
      mealLabel: 'Dinner',
      servingSize: 4,
    ),
  ]);

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => const Stream.empty();

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {}

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {}
}

class _RecipeNavigationRecipeRepository implements RecipeRepository {
  _RecipeNavigationRecipeRepository(DateTime now)
    : recipe = Recipe(
        id: 'braise',
        authorUserId: 'fixture-user',
        householdId: 'solo-household',
        name: 'Tomato & white bean braise',
        description: 'A navigation fixture.',
        defaultServingSize: 4,
        mealTimeTags: const ['Dinner'],
        recipeTags: const ['Vegetarian'],
        location: 'KitchenSync',
        visibility: RecipeVisibility.private,
        monetization: RecipeMonetization.free,
        createdAt: now,
        updatedAt: now,
        ingredients: const [],
        instructions: const [],
      );

  final Recipe recipe;

  @override
  Stream<Recipe?> watchById(String recipeId) =>
      Stream.value(recipeId == recipe.id ? recipe : null);

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value([recipe]);

  @override
  Future<void> delete(String recipeId) async {}

  @override
  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  }) => throw UnimplementedError();

  @override
  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  }) async => const [];

  @override
  Future<void> upsert(Recipe recipe) async {}
}

class _EmptyIngredientRepository implements IngredientRepository {
  const _EmptyIngredientRepository();

  @override
  Future<void> createCustom(Ingredient ingredient) async {}

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async => null;

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  }) async => const [];

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      Stream.value(const []);

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) =>
      Stream.value(const []);
}
