import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  Widget child, {
  ThemeData? theme,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: child),
  );
}

void main() {
  testWidgets('SignInScreen shows disabled OAuth and email paths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const SignInScreen()));

    expect(find.text('KitchenSync'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Not configured'), findsNWidgets(2));
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'you@email.com'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
  });

  testWidgets('SignInScreen does not use anonymous OAuth placeholders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const SignInScreen()));

    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Set up your kitchen'), findsNothing);
  });

  testWidgets('SignInScreen validates the email password path', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const SignInScreen()));

    await tester.enterText(
      find.widgetWithText(TextField, 'you@email.com'),
      'ana@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');
    await tester.tap(find.text('Continue with email'));
    await tester.pump();

    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('HouseholdSetupScreen lets you pick a kitchen kind', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const HouseholdSetupScreen()));

    expect(find.text('Set up your kitchen'), findsOneWidget);
    expect(find.text('Just me'), findsOneWidget);
    expect(find.text('Create a household'), findsOneWidget);
    expect(find.byType(KsBadge), findsOneWidget); // Premium on "joint"

    // Selecting the joint option moves the check mark without throwing.
    await tester.tap(find.text('Create a household'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('HouseholdSetupScreen can skip setup in debug builds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _wrap(
        const HouseholdSetupScreen(),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      ),
    );

    expect(find.text('Skip for now'), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pump();

    expect(prefs.getBool(skipHouseholdSetupPrefKey), isTrue);
  });

  testWidgets('Onboarding screens render in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const SignInScreen(), theme: AppTheme.dark()),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _wrap(const HouseholdSetupScreen(), theme: AppTheme.dark()),
    );
    expect(tester.takeException(), isNull);
  });
}
