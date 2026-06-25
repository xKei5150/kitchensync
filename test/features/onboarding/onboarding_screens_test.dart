import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/sign_in_screen.dart';

void main() {
  testWidgets('SignInScreen shows the wordmark and OAuth + email paths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const SignInScreen()),
    );

    expect(find.text('KitchenSync'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('HouseholdSetupScreen lets you pick a kitchen kind', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HouseholdSetupScreen()),
    );

    expect(find.text('Set up your kitchen'), findsOneWidget);
    expect(find.text('Just me'), findsOneWidget);
    expect(find.text('Create a household'), findsOneWidget);
    expect(find.byType(KsBadge), findsOneWidget); // Premium on "joint"

    // Selecting the joint option moves the check mark without throwing.
    await tester.tap(find.text('Create a household'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding screens render in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const SignInScreen()),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const HouseholdSetupScreen()),
    );
    expect(tester.takeException(), isNull);
  });
}
