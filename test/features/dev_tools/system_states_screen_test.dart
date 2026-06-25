import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/dev_tools/system_states_screen.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(420, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(theme: theme, home: const SystemStatesScreen()),
  );
  // Skeleton + spinner animate forever — pump frames, never settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('SystemStatesScreen lays out every honest-edge section', (
    tester,
  ) async {
    await _pump(tester, AppTheme.light());

    expect(find.text('The honest edges'), findsOneWidget);
    expect(find.text('Two hands, one shelf'), findsOneWidget);
    expect(find.text('Works on the subway'), findsOneWidget);
    expect(find.text('A polite locked door'), findsOneWidget);
    // The live components are actually present, not just mocked.
    expect(find.byType(KsSkeleton), findsWidgets);
    expect(find.byType(KsDonutChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SystemStatesScreen surfaces the role capability matrix', (
    tester,
  ) async {
    await _pump(tester, AppTheme.light());

    expect(find.text('OWNER'), findsOneWidget);
    expect(find.text('MEMBER'), findsOneWidget);
    expect(find.text('VIEWER'), findsOneWidget);
    expect(find.text('Only owners can do that'), findsOneWidget);
  });

  testWidgets('SystemStatesScreen renders in dark theme without error', (
    tester,
  ) async {
    await _pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
    expect(find.text('The honest edges'), findsOneWidget);
  });
}
