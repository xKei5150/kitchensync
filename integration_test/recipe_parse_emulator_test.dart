import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

import '_helpers.dart';

RecipeImportController _controller(
  ProviderContainer container, {
  required String householdId,
  required String userId,
  required bool hasPremium,
  required List<String> ids,
}) {
  return RecipeImportController(
    repository: container.read(recipeRepositoryProvider),
    householdId: householdId,
    household: ActiveHouseholdContext(
      id: householdId,
      name: 'Parse QA kitchen',
      role: HouseholdRole.admin,
      isJoint: hasPremium,
      hasPremium: hasPremium,
    ),
    userId: userId,
    idGenerator: FakeIdGenerator(ids),
    clock: FakeClock(DateTime(2026, 7, 18, 9)),
    resolveOrCreateIngredient: container.read(
      resolveOrCreateIngredientProvider,
    ),
  );
}

List<RecipeDraft> _twoDrafts() => const [
  RecipeDraft(
    name: 'Parsed alpha',
    defaultServingSize: 2,
    timeTags: ['Dinner'],
    recipeTags: ['parse'],
    description: 'First parsed block.',
    ingredients: [],
    instructions: ['Cook alpha.'],
    visibility: RecipeVisibility.private,
  ),
  RecipeDraft(
    name: 'Parsed beta',
    defaultServingSize: 4,
    timeTags: ['Lunch'],
    recipeTags: ['parse'],
    description: 'Second parsed block.',
    ingredients: [],
    instructions: ['Cook beta.'],
    visibility: RecipeVisibility.private,
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('premium paste-and-parse persists every parsed recipe', (
    tester,
  ) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final imported = await withTimeout(
      'import parsed drafts as premium',
      () => _controller(
        container,
        householdId: householdId,
        userId: uid,
        hasPremium: true,
        ids: const ['parse-alpha', 'parse-beta'],
      ).importParsedDrafts(_twoDrafts()),
    );
    expect(imported, hasLength(2));

    final repo = container.read(recipeRepositoryProvider);
    final alpha = await withTimeout(
      'read persisted alpha',
      () => repo.watchById('parse-alpha').firstWhere((r) => r != null),
    );
    final beta = await withTimeout(
      'read persisted beta',
      () => repo.watchById('parse-beta').firstWhere((r) => r != null),
    );
    expect(alpha!.name, 'Parsed alpha');
    expect(beta!.name, 'Parsed beta');
  });

  testWidgets('free household is denied paste-and-parse import', (
    tester,
  ) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      _controller(
        container,
        householdId: householdId,
        userId: uid,
        hasPremium: false,
        ids: const ['free-alpha', 'free-beta'],
      ).importParsedDrafts(_twoDrafts()),
      throwsStateError,
    );

    // Verify absence through the admin surface: reading a missing recipe as a
    // client hits the visibility rule on a null document and is denied, which
    // is not the same as proving the write never happened.
    final exists = await withTimeout(
      'confirm free import persisted nothing',
      () => firestoreDocumentExistsThroughEmulatorAdmin('recipes/free-alpha'),
    );
    expect(exists, isFalse);
  });
}
