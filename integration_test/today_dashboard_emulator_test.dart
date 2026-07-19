import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// FD-GEN-DASH-01: the Today dashboard summarizes the active household using
/// live calendar/recipe/pantry/shopping/waste providers (the old sample-only
/// `planning_providers.dart` has been removed). This proves the screen's data
/// sources return real seeded data and the screen renders it without error.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today dashboard renders live household data (no sample state)', (
    tester,
  ) async {
    await bootEmulatedApp();

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await seedGlobalDictionaryThroughEmulatorAdmin();

    final hid = await withTimeout(
      'wait for bootstrapped household',
      () => _waitForActiveHouseholdId(container),
    );

    // Seed live data: a recipe and pantry item in the active household.
    final recipe = await withTimeout(
      'create today recipe',
      () async {
        final recipes = await container
            .read(recipeImportControllerProvider)
            .importDrafts([
              const RecipeDraft(
                name: 'Dashboard demo stew',
                defaultServingSize: 2,
                timeTags: ['Dinner'],
                recipeTags: ['qa'],
                description: 'Recipe seeded for the Today dashboard test.',
                ingredients: [
                  RecipeIngredientDraft(
                    name: 'Dashboard onion',
                    quantity: 2,
                    unit: UnitId.piece,
                  ),
                ],
                instructions: ['Cook.'],
                visibility: RecipeVisibility.private,
              ),
            ]);
        return recipes.single;
      },
    );

    await withTimeout(
      'add pantry item',
      () => container.read(addPantryItemProvider)(
        AddPantryItemParams(
          householdId: hid,
          ingredientId: 'onion',
          quantity: 4,
          unit: UnitId.piece,
          section: PantrySection.food,
        ),
      ),
    );

    // The dashboard recipe source returns the seeded recipe (live, not sample).
    final recipes = await withTimeout(
      'observe live household recipes',
      () => container
          .read(recipeRepositoryProvider)
          .watchHouseholdRecipes(hid)
          .firstWhere((list) => list.any((r) => r.id == recipe.id)),
    );
    expect(recipes.any((r) => r.name == 'Dashboard demo stew'), isTrue);

    // The dashboard pantry source returns the seeded item (live, not sample).
    final pantry = await withTimeout(
      'observe live pantry items',
      () => container
          .read(pantryRepositoryProvider)
          .watchBySection(hid, PantrySection.food)
          .firstWhere((items) => items.any((i) => i.ingredientId == 'onion')),
    );
    expect(pantry.any((PantryItem i) => i.ingredientId == 'onion'), isTrue);

    // Pump the real TodayScreen against the live (real-auth) providers and
    // confirm it renders content rather than the "Could not load today" error.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TodayScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Could not load today'), findsNothing);
  });
}

Future<String> _waitForActiveHouseholdId(ProviderContainer container) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 25)) {
    final context = container.read(activeHouseholdContextProvider);
    if (context != null && context.id != previewHouseholdContext.id) {
      return context.id;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Active household context did not resolve.');
}
