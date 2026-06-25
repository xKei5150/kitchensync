import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';

/// On-device visual walk of the P2 "Premium & system" screens. Boots the real
/// router on the simulator and drives real taps through every P2 surface,
/// screenshotting each. Presentational screens — no Firebase needed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  testWidgets('P2 screens render on-device', (tester) async {
    // iOS needs the surface converted to an image before screenshots.
    await binding.convertFlutterSurfaceToImage();
    final router = await pumpApp(tester);

    // Navigation is driven through the real router (robust on iOS); the
    // tap-based entry points are covered by test/app/p2_routes_test.dart.
    Future<void> go(String location, String shotName) async {
      router.go('/today');
      await tester.pumpAndSettle();
      unawaited(router.push(location));
      await shot(tester, shotName);
    }

    // Today now carries the notifications / settings / account entry points.
    await shot(tester, '01-today');

    await go('/notifications', '02-notifications');
    await go('/settings', '03-settings');
    await go('/settings/premium', '04-premium');

    // Household → tap a non-admin member to reveal the role sheet.
    await go('/household', '05-household');
    await tester.tap(find.text('Ben'));
    await shot(tester, '06-role-sheet');
    await tester.tap(find.text('Save role')); // dismiss the sheet
    await tester.pumpAndSettle();

    // Menu Sets deck → editor → apply sheet.
    await go('/menu-sets', '07-menu-sets');
    unawaited(router.push('/menu-sets/edit'));
    await shot(tester, '08-menu-set-editor');
    await tester.tap(find.text('Apply to calendar').last);
    await shot(tester, '09-apply-sheet');
    await tester.tap(find.text('Apply · 28 meals')); // dismiss the sheet
    await tester.pumpAndSettle();

    // Onboarding front door → household setup.
    await go('/onboarding', '10-sign-in');
    unawaited(router.push('/onboarding/household'));
    await shot(tester, '11-household-setup');
  });
}
