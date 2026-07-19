import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

import '_helpers.dart';

Recipe _recipe({
  required String id,
  required String authorUserId,
  required String householdId,
  required String name,
  required RecipeVisibility visibility,
  required DateTime now,
}) {
  return Recipe(
    id: id,
    authorUserId: authorUserId,
    householdId: householdId,
    name: name,
    description: 'Visibility scoping fixture.',
    defaultServingSize: 2,
    mealTimeTags: const ['Dinner'],
    recipeTags: const ['scope'],
    priceEstimate: visibility == RecipeVisibility.public ? 300 : null,
    location: 'Test kitchen',
    visibility: visibility,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: const [],
    instructions: const ['Cook.'],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'My Recipes is household-scoped while Discover shows only public recipes',
    (tester) async {
      await bootEmulatedApp();
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final householdId = debugHouseholdIdForUser(uid);
      final now = DateTime(2026, 7, 18, 9);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(recipeRepositoryProvider);

      await withTimeout(
        'persist private own recipe',
        () => repo.upsert(
          _recipe(
            id: 'vis-private',
            authorUserId: uid,
            householdId: householdId,
            name: 'Private supper',
            visibility: RecipeVisibility.private,
            now: now,
          ),
        ),
      );
      await withTimeout(
        'persist public own recipe',
        () => repo.upsert(
          _recipe(
            id: 'vis-public',
            authorUserId: uid,
            householdId: householdId,
            name: 'Public supper',
            visibility: RecipeVisibility.public,
            now: now,
          ),
        ),
      );

      // My Recipes: household-scoped, shows both visibilities.
      final mine = await withTimeout(
        'load My Recipes for household',
        () => repo
            .watchHouseholdRecipes(householdId)
            .firstWhere((list) => list.length >= 2),
      );
      final mineIds = mine.map((r) => r.id).toSet();
      expect(mineIds, containsAll(<String>['vis-private', 'vis-public']));

      // Discover: public only, private never leaks.
      final discover = await withTimeout(
        'search public recipes for Discover',
        repo.searchPublicRecipes,
      );
      final discoverIds = discover.map((r) => r.id).toSet();
      expect(discoverIds, contains('vis-public'));
      expect(discoverIds, isNot(contains('vis-private')));
    },
  );
}
