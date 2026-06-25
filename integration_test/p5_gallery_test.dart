import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';

/// On-device visual walk of the P5 "System States & Intelligence" surfaces:
/// the debug-only system-states gallery (skeleton + charts live; conflict,
/// queue, and role-matrix presentational) and the premium Insights screen, in
/// light + dark.
///
/// The gallery animates forever (skeleton shimmer, the sync spinner), so it
/// uses fixed-frame pumps rather than [WidgetTester.pumpAndSettle], which would
/// never settle. Presentational where there is no backend, so no emulator is
/// needed for the screenshots.
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
    // Fixed-frame settle — the gallery's shimmer never quiesces.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return router;
  }

  Future<void> go(WidgetTester tester, GoRouter router, String location) async {
    router.go('/today');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    unawaited(router.push(location));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot(name);
  }

  testWidgets('P5 system states render on-device', (tester) async {
    await binding.convertFlutterSurfaceToImage();

    final light = await pumpApp(tester, AppTheme.light());
    await go(tester, light, '/dev/system-states');
    await shot(tester, '01-system-states-light');
    await go(tester, light, '/insights');
    await shot(tester, '02-insights-light');

    final dark = await pumpApp(tester, AppTheme.dark());
    await go(tester, dark, '/dev/system-states');
    await shot(tester, '03-system-states-dark');
    await go(tester, dark, '/insights');
    await shot(tester, '04-insights-dark');
  });
}
