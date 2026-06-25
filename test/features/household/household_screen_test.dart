import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/presentation/screens/household_screen.dart';

void main() {
  testWidgets('HouseholdScreen lists members and the invite code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HouseholdScreen()),
    );

    expect(find.text("Who's in the kitchen"), findsOneWidget);
    expect(find.byType(KsMemberRow), findsNWidgets(3));
    expect(find.byType(KsInviteCode), findsOneWidget);
    expect(find.text('SAGE-417'), findsOneWidget);
  });

  testWidgets('tapping a non-admin member opens the role sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HouseholdScreen()),
    );

    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();

    expect(find.text("Ben's role"), findsOneWidget);
    expect(find.text('Save role'), findsOneWidget);

    // Selecting a different role updates the radio without throwing.
    await tester.tap(find.text('Shopper'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('HouseholdScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const HouseholdScreen()),
    );
    expect(tester.takeException(), isNull);
  });
}
