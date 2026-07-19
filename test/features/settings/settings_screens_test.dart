import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/app/theme_mode_controller.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/settings/presentation/screens/premium_screen.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(
  Widget child, {
  Map<String, Object> prefs = const {},
  ThemeData? theme,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(instance),
      ...overrides,
    ],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: child),
  );
}

class _FakePremiumUpgradeController extends PremiumUpgradeController {
  _FakePremiumUpgradeController({this.completion, this.failure})
    : super(auth: null, activeHousehold: null);

  final Completer<void>? completion;
  final Object? failure;
  PremiumPlan? startedPlan;

  @override
  Future<void> startTrial({required PremiumPlan plan}) async {
    startedPlan = plan;
    final failure = this.failure;
    if (failure != null) {
      if (failure is Error) throw failure;
      if (failure is Exception) throw failure;
      throw StateError(failure.toString());
    }
    await completion?.future;
  }
}

class _FakeSignOutController extends SettingsSignOutController {
  _FakeSignOutController(this.prefs) : super(auth: null, preferences: prefs);

  final SharedPreferences prefs;
  bool called = false;

  @override
  Future<void> signOut() async {
    called = true;
    await prefs.remove(skipHouseholdSetupPrefKey);
  }
}

class _FakeProfileController extends SettingsProfileController {
  _FakeProfileController() : super(auth: null, db: null);

  String? updatedName;

  @override
  Future<void> updateDisplayName(String rawName) async {
    updatedName = rawName.trim();
  }
}

void main() {
  testWidgets('SettingsScreen shows the profile, premium banner and list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Try Premium'), findsOneWidget);
    expect(find.text('Household & roles'), findsOneWidget);
    expect(find.text('Switch kitchen'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders and edits the active profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _FakeProfileController();
    const profile = SettingsProfile(
      userId: 'user-1',
      displayName: 'Sam Rivera',
      email: 'sam@example.test',
      roleLabel: 'Cook',
      isEditable: true,
    );

    await tester.pumpWidget(
      await _wrap(
        const SettingsScreen(),
        overrides: [
          settingsProfileProvider.overrideWith((ref) => Stream.value(profile)),
          settingsProfileControllerProvider.overrideWithValue(controller),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sam Rivera'), findsOneWidget);
    expect(find.text('sam@example.test · Cook'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Samira Rivera');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(controller.updatedName, 'Samira Rivera');
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('profile editor rejects an empty display name', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const profile = SettingsProfile(
      userId: 'user-1',
      displayName: 'Sam Rivera',
      roleLabel: 'Admin',
      isEditable: true,
    );

    await tester.pumpWidget(
      await _wrap(
        const SettingsScreen(),
        overrides: [
          settingsProfileProvider.overrideWith((ref) => Stream.value(profile)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' ');
    await tester.tap(find.text('Save profile'));
    await tester.pump();

    expect(find.text('Name must have at least 2 characters.'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Sign out clears debug household skip and routes to onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({skipHouseholdSetupPrefKey: true});
    final prefs = await SharedPreferences.getInstance();
    final signOut = _FakeSignOutController(prefs);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(body: Text('Onboarding')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsSignOutControllerProvider.overrideWithValue(signOut),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(signOut.called, isTrue);
    expect(prefs.getBool(skipHouseholdSetupPrefKey), isNull);
    expect(find.text('Onboarding'), findsOneWidget);
  });

  testWidgets('Appearance row reflects the stored choice', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await _wrap(
        const SettingsScreen(),
        prefs: {themeModePrefKey: 'dark'},
        theme: AppTheme.dark(),
      ),
    );

    // Trailing value on the Appearance row.
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('picking Dark from the Appearance sheet updates and persists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );

    // Default appearance is Auto.
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    // The sheet offers the three modes.
    expect(find.text('Light'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Choice is reflected in the row and written to preferences.
    expect(find.text('Dark'), findsOneWidget);
    expect(prefs.getString(themeModePrefKey), 'dark');
  });

  testWidgets('Units & locale row shows the default Metric · £', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const SettingsScreen()));

    expect(find.text('Metric · £'), findsOneWidget);
  });

  testWidgets('Units & locale row reflects a stored imperial/USD choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await _wrap(
        const SettingsScreen(),
        prefs: {unitSystemPrefKey: 'imperial', currencyPrefKey: 'USD'},
      ),
    );

    expect(find.text(r'Imperial · $'), findsOneWidget);
  });

  testWidgets('picking Imperial and USD from the sheet updates and persists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Metric · £'), findsOneWidget);

    await tester.tap(find.text('Units & locale'));
    await tester.pumpAndSettle();

    // The sheet offers both systems and the currencies.
    expect(find.text('Imperial'), findsOneWidget);
    expect(find.text('US dollar'), findsOneWidget);

    await tester.tap(find.text('Imperial'));
    await tester.pump();
    await tester.tap(find.text('US dollar'));
    await tester.pump();

    // Both choices persisted with their canonical encodings.
    expect(prefs.getString(unitSystemPrefKey), 'imperial');
    expect(prefs.getString(currencyPrefKey), 'USD');

    // The row behind the sheet now reads the new summary.
    expect(find.text(r'Imperial · $'), findsOneWidget);
  });

  testWidgets('PremiumScreen lists benefits and toggles the plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const PremiumScreen()));

    expect(find.text('KitchenSync Premium'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    expect(find.textContaining('then £29/year'), findsOneWidget);

    // Switching to Monthly updates the fine print.
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    expect(find.textContaining('then £3.99/month'), findsOneWidget);
  });

  testWidgets('PremiumScreen starts a household trial for the selected plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final upgradeController = _FakePremiumUpgradeController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          premiumUpgradeControllerProvider.overrideWithValue(upgradeController),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PremiumScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pump();

    expect(upgradeController.startedPlan, PremiumPlan.monthly);
    expect(
      find.text('Premium trial started for this household.'),
      findsOneWidget,
    );
  });

  testWidgets('PremiumScreen disables trial submission while it is pending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final completion = Completer<void>();
    final upgradeController = _FakePremiumUpgradeController(
      completion: completion,
    );

    await tester.pumpWidget(
      await _wrap(
        const PremiumScreen(),
        overrides: [
          premiumUpgradeControllerProvider.overrideWithValue(upgradeController),
        ],
      ),
    );
    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pump();

    expect(find.text('Starting...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    completion.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Premium trial started for this household.'),
      findsOneWidget,
    );
  });

  testWidgets('PremiumScreen restores the trial action after an error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final upgradeController = _FakePremiumUpgradeController(
      failure: StateError('service unavailable'),
    );

    await tester.pumpWidget(
      await _wrap(
        const PremiumScreen(),
        overrides: [
          premiumUpgradeControllerProvider.overrideWithValue(upgradeController),
        ],
      ),
    );
    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not start trial:'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('Settings screens render in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(const SettingsScreen(), theme: AppTheme.dark()),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      await _wrap(const PremiumScreen(), theme: AppTheme.dark()),
    );
    expect(tester.takeException(), isNull);
  });
}
