import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/account_deletion_requested_screen.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(theme: theme ?? AppTheme.dark(), home: child);
}

void main() {
  testWidgets('confirms acceptance, sign-out, and returns through one action', (
    tester,
  ) async {
    var continued = 0;

    await tester.pumpWidget(
      _wrap(AccountDeletionRequestedScreen(onContinue: () => continued++)),
    );

    expect(find.text('Deletion request accepted'), findsOneWidget);
    expect(find.textContaining('Your request was accepted.'), findsOneWidget);
    expect(find.text("You're signed out"), findsOneWidget);
    expect(
      find.textContaining('continues processing after you leave this screen.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Return to sign in'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('request ID'), findsNothing);
    expect(find.textContaining('retained'), findsNothing);
    expect(find.textContaining('percent'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Return to sign in'));

    expect(continued, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays usable with large text, narrow space, and semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: AccountDeletionRequestedScreen(onContinue: _noop),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(find.text('Return to sign in'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('renders in the established dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AccountDeletionRequestedScreen(onContinue: _noop)),
    );

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
