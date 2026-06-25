import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/dev_tools/accessibility_audit_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const AccessibilityAuditScreen()),
    );
    await tester.pump();
  }

  testWidgets('renders the three audit sections', (tester) async {
    await pump(tester, AppTheme.light());

    expect(find.text('Provable, not just pretty'), findsOneWidget);
    expect(find.text('SCREEN 17 · CONTRAST AUDIT — LIGHT'), findsOneWidget);
    expect(find.text('SCREEN 18 · CONTRAST AUDIT — DARK'), findsOneWidget);
    expect(find.text('SCREEN 19 · COLOUR-VISION & GREYSCALE'), findsOneWidget);

    // The colour-vision wall labels each simulation.
    expect(find.text('NORMAL VISION'), findsOneWidget);
    expect(find.text('DEUTERANOPIA'), findsOneWidget);
    expect(find.text('GREYSCALE'), findsOneWidget);
  });

  testWidgets('measures real token pairs into AA/AAA verdicts', (tester) async {
    await pump(tester, AppTheme.light());

    // Primary text on white clears AAA; the reserved tertiary grey is flagged
    // sub-AA (it resolves to ~3.2:1 → "AA Large", never full body AA).
    expect(find.text('AAA'), findsWidgets);
    expect(find.text('AA LARGE'), findsWidgets);
    // Each panel tallies its AA passes.
    expect(find.textContaining('pass AA'), findsWidgets);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
  });
}
