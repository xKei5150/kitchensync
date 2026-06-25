import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';

/// On-device visual walk of the P4 "Accessibility States" surfaces: the
/// debug-only states gallery (focus, dynamic type, reduced-motion map) in
/// light + dark, plus the two graduated forms with their validation errors
/// surfaced — the error summary, the per-field danger treatment, and the
/// inline messages. Presentational until save, so no emulator is needed for
/// the screenshots.
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

  testWidgets('P4 accessibility states render on-device', (tester) async {
    await binding.convertFlutterSurfaceToImage();

    Future<void> go(GoRouter router, String location) async {
      router.go('/today');
      await tester.pumpAndSettle();
      unawaited(router.push(location));
      await tester.pumpAndSettle();
    }

    // Light theme — the states gallery, then the add-pantry form with its
    // validation errors surfaced by an attempted save.
    final light = await pumpApp(tester, AppTheme.light());
    await go(light, '/dev/a11y-states');
    await shot(tester, '01-a11y-states-light');

    await go(light, '/pantry/add');
    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await shot(tester, '02-add-pantry-errors-light');

    await go(light, '/ingredient/create');
    await tester.tap(find.widgetWithText(FilledButton, 'Create ingredient'));
    await shot(tester, '03-create-ingredient-errors-light');

    // Dark theme — the gallery again.
    final dark = await pumpApp(tester, AppTheme.dark());
    await go(dark, '/dev/a11y-states');
    await shot(tester, '04-a11y-states-dark');
  });
}
