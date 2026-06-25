import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme_mode_controller.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system when nothing is stored', () async {
    final container = await _container({});

    expect(container.read(themeModeControllerProvider), ThemeMode.system);
  });

  test('restores the stored dark choice on build', () async {
    final container = await _container({themeModePrefKey: 'dark'});

    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
  });

  test('falls back to system for an unrecognised stored value', () async {
    final container = await _container({themeModePrefKey: 'sepia'});

    expect(container.read(themeModeControllerProvider), ThemeMode.system);
  });

  test('set() updates live state and persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(themeModeControllerProvider.notifier)
        .set(ThemeMode.light);

    expect(container.read(themeModeControllerProvider), ThemeMode.light);
    expect(prefs.getString(themeModePrefKey), 'light');
  });
}
