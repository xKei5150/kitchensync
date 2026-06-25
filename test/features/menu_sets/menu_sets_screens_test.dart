import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_set_editor_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_sets_screen.dart';

void main() {
  testWidgets('MenuSetsScreen shows the premium deck and save CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const MenuSetsScreen()),
    );

    expect(find.text('A deck of weeks'), findsOneWidget);
    expect(find.text('Cosy autumn week'), findsOneWidget);
    expect(find.byType(KsMenuSetCard), findsWidgets);
    expect(find.text('Save this week as a set'), findsOneWidget);
  });

  testWidgets('MenuSetEditorScreen opens the Apply sheet and toggles mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const MenuSetEditorScreen()),
    );

    expect(find.byType(KsMenuSlotEditor), findsOneWidget);
    expect(find.text('Drop here'), findsOneWidget);

    // The first "Apply to calendar" is the screen CTA; opening the sheet shows
    // the date range + mode toggle.
    await tester.tap(find.text('Apply to calendar').first);
    await tester.pumpAndSettle();

    expect(find.text('Apply to the calendar'), findsOneWidget);
    expect(find.text('Fill empty'), findsOneWidget);
    expect(find.text('Apply · 28 meals'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu Sets screens render in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const MenuSetsScreen()),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const MenuSetEditorScreen()),
    );
    expect(tester.takeException(), isNull);
  });
}
