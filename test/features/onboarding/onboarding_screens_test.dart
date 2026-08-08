import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/sign_in_screen.dart';

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
  testWidgets(
    'SignInScreen hides unavailable Apple and shows explicit email modes',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const SignInScreen()));

      expect(find.text('KitchenSync'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Not configured'), findsOneWidget);
      expect(find.text('Login'), findsNWidgets(2));
      expect(find.text('Register'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'you@email.com'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    },
  );

  testWidgets('SignInScreen does not use anonymous OAuth placeholders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const SignInScreen()));

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
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pump();

    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('SignInScreen switches explicitly from login to registration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const SignInScreen()));

    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsNothing);

    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Password (12+ characters)'),
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
    await tester.pumpAndSettle();

    expect(find.text('Set up your kitchen'), findsOneWidget);
    expect(find.text('Just me'), findsOneWidget);
    expect(find.text('Create a household'), findsOneWidget);
    expect(find.byType(KsBadge), findsOneWidget); // Premium on "joint"

    // Selecting the joint option moves the check mark without throwing.
    await tester.tap(find.text('Create a household'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('HouseholdSetupScreen lists active and switchable kitchens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const pickerState = HouseholdPickerState(
      households: [
        HouseholdPickerOption(
          id: 'joint',
          name: 'Shared kitchen',
          role: HouseholdRole.cook,
          isJoint: true,
          hasPremium: true,
          isActive: true,
        ),
        HouseholdPickerOption(
          id: 'solo',
          name: 'My kitchen',
          role: HouseholdRole.admin,
          isJoint: false,
          hasPremium: false,
          isActive: false,
        ),
      ],
      userIsPremium: false,
      canCreateSolo: false,
      canCreateJoint: false,
    );
    await tester.pumpWidget(
      _wrap(
        const HouseholdSetupScreen(),
        overrides: [
          householdPickerProvider.overrideWith((ref) async => pickerState),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your kitchen'), findsOneWidget);
    expect(find.text('Shared kitchen'), findsOneWidget);
    expect(find.text('Cook · Shared · Premium'), findsOneWidget);
    expect(find.text('My kitchen'), findsOneWidget);
    expect(find.text('Admin · Solo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Active'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pick'), findsOneWidget);
    expect(find.text('Create and enter'), findsNothing);
    expect(find.text('Join with a code'), findsOneWidget);
  });

  testWidgets('HouseholdSetupScreen does not offer a debug skip bypass', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const HouseholdSetupScreen()));

    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('HouseholdSetupScreen rejects a legacy invite locally without '
      'a fallback', (tester) async {
    await tester.pumpWidget(_wrap(const HouseholdSetupScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste invite token'),
      'KS-HOUSEH',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();

    expect(find.textContaining('This invite cannot be used'), findsWidgets);
    expect(find.textContaining('Invite code not found'), findsNothing);
  });

  test(
    'opaque invite normalization removes whitespace without changing case',
    () {
      expect(
        HouseholdOnboardingController.normalizeInviteToken(' AbC_d-12 3\n'),
        'AbC_d-123',
      );
    },
  );

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

  // `OnboardingEntryScreen` is the `/onboarding` destination and the only
  // widget deciding whether a caller lands on household recovery or the real
  // Login/Register surface. It lives inside `sign_in_screen.dart`, so a
  // filename-based inventory misses it; nothing constructed it before.
  _onboardingEntryRouting();
}

void _onboardingEntryRouting() {
  Future<void> pumpEntry(
    WidgetTester tester, {
    required AppSessionPhase phase,
    bool showHouseholdPicker = false,
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        OnboardingEntryScreen(showHouseholdPicker: showHouseholdPicker),
        overrides: [
          appSessionStateProvider.overrideWithValue(
            AppSessionState(phase: phase),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('OnboardingEntryScreen sends a signed-out caller to sign in', (
    tester,
  ) async {
    await pumpEntry(tester, phase: AppSessionPhase.signedOut);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HouseholdSetupScreen), findsNothing);
  });

  testWidgets('OnboardingEntryScreen shows household setup when required', (
    tester,
  ) async {
    await pumpEntry(tester, phase: AppSessionPhase.needsHouseholdSetup);

    // A confirmed identity without a household must not see Login/Register.
    expect(find.byType(HouseholdSetupScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('OnboardingEntryScreen opens the picker for a ready session', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      phase: AppSessionPhase.ready,
      showHouseholdPicker: true,
    );

    expect(find.byType(HouseholdSetupScreen), findsOneWidget);
  });

  testWidgets('OnboardingEntryScreen keeps a ready session off the picker', (
    tester,
  ) async {
    await pumpEntry(tester, phase: AppSessionPhase.ready);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HouseholdSetupScreen), findsNothing);
  });
}
