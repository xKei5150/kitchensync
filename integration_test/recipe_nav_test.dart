import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:kitchensync/features/today/presentation/screens/day_view_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// On-device guard for the Navigator page-key collision that crashed the day
/// view: tapping "Recipe" used to `push('/recipes')` — a StatefulShellRoute
/// branch — which re-instantiated the shell as a second root page and tripped
/// `!keyReservation.contains(key)`. The button now opens the recipe detail via
/// the root-level `/recipe` route, so no shell is re-instantiated.
///
/// This target used to build the real router with fake repositories and no
/// Firebase. That stopped working at the 2026-07-22 auth hardening: with
/// `firebaseAuthProvider` null the session is
/// [AppSessionPhase.unavailable] and every route redirects to `/onboarding`.
/// Overriding the session alone does not fix it either — `TodayScreen`
/// deliberately returns an empty snapshot whenever `firebaseAuthProvider` is
/// null (the "no sample-only state" rule), so the fake calendar repository was
/// never consulted and no meal card ever rendered.
///
/// It therefore runs on the emulator harness like the other 32 targets: a real
/// signed-in identity, a real household, and a real scheduled meal, so the
/// navigation being guarded is exercised against the real data path.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today → Start cooking → Recipe navigates without crashing', (
    tester,
  ) async {
    await bootEmulatedApp();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final now = DateTime(2026, 6, 25, 9);
    final dayKey = DateFormat('yyyy-MM-dd').format(now);
    final recipeId = 'recipe-nav-${DateTime.now().microsecondsSinceEpoch}';
    const recipeName = 'Tomato & white bean braise';

    await withTimeout(
      'seed recipe-nav recipe and scheduled meal',
      () => seedFirestoreDocumentsThroughEmulatorAdmin({
        // Field shapes mirror the proven fixtures in
        // day_view_lifecycle_emulator_test.dart: the meal entry is keyed on
        // `mealSlot`/`state`/`marking`, not on a display label.
        'recipes/$recipeId': {
          'authorUserId': uid,
          'householdId': householdId,
          'name': recipeName,
          'description': 'A navigation fixture.',
          'defaultServingSize': 4,
          'mealTimeTags': const ['Dinner'],
          'recipeTags': const ['Vegetarian'],
          'priceEstimate': 120.0,
          'location': 'KitchenSync',
          'visibility': 'private',
          'monetization': 'free',
          'instructions': const ['Simmer.'],
          'createdAt': now,
          'updatedAt': now,
        },
        'households/$householdId/mealScheduleEntries/recipe-nav-meal': {
          'householdId': householdId,
          'date': dayKey,
          'mealSlot': 'Dinner',
          'recipeId': recipeId,
          'servingSize': 4,
          'state': 'scheduled',
          'marking': 'none',
          'linkedLeftoverId': null,
          'mergedMealCount': 1,
          'ingredientOverrides': const <Map<String, Object?>>[],
        },
      }),
    );

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // Pins "today" to the seeded meal's date.
        clockProvider.overrideWithValue(FakeClock(now)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _RecipeNavApp(),
      ),
    );

    await _waitFor(
      tester,
      container,
      find.text('Start cooking'),
      describing: 'the Today meal hero',
    );

    // Today → day view (full-screen route pushed over the shell).
    await tester.tap(find.text('Start cooking'));
    await _waitFor(
      tester,
      container,
      find.byType(DayViewScreen),
      describing: 'the day view',
    );
    expect(find.widgetWithText(OutlinedButton, 'Recipe'), findsOneWidget);

    // Day view → recipe detail. Previously crashed here.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recipe'));
    await _waitFor(
      tester,
      container,
      find.byType(RecipeDetailScreen),
      describing: 'the recipe detail',
    );

    expect(tester.takeException(), isNull);
    expect(find.text(recipeName), findsWidgets);
  });
}

/// Mirrors `KitchenSyncApp` by watching `routerProvider`.
///
/// `routerProvider` watches the session, so Riverpod rebuilds it — producing a
/// **new** `GoRouter` — as the session advances. Pumping the instance captured
/// at `container.read` time (as this target used to) leaves a router whose
/// redirect closure still sees a loading session, so every route pins to
/// `/auth/loading` and Today never renders.
class _RecipeNavApp extends ConsumerWidget {
  const _RecipeNavApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: ref.watch(routerProvider),
  );
}

/// Bounded wait that reports the session phase on failure, so a redirect back
/// to `/onboarding` is immediately distinguishable from a slow emulator read.
Future<void> _waitFor(
  WidgetTester tester,
  ProviderContainer container,
  Finder finder, {
  required String describing,
}) => waitForFinder(
  tester,
  finder,
  describing: describing,
  diagnose: () =>
      'Session phase is ${container.read(appSessionStateProvider).phase}.',
);
