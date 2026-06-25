import 'package:flutter/foundation.dart';
import 'package:kitchensync/core/locale/app_currency.dart';
import 'package:kitchensync/core/locale/unit_system.dart';

/// The household's units-and-locale choices, persisted across launches.
@immutable
class LocalePreferences {
  const LocalePreferences({required this.unitSystem, required this.currency});

  /// The defaults applied when nothing has been chosen — metric and pounds,
  /// matching the design's original copy so first launch looks unchanged.
  static const fallback = LocalePreferences(
    unitSystem: UnitSystem.metric,
    currency: AppCurrency.gbp,
  );

  final UnitSystem unitSystem;
  final AppCurrency currency;

  /// Trailing summary for the settings row, e.g. `Metric · £`.
  String get summary => '${unitSystem.label} · ${currency.symbol}';

  LocalePreferences copyWith({UnitSystem? unitSystem, AppCurrency? currency}) =>
      LocalePreferences(
        unitSystem: unitSystem ?? this.unitSystem,
        currency: currency ?? this.currency,
      );

  @override
  bool operator ==(Object other) =>
      other is LocalePreferences &&
      other.unitSystem == unitSystem &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(unitSystem, currency);
}
