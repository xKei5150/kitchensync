import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

const _household = ActiveHouseholdContext(
  id: 'calendar-week-household',
  name: 'Calendar week kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

class _CalendarRepository implements CalendarRepository {
  const _CalendarRepository();

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value([
    if (!DateTime(2026, 7, 8).isBefore(startDate) &&
        !DateTime(2026, 7, 8).isAfter(endDate))
      MealScheduleEntry(
        id: 'week-meal',
        recipeId: 'week-recipe',
        date: DateTime(2026, 7, 8),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
  ]);

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => const Stream.empty();

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
  Future<void> upsertDaySettings(CalendarDaySettings next) async {}
}

class _RecipeRepository implements RecipeRepository {
  const _RecipeRepository();

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      Stream.value([
        Recipe(
          id: 'week-recipe',
          authorUserId: 'calendar-user',
          householdId: householdId,
          name: 'Wednesday vegetable bake',
          description: '',
          defaultServingSize: 4,
          mealTimeTags: const ['Dinner'],
          recipeTags: const [],
          location: '',
          visibility: RecipeVisibility.private,
          monetization: RecipeMonetization.free,
          createdAt: DateTime(2026, 7),
          updatedAt: DateTime(2026, 7),
          ingredients: const [],
          instructions: const [],
        ),
      ]);

  @override
  Stream<Recipe?> watchById(String recipeId) => const Stream.empty();

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
  }) async => throw UnimplementedError();
}

class _WasteRepository implements WasteRepository {
  const _WasteRepository();

  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Future<void> log(WasteEvent event) async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calendar week view renders, advances, and opens exact date', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: CalendarScreen(initialSelectedDate: DateTime(2026, 7)),
          ),
        ),
        GoRoute(
          path: '/day/:date',
          builder: (context, state) => Scaffold(
            body: Center(child: Text('Opened ${state.pathParameters['date']}')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_household),
          calendarRepositoryProvider.overrideWithValue(
            const _CalendarRepository(),
          ),
          recipeRepositoryProvider.overrideWithValue(const _RecipeRepository()),
          wasteRepositoryProvider.overrideWithValue(const _WasteRepository()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('29 June-5 July 2026'), findsOneWidget);
    await binding.takeScreenshot('calendar-week-cross-month');

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('6-12 July 2026'), findsOneWidget);
    expect(find.text('Wednesday vegetable bake'), findsOneWidget);
    await binding.takeScreenshot('calendar-week-next');

    await tester.tap(find.widgetWithText(InkWell, '8').first);
    await tester.pumpAndSettle();
    expect(find.text('Opened 2026-07-08'), findsOneWidget);
  });
}
