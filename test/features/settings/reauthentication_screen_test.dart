import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/settings/presentation/reauthentication_screen.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(theme: theme ?? AppTheme.dark(), home: child);
}

void main() {
  testWidgets('renders email and provider reauthentication actions', (
    tester,
  ) async {
    String? password;
    ReauthenticationProvider? provider;
    var cancelled = 0;
    await tester.pumpWidget(
      _wrap(
        ReauthenticationScreen(
          viewModel: const ReauthenticationViewModel(
            currentEmail: 'sam@example.com',
            availableProviders: [
              ReauthenticationProvider.google,
              ReauthenticationProvider.apple,
            ],
          ),
          onEmailPasswordReauthenticate: (value) => password = value,
          onProviderReauthenticate: (value) => provider = value,
          onCancel: () => cancelled++,
        ),
      ),
    );

    expect(find.text('Confirm your identity'), findsOneWidget);
    expect(find.text('Current email'), findsOneWidget);
    expect(find.text('sam@example.com'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Reauthenticate'), findsOneWidget);
    expect(find.text('Reauthenticate with Google'), findsOneWidget);
    expect(find.text('Reauthenticate with Apple'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reauth-password-field')),
      'secret',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Reauthenticate'));
    await tester.tap(find.text('Reauthenticate with Google'));
    await tester.tap(find.text('Cancel'));

    expect(password, 'secret');
    expect(provider, ReauthenticationProvider.google);
    expect(cancelled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'presents a password validation error without invoking callback',
    (tester) async {
      var submitted = 0;
      await tester.pumpWidget(
        _wrap(
          ReauthenticationScreen(
            viewModel: const ReauthenticationViewModel(
              currentEmail: 'sam@example.com',
            ),
            onEmailPasswordReauthenticate: (_) => submitted++,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Reauthenticate'));
      await tester.pump();

      expect(find.text('Enter your password.'), findsOneWidget);
      expect(submitted, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders integration error and external password error accessibly',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const ReauthenticationScreen(
            viewModel: ReauthenticationViewModel(
              currentEmail: 'sam@example.com',
              passwordError: 'That password was not accepted.',
              errorMessage: 'We could not confirm your identity.',
            ),
          ),
        ),
      );

      expect(find.text('That password was not accepted.'), findsOneWidget);
      expect(find.text('We could not confirm your identity.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('disables every action while email reauthentication is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ReauthenticationScreen(
          viewModel: const ReauthenticationViewModel(
            currentEmail: 'sam@example.com',
            availableProviders: [ReauthenticationProvider.google],
            isEmailSubmitting: true,
          ),
          onEmailPasswordReauthenticate: (_) {},
          onProviderReauthenticate: (_) {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('Reauthenticating...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('reauth-email-password-action')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Reauthenticate with Google'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('reauth-cancel-action')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows provider loading state and preserves other provider label',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReauthenticationScreen(
            viewModel: const ReauthenticationViewModel(
              currentEmail: 'sam@example.com',
              availableProviders: [
                ReauthenticationProvider.google,
                ReauthenticationProvider.apple,
              ],
              activeProvider: ReauthenticationProvider.apple,
            ),
            onProviderReauthenticate: (_) {},
          ),
        ),
      );

      expect(find.text('Reauthenticating...'), findsOneWidget);
      expect(find.text('Reauthenticate with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps the form accessible at narrow width and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: ReauthenticationScreen(
            viewModel: ReauthenticationViewModel(
              currentEmail: 'longer.email@example.com',
              availableProviders: [ReauthenticationProvider.google],
            ),
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('toggles password visibility with an accessible label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ReauthenticationScreen(
          viewModel: ReauthenticationViewModel(currentEmail: 'sam@example.com'),
        ),
      ),
    );

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
