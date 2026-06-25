import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/pantry/presentation/screens/add_pantry_item_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: theme, home: const AddPantryItemScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the graduated form scaffold', (tester) async {
    await pump(tester, AppTheme.light());

    expect(find.text('Add to pantry'), findsWidgets);
    expect(find.text('ITEM'), findsOneWidget);
    expect(find.text('QUANTITY'), findsOneWidget);
    expect(find.text('UNIT'), findsOneWidget);
    expect(find.text('SECTION'), findsOneWidget);
    // The item control invites a pick when nothing is selected.
    expect(find.text('Select an ingredient'), findsOneWidget);
  });

  testWidgets('blocks save with a message until an ingredient is picked', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await tester.pump();

    expect(find.text('Please select an ingredient.'), findsOneWidget);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
  });
}
