import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/locale/app_currency.dart';
import 'package:kitchensync/core/locale/locale_preferences.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/locale/unit_system.dart';
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

  test('defaults to metric and GBP when nothing is stored', () async {
    final container = await _container({});

    expect(
      container.read(localePreferencesControllerProvider),
      LocalePreferences.fallback,
    );
  });

  test('restores stored unit system and currency', () async {
    final container = await _container({
      unitSystemPrefKey: 'imperial',
      currencyPrefKey: 'USD',
    });

    final prefs = container.read(localePreferencesControllerProvider);
    expect(prefs.unitSystem, UnitSystem.imperial);
    expect(prefs.currency, AppCurrency.usd);
  });

  test('falls back for unrecognised stored values', () async {
    final container = await _container({
      unitSystemPrefKey: 'cubits',
      currencyPrefKey: 'XYZ',
    });

    expect(
      container.read(localePreferencesControllerProvider),
      LocalePreferences.fallback,
    );
  });

  test('setUnitSystem updates live state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(localePreferencesControllerProvider.notifier)
        .setUnitSystem(UnitSystem.imperial);

    expect(
      container.read(localePreferencesControllerProvider).unitSystem,
      UnitSystem.imperial,
    );
    expect(prefs.getString(unitSystemPrefKey), 'imperial');
  });

  test('setCurrency updates live state and persists the ISO code', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(localePreferencesControllerProvider.notifier)
        .setCurrency(AppCurrency.eur);

    expect(
      container.read(localePreferencesControllerProvider).currency,
      AppCurrency.eur,
    );
    expect(prefs.getString(currencyPrefKey), 'EUR');
  });

  test('localeFormatters reflects the active preferences', () async {
    final container = await _container({
      unitSystemPrefKey: 'imperial',
      currencyPrefKey: 'USD',
    });

    final formatters = container.read(localeFormattersProvider);
    expect(formatters.currency.format(3.20), r'$3.20');
    expect(formatters.measurement.format(100, 'g'), '3.5 oz');
  });
}
