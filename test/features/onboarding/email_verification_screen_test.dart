import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/email_verification_screen.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(theme: theme ?? AppTheme.dark(), home: child);
}

void main() {
  testWidgets('renders the verification actions and account email', (
    tester,
  ) async {
    var refreshes = 0;
    var resends = 0;
    var signOuts = 0;

    await tester.pumpWidget(
      _wrap(
        EmailVerificationScreen(
          accountEmail: 'ana@example.com',
          onRefreshStatus: () => refreshes++,
          onResendVerification: () => resends++,
          onSignOut: () => signOuts++,
        ),
      ),
    );

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
    expect(find.textContaining('KitchenSync'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.tap(find.text('Resend verification email'));
    await tester.tap(find.text('Sign out'));

    expect(refreshes, 1);
    expect(resends, 1);
    expect(signOuts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows inline error and keeps retry available', (tester) async {
    await tester.pumpWidget(
      _wrap(
        EmailVerificationScreen(
          accountEmail: 'cook@example.com',
          onRefreshStatus: () {},
          onResendVerification: () {},
          onSignOut: () {},
          errorMessage: 'Could not check your verification status.',
        ),
      ),
    );

    expect(
      find.text('Could not check your verification status.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Try again'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows refresh loading and disables every action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        EmailVerificationScreen(
          accountEmail: 'cook@example.com',
          onRefreshStatus: () {},
          onResendVerification: () {},
          onSignOut: () {},
          isRefreshing: true,
        ),
      ),
    );

    expect(find.text('Checking...'), findsOneWidget);
    expect(find.text('Checking verification status'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows resend and sign-out loading labels independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        EmailVerificationScreen(
          accountEmail: 'cook@example.com',
          onRefreshStatus: () {},
          onResendVerification: () {},
          onSignOut: () {},
          isResending: true,
        ),
      ),
    );

    expect(find.text('Sending...'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _wrap(
        EmailVerificationScreen(
          accountEmail: 'cook@example.com',
          onRefreshStatus: () {},
          onResendVerification: () {},
          onSignOut: () {},
          isSigningOut: true,
        ),
      ),
    );

    expect(find.text('Signing out...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meets tap-target and dark-theme rendering expectations', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        const EmailVerificationScreen(
          accountEmail: 'a.longer.email@example.com',
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
