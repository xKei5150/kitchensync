// SIZE_OK: recipe detail tests cover existing full detail UI states.
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
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository({List<CalendarDaySettings>? settings})
    : settings =
          settings ??
          [
            CalendarDaySettings(
              id: 'default-week',
              householdId: 'joint-household',
              dateRangeStart: DateTime(2026, 7),
              dateRangeEnd: DateTime(2026, 7, 31),
              defaultServingSize: 6,
              mealsPerDay: 3,
              dishesPerMeal: 1,
              mealModeName: 'standard',
              isActive: true,
            ),
          ];

  MealScheduleEntry? upserted;
  final List<CalendarDaySettings> settings;

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
    return Stream.value(
      settings
          .where((setting) => setting.householdId == householdId)
          .toList(growable: false),
    );
  }

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {}

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

class _FakeIngredientRepository implements IngredientRepository {
  const _FakeIngredientRepository(this.ingredients);

  final List<Ingredient> ingredients;

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async {
    for (final ingredient in ingredients) {
      if (ingredient.id == id) return ingredient;
    }
    return null;
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
  }) async => ingredients
      .where((ingredient) => ingredient.name.contains(query))
      .take(limit)
      .toList(growable: false);

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<void> createCustom(Ingredient ingredient) async {}

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      Stream.value(const []);
}

const _cookHousehold = ActiveHouseholdContext(
  id: 'joint-household',
  name: 'Shared kitchen',
  role: HouseholdRole.cook,
  isJoint: true,
  hasPremium: true,
);

