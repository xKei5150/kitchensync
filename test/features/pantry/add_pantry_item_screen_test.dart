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

  testWidgets('surfaces a summary and field error when saving with no item', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await tester.pump();

    // Quantity defaults to a valid 1, so only the item is wrong → one error.
    expect(find.text('One thing needs a look'), findsOneWidget);
    expect(
      find.text('Pick an ingredient so it lands on the right shelf.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a quantity error that clears live once fixed', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await tester.pump();

    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);

    // Correcting the field clears its error without re-tapping save.
    await tester.enterText(find.byType(TextField).first, '3');
    await tester.pump();

    expect(find.text('Enter an amount greater than zero.'), findsNothing);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives 200% system text without overflow', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AddPantryItemScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
