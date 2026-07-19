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

  testWidgets('checklist persists unavailable and skipped item states', (
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

    // Recipe with two distinct ingredients -> two shopping lines.
    final recipe = await withTimeout('create recipe', () async {
      final recipes = await container
          .read(recipeImportControllerProvider)
          .importDrafts([
            const RecipeDraft(
              name: 'Two-item dish',
              defaultServingSize: 2,
              timeTags: ['Dinner'],
              recipeTags: ['test'],
              description: 'Item-state fixture.',
              ingredients: [
                RecipeIngredientDraft(
                  name: 'Onion',
                  quantity: 2,
                  unit: UnitId.piece,
                ),
                RecipeIngredientDraft(
                  name: 'Flour',
                  quantity: 200,
                  unit: UnitId.g,
                ),
              ],
              instructions: ['Cook.'],
              visibility: RecipeVisibility.private,
            ),
          ]);
      return recipes.single;
    });

    final calendar = container.read(calendarRepositoryProvider);
    await withTimeout('schedule meal', () => calendar.upsertMeal(
      householdId: householdId,
      entry: MealScheduleEntry(
        id: 'states-meal',
        recipeId: recipe.id,
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 2,
      ),
    ));

    final shopping = ShoppingPlanningController(
      repository: container.read(shoppingRepositoryProvider),
      writeCoordinator: ShoppingWriteCoordinator(
        repository: container.read(shoppingCommandRepositoryProvider),
        householdId: householdId,
        idGenerator: FakeIdGenerator(const [
          'states-list-command',
          'unavailable-command',
          'skipped-command',
        ]),
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
      'generate list',
      () => shopping.generateAdaptiveList(
        type: ShoppingListType.emergency,
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 6),
      ),
    );
    expect(list.items.length, greaterThanOrEqualTo(2));
    final first = list.items.first;
    final second = list.items[1];

    final r1 = await withTimeout(
      'mark first unavailable',
      () => shopping.updateItemStatus(
        listId: list.id,
        itemId: first.id,
        expectedRevision: list.revision,
        status: ShoppingListItemStatus.unavailable,
      ),
    );
    final rev1 = r1?.revision;
    if (rev1 == null) {
      throw StateError('Unavailable mutation returned no revision.');
    }
    await withTimeout(
      'mark second skipped',
      () => shopping.updateItemStatus(
        listId: list.id,
        itemId: second.id,
        expectedRevision: rev1,
        status: ShoppingListItemStatus.skipped,
      ),
    );

    // Read back the authoritative statuses from Firestore.
    final reloaded = await withTimeout(
      'reload list with both states',
      () => container
          .read(shoppingRepositoryProvider)
          .watchList(householdId: householdId, listId: list.id)
          .firstWhere((l) {
            if (l == null) return false;
            final statuses = l.items.map((i) => i.status).toSet();
            return statuses.contains(ShoppingListItemStatus.unavailable) &&
                statuses.contains(ShoppingListItemStatus.skipped);
          }),
    );
    final byId = {for (final i in reloaded!.items) i.id: i.status};
    expect(byId[first.id], ShoppingListItemStatus.unavailable);
    expect(byId[second.id], ShoppingListItemStatus.skipped);
  });
}
