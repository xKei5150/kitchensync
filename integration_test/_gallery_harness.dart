import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Shared scaffolding for the on-device screenshot galleries.
///
/// These galleries used to build the real router **without** booting Firebase.
/// Since the 2026-07-22 auth hardening `firebaseAuthProvider` is null in that
/// setup, so the session sits at [AppSessionPhase.unavailable] and the router's
/// redirect sends *every* route to `/onboarding`. Each gallery therefore
/// screenshotted the sign-in page while claiming to walk Premium, Pantry,
/// accessibility and recipe surfaces — and the two that made no assertions
/// passed while proving nothing.
///
/// The fix is structural, not cosmetic: boot the same emulator harness the
/// other 32 targets use, and make every hop prove it landed on the intended
/// screen before the shutter fires. A gallery that cannot reach its screen now
/// fails loudly instead of quietly producing a folder of sign-in screenshots.

/// A booted gallery: real router, real session, real screens.
class Gallery {
  Gallery({
    required this.tester,
    required this.binding,
    required this.container,
    required this.settle,
  });

  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final ProviderContainer container;
  final SettleStrategy settle;

  /// Read fresh every time, never cached.
  ///
  /// `routerProvider` watches the session, so Riverpod rebuilds it — producing
  /// a **new** `GoRouter` — as the session advances. Holding the instance that
  /// existed at pump time (as every gallery used to, via
  /// `container.read(routerProvider)`) leaves a router whose redirect closure
  /// still sees a loading session, so every route pins to `/auth/loading` even
  /// after the real session is ready.
  GoRouter get router => container.read(routerProvider);

  String get currentPath =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// Pushes [location] over `/today`, proves [expect] is on screen, then
  /// screenshots as [screenshot].
  ///
  /// The assertion is the point. Without it a redirected route screenshots
  /// whatever the redirect landed on and the gallery still "passes".
  Future<void> visit(
    String location, {
    required Finder expect,
    required String screenshot,
  }) async {
    router.go('/today');
    await settle(tester);
    router.push(location).ignore();
    await waitFor(expect, describing: location);
    await binding.takeScreenshot(screenshot);
  }

  /// Screenshots the current surface after proving [expect] is on screen.
  Future<void> capture(String screenshot, {required Finder expect}) async {
    await waitFor(expect, describing: currentPath);
    await binding.takeScreenshot(screenshot);
  }

  /// Taps [target] on the current surface and screenshots the result.
  ///
  /// The tap target is asserted first: tapping a widget that is not there is
  /// how the previous revision of the P4 gallery failed.
  Future<void> tapAndCapture(
    Finder target, {
    required String screenshot,
    Finder? expectAfter,
  }) async {
    await waitFor(target, describing: 'tap target on $currentPath');
    await tester.tap(target);
    await settle(tester);
    if (expectAfter != null) {
      await waitFor(expectAfter, describing: 'the state the tap should show');
    }
    await binding.takeScreenshot(screenshot);
  }

  /// Waits up to ~10s for [finder], reporting the route actually reached.
  Future<void> waitFor(Finder finder, {required String describing}) =>
      waitForFinder(
        tester,
        finder,
        describing: describing,
        diagnose: () =>
            'Router is at "$currentPath"; session phase is '
            '${container.read(appSessionStateProvider).phase}.',
      );
}

/// Boots Firebase, signs in a disposable emulator identity, waits for the
/// session to become usable, and pumps the real router.
Future<Gallery> bootGallery(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required ThemeData theme,
  SettleStrategy settle = settleOrAdvance,
  bool grantPremium = false,
}) async {
  await bootEmulatedApp();
  if (grantPremium) await _grantPremiumToBootHousehold();
  await binding.convertFlutterSurfaceToImage();

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _GalleryApp(theme: theme),
    ),
  );
  await settle(tester);

  final gallery = Gallery(
    tester: tester,
    binding: binding,
    container: container,
    settle: settle,
  );
  await _awaitReadySession(gallery);
  return gallery;
}

/// Mirrors `KitchenSyncApp`: watches `routerProvider` so the widget tree picks
/// up each rebuilt router instead of pinning the first one.
class _GalleryApp extends ConsumerWidget {
  const _GalleryApp({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      MaterialApp.router(theme: theme, routerConfig: ref.watch(routerProvider));
}

/// Grants Premium to the household [bootEmulatedApp] seeds.
///
/// `/menu-sets` redirects to `/settings/premium` without it, so a Premium
/// gallery must arrange Premium rather than photograph the redirect.
Future<void> _grantPremiumToBootHousehold() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    fail('bootEmulatedApp did not leave a signed-in user for the gallery.');
  }
  final now = DateTime.now().toUtc();
  // Merge, never replace: a whole-document write here would delete the
  // `activeHouseholdId` that `bootEmulatedApp` just seeded and drop the
  // session straight back to `needsHouseholdSetup`.
  await withTimeout(
    'grant gallery household Premium',
    () => mergeFirestoreDocumentsThroughEmulatorAdmin({
      'households/${debugHouseholdIdForUser(uid)}': {
        'hasPremium': true,
        'maxMembers': 6,
        'updatedAt': now,
      },
      'users/$uid': {'isPremium': true, 'updatedAt': now},
    }),
  );
}

/// Fails fast if the session never becomes ready. This is exactly the state
/// that used to be silently tolerated, so it must not be tolerated here.
Future<void> _awaitReadySession(Gallery gallery) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    final phase = gallery.container.read(appSessionStateProvider).phase;
    if (phase == AppSessionPhase.ready) return;
    await gallery.settle(gallery.tester);
    await gallery.tester.pump(const Duration(milliseconds: 250));
  }
  fail(
    'Gallery session never became ready (phase '
    '${gallery.container.read(appSessionStateProvider).phase}). Every route '
    'would redirect to /onboarding and the screenshots would be worthless.',
  );
}
