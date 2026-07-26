import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goldenHousehold = ActiveHouseholdContext(
  id: 'solo-household',
  name: 'Debug kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

Future<Widget> _wrap(ThemeData theme) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Golden widgets do not boot Firebase; preserve the intentional
      // presentation fixture without restoring it in application routing.
      activeHouseholdContextProvider.overrideWithValue(_goldenHousehold),
    ],
    child: MaterialApp(theme: theme, home: const SettingsScreen()),
  );
}

void main() {
  setUpAll(loadAppFonts);

  testGoldens('SettingsScreen — light theme', (tester) async {
    await tester.pumpWidgetBuilder(
      await _wrap(AppTheme.light()),
      surfaceSize: const Size(393, 852),
    );
    await screenMatchesGolden(tester, 'settings_light');
  });

  testGoldens('SettingsScreen — dark theme', (tester) async {
    await tester.pumpWidgetBuilder(
      await _wrap(AppTheme.dark()),
      surfaceSize: const Size(393, 852),
    );
    await screenMatchesGolden(tester, 'settings_dark');
  });
}
