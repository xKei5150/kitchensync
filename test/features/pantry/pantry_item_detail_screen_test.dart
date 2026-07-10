// SIZE_OK: pantry detail tests cover existing item lifecycle UI branches.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/pantry_item_detail_screen.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _activeHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

class _FakeCalendarRepository implements CalendarRepository {
  const _FakeCalendarRepository(this.meals);

  final List<MealScheduleEntry> meals;

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
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
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) {
    return Stream.value(
      recipes
          .where((recipe) => recipe.householdId == householdId)
          .toList(growable: false),
    );
  }

  @override
  Stream<Recipe?> watchById(String recipeId) {
    return Stream.value(
      recipes.where((recipe) => recipe.id == recipeId).firstOrNull,
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
  }) async {
    return const [];
  }

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

Ingredient _ingredient(
  String id,
  String name, {
  List<String> substituteIngredientIds = const [],
  UnitId defaultUnit = UnitId.g,
  List<UnitId> allowedUnits = const [UnitId.g],
  List<UnitDefinition> localUnitDefinitions = const [],
}) {
  final now = DateTime(2026, 7, 5);
  return Ingredient(
    id: id,
    name: name.toLowerCase(),
    displayNames: {'en': name},
    category: IngredientCategory.grain,
    defaultUnit: defaultUnit,
    allowedUnits: allowedUnits,
    localUnitDefinitions: localUnitDefinitions,
    defaultShelfLifeDays: 365,
    allergens: const [Allergen.gluten],
    substituteIngredientIds: substituteIngredientIds,
    scope: IngredientScope.global,
    createdAt: now,
    updatedAt: now,
  );
}

PantryItem _pantryItem() {
  final now = DateTime(2026, 7, 5);
  return PantryItem(
    id: 'rice-item',
    householdId: 'solo-household',
    ingredientId: 'rice',
    quantity: 2,
    unit: UnitId.kg,
    section: PantrySection.food,
    note: 'Keep dry.',
    lastPurchaseDate: DateTime(2026, 7),
    expiryDate: DateTime(2026, 7, 20),
    createdAt: now,
    updatedAt: now,
  );
}

PantryItem _localUnitPantryItem() {
  final now = DateTime(2026, 7, 5);
  return PantryItem(
    id: 'pepper-item',
    householdId: 'solo-household',
    ingredientId: 'pepper',
    quantity: 3,
    unit: UnitId('bundle'),
    section: PantrySection.food,
    createdAt: now,
    updatedAt: now,
  );
}

Recipe _recipe() {
  final now = DateTime(2026, 7, 5);
  return Recipe(
    id: 'garlic-rice',
    authorUserId: 'demo-user',
    householdId: 'solo-household',
    name: 'Garlic Rice',
    description: 'Pantry rice with aromatics',
    defaultServingSize: 4,
    mealTimeTags: const ['Breakfast'],
    recipeTags: const ['Pantry'],
    location: 'Home',
    visibility: RecipeVisibility.private,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: const [
      RecipeIngredient(
        id: 'ri-rice',
        recipeId: 'garlic-rice',
        ingredientId: 'rice',
        quantity: 300,
        unit: UnitId.g,
        description: 'Rice',
      ),
    ],
    instructions: const ['Fry garlic.', 'Add rice.'],
  );
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required PantryItem item,
  required Ingredient rice,
  required Ingredient cauliflower,
  required Recipe recipe,
  required MealScheduleEntry meal,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/pantry/${item.id}',
    routes: [
      GoRoute(
        path: '/pantry/:itemId',
        builder: (context, state) =>
            PantryItemDetailScreen(itemId: state.pathParameters['itemId']!),
      ),
      GoRoute(
        path: '/recipe/:recipeId',
        builder: (context, state) =>
            Text('Recipe route ${state.pathParameters['recipeId']}'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeHouseholdContextProvider.overrideWithValue(_activeHousehold),
        pantryItemStreamProvider(
          'solo-household',
          item.id,
        ).overrideWith((ref) => Stream.value(item)),
        pantryIngredientProvider(
          item.ingredientId,
        ).overrideWith((ref) async => Result.success(rice)),
        pantryIngredientProvider(
          'cauliflower-rice',
        ).overrideWith((ref) async => Result.success(cauliflower)),
        recipeRepositoryProvider.overrideWithValue(
          _FakeRecipeRepository([recipe]),
        ),
        calendarRepositoryProvider.overrideWithValue(
          _FakeCalendarRepository([meal]),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
}

void main() {
  testWidgets('PantryItemDetailScreen renders local unit plural label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bundle = UnitDefinition(
      id: UnitId('bundle'),
      label: 'Bundle',
      pluralLabel: 'Bundles',
      dimension: UnitDimension.informal,
      family: UnitSystemFamily.local,
    );
    final pepper = _ingredient(
      'pepper',
      'Pepper',
      defaultUnit: bundle.id,
      allowedUnits: [bundle.id],
      localUnitDefinitions: [bundle],
    );

    await _pumpDetail(
      tester,
      item: _localUnitPantryItem(),
      rice: pepper,
      cauliflower: _ingredient('cauliflower-rice', 'Cauliflower Rice'),
      recipe: _recipe(),
      meal: MealScheduleEntry(
        id: 'meal-1',
        recipeId: 'garlic-rice',
        date: DateTime(2026, 7, 4),
        mealLabel: 'Breakfast',
        servingSize: 4,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current quantity'), findsOneWidget);
    expect(find.text('3 Bundles'), findsOneWidget);
    expect(find.text('3 bundle'), findsNothing);
  });

  testWidgets('PantryItemDetailScreen shows recipe usage context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = _pantryItem();
    final rice = _ingredient(
      'rice',
      'Rice',
      substituteIngredientIds: const ['cauliflower-rice'],
    );
    final cauliflower = _ingredient('cauliflower-rice', 'Cauliflower Rice');
    final recipe = _recipe();
    final meal = MealScheduleEntry(
      id: 'meal-1',
      recipeId: recipe.id,
      date: DateTime(2026, 7, 4),
      mealLabel: 'Breakfast',
      servingSize: 4,
      state: ScheduledMealState.cooked,
      ingredientOverrides: const [
        MealIngredientOverride(
          originalIngredientId: 'rice',
          originalUnit: UnitId.g,
          substituteIngredientId: 'cauliflower-rice',
          substituteQuantity: 250,
          substituteUnit: UnitId.g,
        ),
      ],
    );

    await _pumpDetail(
      tester,
      item: item,
      rice: rice,
      cauliflower: cauliflower,
      recipe: recipe,
      meal: meal,
    );
    await tester.pumpAndSettle();

    expect(find.text('Current quantity'), findsOneWidget);
    expect(find.text('2 kg'), findsOneWidget);
    expect(find.text('Freshness state'), findsOneWidget);
    expect(find.textContaining('Fresh'), findsWidgets);
    expect(find.text('Last purchased'), findsOneWidget);
    expect(find.text('Typical shelf life'), findsOneWidget);
    expect(find.text('Allergens'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Used by Recipes'), findsOneWidget);
    expect(find.text('Garlic Rice'), findsOneWidget);
    expect(find.textContaining('Last cooked 2026-07-04'), findsOneWidget);
    expect(find.text('Used substitutes'), findsOneWidget);
    expect(find.text('Cauliflower Rice'), findsWidgets);
    expect(find.text('Ingredient substitutes'), findsOneWidget);

    await tester.tap(find.text('Garlic Rice'));
    await tester.pumpAndSettle();

    expect(find.text('Recipe route garlic-rice'), findsOneWidget);
  });
}
