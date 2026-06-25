import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';

void main() {
  testWidgets('TodayScreen renders the greeting and tonight hero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const TodayScreen()),
    );

    expect(find.text('Good evening, Ana'), findsOneWidget);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
    expect(find.text('Start cooking'), findsOneWidget);
    expect(find.text('Use soon'.toUpperCase()), findsOneWidget);
  });

  testWidgets('TodayScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const TodayScreen()),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Good evening, Ana'), findsOneWidget);
  });
}
