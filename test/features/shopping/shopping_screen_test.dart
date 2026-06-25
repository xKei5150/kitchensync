import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_screen.dart';

void main() {
  testWidgets('ShoppingScreen renders the checklist, progress and payoff', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ShoppingScreen()),
    );

    expect(find.text('Weekly shop'), findsOneWidget);
    expect(find.text('7 / 11'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.text('Done shopping'), findsOneWidget);
    expect(find.byType(KsChecklistRow), findsNWidgets(4));
  });

  testWidgets('ShoppingScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const ShoppingScreen()),
    );

    expect(tester.takeException(), isNull);
  });
}