const _memberHousehold = ActiveHouseholdContext(
  id: 'joint-household',
  name: 'Shared kitchen',
  role: HouseholdRole.member,
  isJoint: true,
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

Ingredient _pepperWithLocalBundleUnit() {
  final now = DateTime(2026, 7, 5, 12);
  return Ingredient(
    id: 'pepper',
    name: 'pepper',
    displayNames: const {'en': 'Pepper'},
    category: IngredientCategory.produce,
    defaultUnit: UnitId('bundle'),
    allowedUnits: [UnitId('bundle'), UnitId.g],
    localUnitDefinitions: [
      UnitDefinition(
        id: UnitId('bundle'),
        label: 'Bundle',
        pluralLabel: 'Bundles',
        dimension: UnitDimension.informal,
        family: UnitSystemFamily.local,
      ),
    ],
    scope: IngredientScope.householdCustom,
    householdId: 'solo-household',
    createdAt: now,
    updatedAt: now,
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

  testWidgets(
    'RecipeDetailScreen schedule uses the later overlapping calendar default',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final calendar = _FakeCalendarRepository(
        settings: [
          CalendarDaySettings(
            id: 'broad-default',
            householdId: 'joint-household',
            dateRangeStart: DateTime(2026, 7),
            dateRangeEnd: DateTime(2026, 7, 31),
            defaultServingSize: 6,
            mealsPerDay: 3,
            dishesPerMeal: 1,
            mealModeName: 'standard',
            isActive: true,
          ),
          CalendarDaySettings(
            id: 'specific-default',
            householdId: 'joint-household',
            dateRangeStart: DateTime(2026, 7, 6),
            dateRangeEnd: DateTime(2026, 7, 12),
            defaultServingSize: 8,
            mealsPerDay: 2,
            dishesPerMeal: 2,
            mealModeName: 'holiday',
            isActive: true,
          ),
        ],
      );
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
            unit: UnitId.kg,
          ),
        ],
        instructions: const ['Fry until golden.'],
      );

      await tester.pumpWidget(
        await _wrap(
          const RecipeDetailScreen(recipeId: 'fried-chicken'),
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_cookHousehold),
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
      expect(find.text('Serves 8'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Add to calendar'));
      await tester.tap(find.text('Add to calendar'));
      await tester.pumpAndSettle();

      expect(calendar.upserted?.id, 'meal-1');
      expect(calendar.upserted?.recipeId, 'fried-chicken');
      expect(calendar.upserted?.date, DateTime(2026, 7, 6));
      expect(calendar.upserted?.mealLabel, 'Dinner');
      expect(calendar.upserted?.servingSize, 8);
    },
  );

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
          unit: UnitId.kg,
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

  testWidgets(
    'public detail shows metadata and save/social but hides member mutations',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipe = Recipe(
        id: 'public-soup',
        authorUserId: 'author-1',
        householdId: 'author-household',
        name: 'Public Soup',
        description: 'A public recipe.',
        defaultServingSize: 4,
        mealTimeTags: const ['Dinner'],
        recipeTags: const ['Soup'],
        priceEstimate: 120,
        location: 'Manila',
        youtubeEmbedUrl: Uri.parse('https://youtu.be/public-soup'),
        visibility: RecipeVisibility.public,
        monetization: RecipeMonetization.free,
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
        ingredients: const [],
        instructions: const ['Simmer.'],
      );

      await tester.pumpWidget(
        await _wrap(
          const RecipeDetailScreen(recipeId: 'public-soup'),
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_memberHousehold),
            recipeRecordProvider(
              'public-soup',
            ).overrideWith((ref) => Stream.value(recipe)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('by author-1 · Manila'), findsOneWidget);
      expect(find.text('https://youtu.be/public-soup'), findsOneWidget);
      expect(find.byTooltip('Save recipe'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.byTooltip('Delete recipe'), findsNothing);
      expect(find.text('Start cooking'), findsNothing);
      expect(find.text('Schedule'), findsNothing);
    },
  );

  testWidgets(
    'cook detail exposes household edit delete and schedule actions',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipe = Recipe(
        id: 'shared-soup',
        authorUserId: 'author-1',
        householdId: 'joint-household',
        name: 'Shared Soup',
        description: 'A household recipe.',
        defaultServingSize: 4,
        mealTimeTags: const ['Dinner'],
        recipeTags: const ['Soup'],
        location: 'Shared kitchen',
        visibility: RecipeVisibility.private,
        monetization: RecipeMonetization.free,
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
        ingredients: const [],
        instructions: const ['Simmer.'],
      );

      await tester.pumpWidget(
        await _wrap(
          const RecipeDetailScreen(recipeId: 'shared-soup'),
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_cookHousehold),
            recipeRecordProvider(
              'shared-soup',
            ).overrideWith((ref) => Stream.value(recipe)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete recipe'), findsOneWidget);
      expect(find.text('Start cooking'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.byTooltip('Save recipe'), findsNothing);
    },
  );

  testWidgets('RecipeDetailScreen renders linked local unit label plurals', (
    tester,
  ) async {
    final recipe = Recipe(
      id: 'pepper-salsa',
      authorUserId: 'user-1',
      householdId: 'solo-household',
      name: 'Pepper Salsa',
      description: 'Fresh pepper salsa',
      defaultServingSize: 4,
      mealTimeTags: const ['Snack'],
      recipeTags: const ['Produce'],
      location: 'Home',
      visibility: RecipeVisibility.private,
      monetization: RecipeMonetization.free,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      ingredients: [
        RecipeIngredient(
          id: 'ri-1',
          recipeId: 'pepper-salsa',
          ingredientId: 'pepper',
          quantity: 3,
          unit: UnitId('bundle'),
          description: 'Pepper',
        ),
      ],
      instructions: const ['Chop peppers.'],
    );

    await tester.pumpWidget(
      await _wrap(
        const RecipeDetailScreen(recipeId: 'pepper-salsa'),
        overrides: [
          ingredientRepositoryProvider.overrideWithValue(
            _FakeIngredientRepository([_pepperWithLocalBundleUnit()]),
          ),
          recipeRecordProvider(
            'pepper-salsa',
          ).overrideWith((ref) => Stream.value(recipe)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 Bundles'), findsOneWidget);
    expect(find.text('3 bundle'), findsNothing);
    debugPrint(
      'QA_RECIPE_DETAIL_LOCAL_UNIT rendered=3 Bundles raw_slug_absent=true',
    );
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
