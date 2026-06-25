import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/today/presentation/screens/day_view_screen.dart';

void main() {
  testWidgets('DayViewScreen renders the day timeline and tonight actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const DayViewScreen()),
    );

    expect(find.text('Wednesday 25'), findsOneWidget);
    expect(find.text('Yogurt & berries'), findsOneWidget);
    expect(find.text('Leftover pad thai'), findsOneWidget);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
    expect(find.text('Mark cooked'), findsOneWidget);
  });

  testWidgets('DayViewScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const DayViewScreen()),
    );

    expect(tester.takeException(), isNull);
  });
}
