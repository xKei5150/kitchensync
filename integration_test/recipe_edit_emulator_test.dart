import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manual recipe persists all editable fields round-trip', (
    tester,
  ) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final now = DateTime(2026, 7, 18, 9);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(recipeRepositoryProvider);

    final recipe = Recipe(
      id: 'edit-fields',
      authorUserId: uid,
      householdId: householdId,
      name: 'Full field recipe',
      description: 'Every editable field populated.',
      dishImageUrl: 'https://example.test/dish.jpg',
      defaultServingSize: 3,
      mealTimeTags: const ['Dinner', 'Lunch'],
      recipeTags: const ['Comfort', 'Test'],
      priceEstimate: 725,
      location: 'Nonna kitchen',
      youtubeEmbedUrl: Uri.parse('https://youtu.be/example'),
      visibility: RecipeVisibility.public,
      monetization: RecipeMonetization.paid,
      createdAt: now,
      updatedAt: now,
      ingredients: const [],
      instructions: const ['Step one.', 'Step two.'],
    );
    await withTimeout('persist full-field recipe', () => repo.upsert(recipe));

    final loaded = await withTimeout(
      'read full-field recipe',
      () => repo.watchById('edit-fields').firstWhere((r) => r != null),
    );
    expect(loaded!.name, 'Full field recipe');
    expect(loaded.dishImageUrl, 'https://example.test/dish.jpg');
    expect(loaded.location, 'Nonna kitchen');
    expect(loaded.youtubeEmbedUrl.toString(), 'https://youtu.be/example');
    expect(loaded.visibility, RecipeVisibility.public);
    expect(loaded.monetization, RecipeMonetization.paid);
    expect(loaded.priceEstimate, 725);
    expect(loaded.defaultServingSize, 3);
    expect(loaded.mealTimeTags, ['Dinner', 'Lunch']);
    expect(loaded.recipeTags, ['Comfort', 'Test']);
    expect(loaded.instructions, ['Step one.', 'Step two.']);
  });

  testWidgets('manual creation links a dictionary ingredient by id', (
    tester,
  ) async {
    await bootEmulatedApp();
    await withTimeout(
      'seed global dictionary',
      seedGlobalDictionaryThroughEmulatorAdmin,
    );
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = RecipeImportController(
      repository: container.read(recipeRepositoryProvider),
      householdId: householdId,
      household: ActiveHouseholdContext(
        id: householdId,
        name: 'Edit QA kitchen',
        role: HouseholdRole.admin,
        isJoint: false,
        hasPremium: false,
      ),
      userId: uid,
      idGenerator: FakeIdGenerator(const ['edit-recipe', 'edit-line']),
      clock: FakeClock(DateTime(2026, 7, 18, 9)),
      resolveOrCreateIngredient: container.read(
        resolveOrCreateIngredientProvider,
      ),
    );

    final imported = await withTimeout(
      'import manual recipe with dictionary ingredient',
      () => controller.importDrafts(const [
        RecipeDraft(
          name: 'Onion soup',
          defaultServingSize: 2,
          timeTags: ['Dinner'],
          recipeTags: ['Soup'],
          description: 'Uses a dictionary ingredient.',
          ingredients: [
            RecipeIngredientDraft(
              name: 'Onion',
              quantity: 2,
              unit: UnitId.piece,
            ),
          ],
          instructions: ['Simmer onions.'],
          visibility: RecipeVisibility.private,
        ),
      ]),
    );
    final recipe = imported.single;
    expect(recipe.ingredients, hasLength(1));
    final line = recipe.ingredients.single;
    expect(line.ingredientId, isNotEmpty);

    // The linked ingredient id resolves to a real dictionary document.
    final exists = await withTimeout(
      'confirm dictionary ingredient exists',
      () => firestoreDocumentExistsThroughEmulatorAdmin(
        'ingredients/${line.ingredientId}',
      ),
    );
    expect(exists, isTrue);
  });
}
