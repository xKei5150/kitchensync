import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

Future<ActiveHouseholdContext> _waitForActiveHousehold(
  ProviderContainer container,
  String householdId,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 10)) {
    final ctx = container.read(activeHouseholdContextProvider);
    if (ctx?.id == householdId) return ctx!;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Active household did not resolve to $householdId.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two meals of one recipe aggregate into a single scaled line', (
    tester,
  ) async {
    await bootEmulatedApp();
    await withTimeout(
      'seed dictionary',
      seedGlobalDictionaryThroughEmulatorAdmin,
    );
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    final household = await _waitForActiveHousehold(container, householdId);

    // Recipe: 100 g flour at default 2 servings.
    final recipe = await withTimeout(
      'create recipe',
      () async {
        final recipes = await container
            .read(recipeImportControllerProvider)
            .importDrafts([
              const RecipeDraft(
                name: 'Flatbread',
                defaultServingSize: 2,
                timeTags: ['Dinner'],
                recipeTags: ['bread'],
                description: 'Multi-meal aggregation fixture.',
                ingredients: [
                  RecipeIngredientDraft(
                    name: 'Flour',
                    quantity: 100,
                    unit: UnitId.g,
                  ),
                ],
                instructions: ['Bake.'],
                visibility: RecipeVisibility.private,
              ),
            ]);
        return recipes.single;
      },
    );
    final flourId = recipe.ingredients.single.ingredientId;

    // Two meals in the window: one at default 2 servings, one at 4 servings.
    // Expected flour demand = 100*(2/2) + 100*(4/2) = 100 + 200 = 300 g, one line.
    final calendar = container.read(calendarRepositoryProvider);
    await withTimeout('schedule meal A', () => calendar.upsertMeal(
      householdId: householdId,
      entry: MealScheduleEntry(
        id: 'meal-a',
        recipeId: recipe.id,
        date: DateTime(2026, 7, 6),
        mealLabel: 'Lunch',
        servingSize: 2,
      ),
    ));
    await withTimeout('schedule meal B', () => calendar.upsertMeal(
      householdId: householdId,
      entry: MealScheduleEntry(
        id: 'meal-b',
        recipeId: recipe.id,
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
    ));

    final shopping = ShoppingPlanningController(
      repository: container.read(shoppingRepositoryProvider),
      writeCoordinator: ShoppingWriteCoordinator(
        repository: container.read(shoppingCommandRepositoryProvider),
        householdId: householdId,
        idGenerator: FakeIdGenerator(const ['mm-list-command']),
      ),
      calendarRepository: calendar,
      pantryRepository: container.read(pantryRepositoryProvider),
      purchaseHistoryRepository: container.read(
        purchaseHistoryRepositoryProvider,
      ),
      wasteRepository: container.read(wasteRepositoryProvider),
      recipeRepository: container.read(recipeRepositoryProvider),
      householdId: householdId,
      household: household,
      idGenerator: container.read(idGeneratorProvider),
      clock: container.read(clockProvider),
      shoppingScheduleRepository: container.read(
        shoppingScheduleRepositoryProvider,
      ),
    );

    final list = await withTimeout(
      'generate multi-meal list',
      () => shopping.generateAdaptiveList(
        type: ShoppingListType.emergency,
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 6),
      ),
    );

    // Multi-meal scaling: 100*(2/2) + 100*(4/2) = 300 g aggregated into ONE
    // line at the normalized base unit, persisted through the callable.
    final flourLines = list.items.where((i) => i.ingredientId == flourId);
    expect(flourLines, hasLength(1));
    expect(flourLines.single.quantityNeeded, 300);
    expect(flourLines.single.unit, UnitId.g);
    // NOTE: source-link provenance is not asserted here because the emulator's
    // ControlledEmulatorAllocationPlannerClient stub emits `sourceMealLinks: []`
    // by design; source-link preservation is covered via the real planner in
    // FD-SHOP-SUB-01 / FD-MENU-APPLY-SHOP-01.
  });
}
