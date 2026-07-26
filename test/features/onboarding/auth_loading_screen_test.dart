import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/auth_loading_screen.dart';

/// `AuthLoadingScreen` is the router's `initialLocation`, so every cold start
/// renders it before any other surface. It had no direct render test — the
/// integration targets exercised it only incidentally, which meant a crash in
/// its error branch would surface as an unexplained boot failure rather than a
/// named test failure.
Future<void> _pump(WidgetTester tester, AppSessionState session) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appSessionStateProvider.overrideWithValue(session)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AuthLoadingScreen(),
      ),
    ),
  );
  // A spinner animates forever in the loading branch — pump, never settle.
  await tester.pump();
}

void main() {
  testWidgets('AuthLoadingScreen shows a neutral restoring state', (
    tester,
  ) async {
    await _pump(tester, const AppSessionState.loadingAuth());

    expect(find.text('Restoring your account'), findsOneWidget);
    expect(
      find.text('Checking your sign-in and household access…'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The recovery affordances belong to the error branch only.
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AuthLoadingScreen surfaces recovery actions on error', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppSessionState.error(error: 'network unreachable'),
    );

    expect(find.text('We could not restore your kitchen'), findsOneWidget);
    // The copy must promise that a failed restore did not mutate the account.
    expect(
      find.textContaining('Your account has not been changed.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AuthLoadingScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionStateProvider.overrideWithValue(
            const AppSessionState.loadingAuth(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AuthLoadingScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Restoring your account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
