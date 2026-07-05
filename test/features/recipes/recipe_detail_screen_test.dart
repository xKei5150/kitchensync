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
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCalendarRepository implements CalendarRepository {
  MealScheduleEntry? upserted;

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => const Stream.empty();

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {
    upserted = entry;
  }

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(String householdId) {
    return Stream.value([
      CalendarDaySettings(
        id: 'default-week',
        householdId: householdId,
        dateRangeStart: DateTime(2026, 7),
        dateRangeEnd: DateTime(2026, 7, 31),
        defaultServingSize: 6,
        mealsPerDay: 3,
        dishesPerMeal: 1,
        mealModeName: 'standard',
        isActive: true,
      ),
    ]);
  }

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {}

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

Future<Widget> _wrap(
  Widget home, {
  ThemeData? theme,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: home),
  );
}

void main() {
  testWidgets('RecipeDetailScreen renders the hero, scaler and cook CTAs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const RecipeDetailScreen()));

    expect(find.text('Tomato & white bean braise'), findsOneWidget);
    expect(find.byType(KsServingScaler), findsOneWidget);
    expect(find.text('White beans'), findsOneWidget);
    expect(find.text('Start cooking'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen schedule persists a dated meal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calendar = _FakeCalendarRepository();
    final recipe = Recipe(
      id: 'fried-chicken',
      authorUserId: 'user-1',
      householdId: 'solo-household',
      name: 'Fried Chicken',
      description: 'Crispy comfort food',
      defaultServingSize: 4,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Chicken'],
      location: 'Home',
      visibility: RecipeVisibility.private,
      monetization: RecipeMonetization.free,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      ingredients: const [
        RecipeIngredient(
          id: 'ri-1',
          recipeId: 'fried-chicken',
          ingredientId: 'chicken-thighs',
          quantity: 1,
          unit: Unit.kg,
        ),
      ],
      instructions: const ['Fry until golden.'],
    );

    await tester.pumpWidget(
      await _wrap(
        const RecipeDetailScreen(recipeId: 'fried-chicken'),
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
          calendarRepositoryProvider.overrideWithValue(calendar),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 5, 9))),
          idGeneratorProvider.overrideWithValue(FakeIdGenerator(['meal-1'])),
          recipeRecordProvider(
            'fried-chicken',
          ).overrideWith((ref) => Stream.value(recipe)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Schedule'));
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(calendar.upserted, isNull);
    expect(find.text('Schedule meal'), findsOneWidget);
    expect(find.text('Tomorrow · 2026-07-06'), findsOneWidget);
    expect(find.text('Serves 6'), findsOneWidget);

    await tester.tap(find.text('Add to calendar'));
    await tester.pumpAndSettle();

    expect(calendar.upserted?.id, 'meal-1');
    expect(calendar.upserted?.recipeId, 'fried-chicken');
    expect(calendar.upserted?.date, DateTime(2026, 7, 6));
    expect(calendar.upserted?.mealLabel, 'Dinner');
    expect(calendar.upserted?.servingSize, 6);
  });

  testWidgets('RecipeDetailScreen renders a persisted recipe by id', (
    tester,
  ) async {
    final recipe = Recipe(
      id: 'fried-chicken',
      authorUserId: 'user-1',
      householdId: 'solo-household',
      name: 'Fried Chicken',
      description: 'Crispy comfort food',
      defaultServingSize: 4,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Chicken'],
      priceEstimate: 250,
      location: 'Home',
      visibility: RecipeVisibility.private,
      monetization: RecipeMonetization.free,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      ingredients: const [
        RecipeIngredient(
          id: 'ri-1',
          recipeId: 'fried-chicken',
          ingredientId: 'chicken-thighs',
          quantity: 1,
          unit: Unit.kg,
          description: 'Chicken Thighs',
        ),
      ],
      instructions: const ['Coat chicken.', 'Fry until golden.'],
    );

    await tester.pumpWidget(
      await _wrap(
        const RecipeDetailScreen(recipeId: 'fried-chicken'),
        overrides: [
          recipeRecordProvider(
            'fried-chicken',
          ).overrideWith((ref) => Stream.value(recipe)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fried Chicken'), findsOneWidget);
    expect(
      find.textContaining('Crispy comfort food', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Chicken Thighs'), findsOneWidget);
    expect(find.text('Instructions'), findsOneWidget);
    expect(find.text('1. Coat chicken.'), findsOneWidget);
    expect(find.text('2. Fry until golden.'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(const RecipeDetailScreen(), theme: AppTheme.dark()),
    );

    expect(tester.takeException(), isNull);
  });
}
