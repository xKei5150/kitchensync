import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/locale/app_currency.dart';
import 'package:kitchensync/core/locale/currency_formatter.dart';
import 'package:kitchensync/core/locale/locale_preferences.dart';
import 'package:kitchensync/core/locale/measurement_formatter.dart';
import 'package:kitchensync/core/locale/unit_system.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_preferences_controller.g.dart';

/// Preferences key for the chosen measurement system.
const unitSystemPrefKey = 'locale.unitSystem';

/// Preferences key for the chosen currency (ISO 4217 code).
const currencyPrefKey = 'locale.currency';

/// Holds the household's [LocalePreferences], persisted across launches.
///
/// Initialised synchronously from [sharedPreferencesProvider] so the first
/// frame already reflects the saved choice — mirrors `ThemeModeController`.
@riverpod
class LocalePreferencesController extends _$LocalePreferencesController {
  @override
  LocalePreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return LocalePreferences(
      unitSystem: UnitSystem.decode(prefs.getString(unitSystemPrefKey)),
      currency: AppCurrency.decode(prefs.getString(currencyPrefKey)),
    );
  }

  /// Persists [system] and updates live state. No-op when unchanged.
  Future<void> setUnitSystem(UnitSystem system) async {
    if (system == state.unitSystem) return;
    state = state.copyWith(unitSystem: system);
    await ref
        .read(sharedPreferencesProvider)
        .setString(unitSystemPrefKey, system.name);
  }

  /// Persists [currency] and updates live state. No-op when unchanged.
  Future<void> setCurrency(AppCurrency currency) async {
    if (currency == state.currency) return;
    state = state.copyWith(currency: currency);
    await ref
        .read(sharedPreferencesProvider)
        .setString(currencyPrefKey, currency.code);
  }
}

/// A bundle of formatters derived from the active [LocalePreferences], rebuilt
/// whenever the household changes its units or currency.
class LocaleFormatters {
  const LocaleFormatters({required this.currency, required this.measurement});

  final CurrencyFormatter currency;
  final MeasurementFormatter measurement;
}

/// Presentation-facing formatters that react to the active preferences.
///
/// Widgets watch this rather than the raw controller so a settings change
/// repaints every price and quantity on screen.
@riverpod
LocaleFormatters localeFormatters(Ref ref) {
  final prefs = ref.watch(localePreferencesControllerProvider);
  return LocaleFormatters(
    currency: CurrencyFormatter(prefs.currency),
    measurement: MeasurementFormatter(prefs.unitSystem),
  );
}
