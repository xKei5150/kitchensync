import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public recipe likes and comments persist from the iOS UI', (
    tester,
  ) async {
    // Start from a fresh identity. The iOS Simulator keychain survives an
    // app uninstall, so reusing the previous run's Firebase user would find
    // this fixed-id recipe already liked and commented on by that uid — the
    // Like control would render as 'Unlike recipe' and the single-comment
    // assertion would see stale rows.
    await bootEmulatedApp(clearExistingSession: true);
    // Focusing the comment composer makes the iOS Simulator raise its software
    // keyboard, which reports a viewInsets bottom near the full viewport height
    // and collapses the detail screen's scroll body. Pin it so this target does
    // not depend on whether a hardware keyboard is connected. The viewport size
    // is deliberately left native: this screen's hero overflows a forced
    // 393x852 logical viewport.
    if (defaultTargetPlatform != TargetPlatform.android) {
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.resetViewInsets);
    }
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    final uid = user!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final now = DateTime(2026, 7, 18, 12);
    // Unique per run: a fixed id would already exist from a previous run,
    // owned by that run's uid and household, so this run's upsert would be
    // denied by the recipe authorship rules.
    final recipeId = 'itest-public-social-$uid';

    final dataContainer = ProviderContainer();
    addTearDown(dataContainer.dispose);
    await withTimeout(
      'persist public social recipe',
      () => dataContainer
          .read(recipeRepositoryProvider)
          .upsert(
            Recipe(
              id: recipeId,
              authorUserId: uid,
              householdId: householdId,
              name: 'Community tomato stew',
              description:
                  'A public recipe for social interaction verification.',
              defaultServingSize: 4,
              mealTimeTags: const ['Dinner'],
              recipeTags: const ['Stew'],
              priceEstimate: 220,
              location: 'Test kitchen',
              visibility: RecipeVisibility.public,
              monetization: RecipeMonetization.free,
              createdAt: now,
              updatedAt: now,
              ingredients: const [],
              instructions: const ['Simmer until rich.'],
            ),
          ),
    );

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        // Mounting the screen directly skips the router, which normally holds
        // `/auth/loading` until the Firebase auth stream emits. Without these
        // the first build reads `activeUserIdProvider` while the session is
        // still `loadingAuth` and throws.
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          activeUserIdProvider.overrideWithValue(uid),
          activeHouseholdContextProvider.overrideWithValue(
            ActiveHouseholdContext(
              id: householdId,
              name: debugHouseholdName,
              role: HouseholdRole.admin,
              isJoint: false,
              hasPremium: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: RecipeDetailScreen(recipeId: recipeId),
        ),
      ),
    );
    await settleOrAdvance(tester);
    await binding.convertFlutterSurfaceToImage();

    await tester.ensureVisible(find.text('Community'));
    await tester.tap(find.byTooltip('Like recipe'));
    await settleOrAdvance(tester);
    final like = await withTimeout(
      'read persisted recipe like',
      () => FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .collection('likes')
          .doc(uid)
          .get(),
    );
    expect(like.exists, isTrue);
    expect(like.data()?['userId'], uid);

    await tester.enterText(
      find.byType(TextField),
      'Clear steps and a useful serving size.',
    );
    await tester.tap(find.byTooltip('Post comment'));
    final comments = await withTimeout(
      'observe persisted recipe comment',
      () => FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .collection('comments')
          .where('authorUserId', isEqualTo: uid)
          .snapshots()
          .firstWhere((snapshot) => snapshot.docs.isNotEmpty),
    );
    expect(comments.docs.single.data()['body'], contains('useful serving'));

    await withTimeout('wait for comment composer to clear', () async {
      while (tester
          .widget<TextField>(find.byType(TextField))
          .controller!
          .text
          .isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    await settleOrAdvance(tester);
    expect(find.text('Clear steps and a useful serving size.'), findsOneWidget);

    await binding.takeScreenshot('recipe-social-public');
  });
}
