import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    ThemeData theme, {
    String? initialName,
  }) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          home: CreateCustomIngredientScreen(initialName: initialName),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the identity preview and core fields', (tester) async {
    await pump(tester, AppTheme.light());

    expect(find.text('Add to catalog'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('CATEGORY — SETS THE COLOUR EVERYWHERE'), findsOneWidget);
    // Default identity card: empty name + 7-day default shelf life.
    expect(find.text('New ingredient'), findsOneWidget);
    expect(find.textContaining('keeps ~7 days'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('identity card reflects the typed name', (tester) async {
    await pump(tester, AppTheme.light(), initialName: 'Sweet potato');
    expect(find.text('Sweet potato'), findsWidgets);
  });

  testWidgets('surfaces a summary and field error when the name is empty', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.tap(find.widgetWithText(FilledButton, 'Create ingredient'));
    await tester.pump();

    expect(find.text('One thing needs a look'), findsOneWidget);
    expect(
      find.text('Give it a name so you can find it later.'),
      findsOneWidget,
    );
  });

  testWidgets('clears the name error live once a name is typed', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.tap(find.widgetWithText(FilledButton, 'Create ingredient'));
    await tester.pump();
    expect(
      find.text('Give it a name so you can find it later.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'Sweet potato');
    await tester.pump();

    expect(find.text('Give it a name so you can find it later.'), findsNothing);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
  });
}
