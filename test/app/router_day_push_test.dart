import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('tapping Recipe on the day view opens the recipe detail '
      'without colliding Navigator page keys', (tester) async {
    final router = await _pumpApp(tester);

    // Open the full-screen day view pushed over the shell.
    unawaited(router.push('/day'));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday 25'), findsOneWidget);

    // Tapping "Recipe" pushes the recipe detail ("Closer Look") over the root
    // navigator. Both `/day` and `/recipe` are root-level full-screen routes,
    // so neither re-instantiates the shell as a second root page — the
    // page-key collision that previously crashed `push('/recipes')` (a shell
    // branch) cannot occur.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recipe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
  });

  testWidgets('pushing the full-screen /day route over the shell is fine', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    unawaited(router.push('/day'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Wednesday 25'), findsOneWidget);
  });
}
