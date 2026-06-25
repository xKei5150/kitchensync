import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';

/// On-device visual walk of the P3 "Accessibility & Forms" surfaces: the two
/// graduated forms (Add to pantry, Create ingredient) in light + dark, and the
/// debug-only accessibility verification surface (contrast audit + the
/// colour-vision proofs). Presentational on first render — the forms only touch
/// Firebase on save — so no emulator is needed for the screenshots.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<GoRouter> pumpApp(WidgetTester tester, ThemeData theme) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: theme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  testWidgets('P3 forms & accessibility surface render on-device', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();

    Future<void> walk(GoRouter router, String location, String name) async {
      router.go('/today');
      await tester.pumpAndSettle();
      unawaited(router.push(location));
      await shot(tester, name);
    }

    // Light theme — the two forms and the audit surface.
    final light = await pumpApp(tester, AppTheme.light());
    await walk(light, '/pantry/add', '01-add-pantry-light');
    await walk(light, '/ingredient/create', '02-create-ingredient-light');
    await walk(light, '/dev/a11y', '03-accessibility-audit');

    // Dark theme — the same two forms.
    final dark = await pumpApp(tester, AppTheme.dark());
    await walk(dark, '/pantry/add', '04-add-pantry-dark');
    await walk(dark, '/ingredient/create', '05-create-ingredient-dark');
  });
}
