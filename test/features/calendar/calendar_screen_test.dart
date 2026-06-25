import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';

void main() {
  testWidgets('CalendarScreen renders the month grid, legend and peek', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const CalendarScreen()),
    );

    expect(find.text('June 2025'), findsOneWidget);
    expect(find.byType(KsAlmanacGrid), findsOneWidget);
    // The legend reads the four reserved statuses.
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    // The selected-day peek surfaces today's plan.
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
  });

  testWidgets('CalendarScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const CalendarScreen()),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(KsAlmanacGrid), findsOneWidget);
  });
}
