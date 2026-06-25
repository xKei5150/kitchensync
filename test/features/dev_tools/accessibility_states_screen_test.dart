import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/dev_tools/accessibility_states_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const AccessibilityStatesScreen()),
    );
    await tester.pump();
  }

  testWidgets('renders the four state sections', (tester) async {
    await pump(tester, AppTheme.light());

    expect(find.text('Built to bend, not break'), findsOneWidget);
    expect(find.text('Always know where you are'), findsOneWidget);
    expect(find.text('Bigger text, never broken layout'), findsOneWidget);
    expect(find.text('Movement that yields on request'), findsOneWidget);
    // The motion map names its interactions.
    expect(find.text('Sheet & dialog'), findsOneWidget);
    expect(find.text('Page transition'), findsOneWidget);
    // Dynamic-type ladder shows three system sizes.
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('200%'), findsOneWidget);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
  });
}
