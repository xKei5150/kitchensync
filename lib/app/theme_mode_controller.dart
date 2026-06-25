import 'package:flutter/material.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

/// Preferences key under which the chosen appearance is stored.
const themeModePrefKey = 'appearance.themeMode';

/// Holds the user's chosen [ThemeMode], persisted across launches.
///
/// Initialised synchronously from [sharedPreferencesProvider] so the first
/// frame already reflects the saved choice. [ThemeMode.system] is the default
/// when nothing has been chosen, matching the platform appearance.
@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _decode(prefs.getString(themeModePrefKey));
  }

  /// Persists [mode] and updates the live theme. No-op when unchanged.
  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(themeModePrefKey, mode.name);
  }

  static ThemeMode _decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
