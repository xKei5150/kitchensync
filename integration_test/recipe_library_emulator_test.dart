import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

import '_helpers.dart';

/// Builds a rule-safe public recipe. Ingredients are intentionally empty so the
/// create only touches the recipe document (the ingredient subcollection has
/// its own reference-validation rules exercised elsewhere); price/serving
/// fields are what the budget search normalizes over.
Recipe _publicRecipe({
  required String id,
  required String authorUserId,
  required String householdId,
  required String name,
  required int defaultServingSize,
  double? priceEstimate,
  required DateTime now,
  RecipeVisibility visibility = RecipeVisibility.public,
}) {
  return Recipe(
    id: id,
    authorUserId: authorUserId,
    householdId: householdId,
    name: name,
    description: 'Public recipe for library verification.',
    defaultServingSize: defaultServingSize,
    mealTimeTags: const ['Dinner'],
    recipeTags: const ['verify'],
    priceEstimate: priceEstimate,
    location: 'Test kitchen',
    visibility: visibility,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: const [],
    instructions: const ['Cook thoroughly.'],
  );
}

Future<Recipe?> _readRecipe(RecipeRepository repo, String id) {
  return repo.watchById(id).firstWhere((recipe) => recipe?.id == id);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public recipe saves as an independent editable local copy', (
    tester,
  ) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final now = DateTime(2026, 7, 18, 9);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(recipeRepositoryProvider);

    await withTimeout(
      'persist public source recipe',
      () => repo.upsert(
        _publicRecipe(
          id: 'lib-source-pub',
          authorUserId: uid,
          householdId: householdId,
          name: 'Shared stew',
          defaultServingSize: 4,
          priceEstimate: 400,
          now: now,
        ),
      ),
    );

    final saved = await withTimeout(
      'save public recipe as local copy',
      () => repo.savePublicRecipeAsLocalCopy(
        sourceRecipeId: 'lib-source-pub',
        userId: uid,
        householdId: householdId,
        localRecipeId: 'lib-local-copy',
        savedRecipeId: 'lib-saved-1',
        now: now,
      ),
    );
    expect(saved.sourceRecipeId, 'lib-source-pub');
    expect(saved.localRecipeId, 'lib-local-copy');

    final localCopy = await withTimeout(
      'read local copy',
      () => _readRecipe(repo, 'lib-local-copy'),
    );
    expect(localCopy, isNotNull);
    expect(localCopy!.visibility, RecipeVisibility.private);
    expect(localCopy.sourceRecipeId, 'lib-source-pub');
    expect(localCopy.name, 'Shared stew');

    // Editing the local copy must not mutate the public source.
    await withTimeout(
      'edit local copy name',
      () => repo.upsert(
        _publicRecipe(
          id: 'lib-local-copy',
          authorUserId: uid,
          householdId: householdId,
          name: 'My tweaked stew',
          defaultServingSize: 4,
          priceEstimate: 400,
          now: now,
          visibility: RecipeVisibility.private,
        ),
      ),
    );
    final sourceAfterEdit = await withTimeout(
      'reload source after local edit',
      () => repo
          .watchById('lib-source-pub')
          .firstWhere((r) => r != null && r.name == 'Shared stew'),
    );
    expect(sourceAfterEdit!.name, 'Shared stew');

    // Deleting the local copy leaves the source intact.
    await withTimeout('delete local copy', () => repo.delete('lib-local-copy'));
    final sourceAfterDelete = await withTimeout(
      'reload source after local delete',
      () => _readRecipe(repo, 'lib-source-pub'),
    );
    expect(sourceAfterDelete, isNotNull);
    expect(sourceAfterDelete!.name, 'Shared stew');
  });

  testWidgets(
    'budget and target-servings search filters by price per serving',
    (tester) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final now = DateTime(2026, 7, 18, 10);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(recipeRepositoryProvider);

    // cheap: 400/4 = 100 per serving -> 200 for 2 servings (affordable).
    // pricey: 2000/4 = 500 per serving -> 1000 for 2 servings (too expensive).
    await withTimeout(
      'persist cheap public recipe',
      () => repo.upsert(
        _publicRecipe(
          id: 'lib-cheap',
          authorUserId: uid,
          householdId: householdId,
          name: 'Budget beans',
          defaultServingSize: 4,
          priceEstimate: 400,
          now: now,
        ),
      ),
    );
    await withTimeout(
      'persist pricey public recipe',
      () => repo.upsert(
        _publicRecipe(
          id: 'lib-pricey',
          authorUserId: uid,
          householdId: householdId,
          name: 'Luxury roast',
          defaultServingSize: 4,
          priceEstimate: 2000,
          now: now,
        ),
      ),
    );

    final affordable = await withTimeout(
      'search public recipes within budget',
      () => repo.searchPublicRecipes(budget: 250, targetServings: 2),
    );
    final ids = affordable.map((r) => r.id).toSet();
    expect(ids, contains('lib-cheap'));
    expect(ids, isNot(contains('lib-pricey')));
  });
}
