import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/dev_tools/dev_tools_screen.dart';

/// `DevToolsScreen` is the only screen in the app that no test constructed. It
/// is reachable solely from the `if (kDebugMode)` `/dev` route, and it carries a
/// second `!kDebugMode` guard of its own. Both facts are worth pinning: the
/// guard is the last line of defence if the route gate is ever relaxed.
Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: theme, home: const DevToolsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('DevToolsScreen renders every debug entry point', (tester) async {
    await _pump(tester, AppTheme.light());

    expect(find.text('Dev tools'), findsOneWidget);
    expect(find.text('Seed global dictionary'), findsOneWidget);
    expect(find.text('Accessibility audit'), findsOneWidget);
    expect(find.text('Accessibility states'), findsOneWidget);
    expect(find.text('System states'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DevToolsScreen starts idle with no status text', (tester) async {
    await _pump(tester, AppTheme.light());

    // The seed button is enabled (not mid-run) and reports nothing yet.
    final seedButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Seed global dictionary'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(seedButton.onPressed, isNotNull);
    expect(find.text('Seeding...'), findsNothing);
    expect(find.text('Failed: '), findsNothing);
  });

  testWidgets('DevToolsScreen renders in dark theme without error', (
    tester,
  ) async {
    await _pump(tester, AppTheme.dark());

    expect(find.text('Dev tools'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
