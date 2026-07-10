import 'package:kitchensync/core/locale/unit_system.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

/// Formats quantities authored in metric for the household's [UnitSystem].
///
/// In [UnitSystem.metric] this is identity — the amount and unit render as
/// authored, so the default experience is byte-for-byte unchanged. In
/// [UnitSystem.imperial] mass (g, kg) and volume (ml, l) are converted at the
/// display edge; cooking and count units (tbsp, tsp, cup, piece, "tins",
/// "bunch", …) pass through, since they read the same in both systems.
class MeasurementFormatter {
  const MeasurementFormatter(this.system);

  final UnitSystem system;

  // Mass.
  static const double _gramsPerOz = 28.349523125;
  static const double _gramsPerLb = 453.59237;
  // Volume.
  static const double _mlPerFlOz = 29.5735295625;
  static const double _mlPerCup = 236.5882365;

  /// Formats [amount] (quoted in [unit]) for the active system.
  ///
  /// Returns just the number when [unit] is empty, else `"<number> <unit>"`.
  String format(double amount, String unit) {
    final label = unit.trim();
    final definition = _definitionFor(label);
    if (definition != null) {
      return _formatDefinition(amount, definition);
    }

    return _join(_metricNumber(amount), label);
  }

  /// Formats [amount] for a known registry unit without relying on display
  /// text.
  String formatUnit(
    double amount,
    UnitId unit, {
    List<UnitDefinition> localUnitDefinitions = const [],
  }) {
    final definition =
        UnitRegistry.find(unit) ??
        _localDefinitionFor(unit, localUnitDefinitions);
    if (definition == null) {
      return _join(_metricNumber(amount), unit.value);
    }
    return _formatDefinition(amount, definition);
  }

  String _formatDefinition(double amount, UnitDefinition definition) {
    if (system == UnitSystem.metric) {
      final converted = _toMetric(amount, definition);
      if (converted != null) {
        return _join(_metricNumber(converted.$1), converted.$2);
      }
    } else {
      final converted = _toImperial(amount, definition);
      if (converted != null) {
        return _join(_imperialNumber(converted.$1), converted.$2);
      }
    }

    return _join(
      _metricNumber(amount),
      _displayLabel(amount, definition.label, definition.pluralLabel),
    );
  }

  /// Converts a formal imperial amount to metric, or null when the authored
  /// unit already belongs to the metric/neutral display family.
  (double, String)? _toMetric(double amount, UnitDefinition definition) {
    if (definition.family != UnitSystemFamily.imperial) return null;

    switch (definition.dimension) {
      case UnitDimension.mass:
        return _massToMetric(amount * definition.gramsPerUnit!);
      case UnitDimension.volume:
        return _volumeToMetric(amount * definition.millilitersPerUnit!);
      case UnitDimension.count:
      case UnitDimension.cooking:
      case UnitDimension.informal:
        return null;
    }
  }

  /// Converts a formal metric amount to imperial, or null when the unit should
  /// pass through unchanged.
  (double, String)? _toImperial(double amount, UnitDefinition definition) {
    if (definition.family != UnitSystemFamily.metric) return null;

    switch (definition.dimension) {
      case UnitDimension.mass:
        return _massFromGrams(amount * definition.gramsPerUnit!);
      case UnitDimension.volume:
        return _volumeFromMl(amount * definition.millilitersPerUnit!);
      case UnitDimension.count:
      case UnitDimension.cooking:
      case UnitDimension.informal:
        return null;
    }
  }

  (double, String) _massToMetric(double grams) =>
      grams >= 1000 ? (grams / 1000, 'kg') : (grams, 'g');

  (double, String) _volumeToMetric(double ml) =>
      ml >= 1000 ? (ml / 1000, 'l') : (ml, 'ml');

  (double, String) _massFromGrams(double grams) => grams >= _gramsPerLb
      ? (grams / _gramsPerLb, 'lb')
      : (grams / _gramsPerOz, 'oz');

  (double, String) _volumeFromMl(double ml) =>
      ml >= _mlPerCup ? (ml / _mlPerCup, 'cups') : (ml / _mlPerFlOz, 'fl oz');

  String _join(String number, String unit) =>
      unit.isEmpty ? number : '$number $unit';

  static UnitDefinition? _definitionFor(String unit) {
    if (unit.isEmpty) return null;
    try {
      return UnitRegistry.find(UnitId(unit.toLowerCase()));
    } on FormatException {
      return null;
    }
  }

  static UnitDefinition? _localDefinitionFor(
    UnitId unit,
    List<UnitDefinition> localUnitDefinitions,
  ) {
    for (final definition in localUnitDefinitions) {
      if (definition.id == unit) return definition;
    }
    return null;
  }

  static String _displayLabel(
    double amount,
    String label,
    String pluralLabel,
  ) => amount == 1 ? label : pluralLabel;

  /// Authored precision: whole when integral, else up to two trimmed decimals.
  static String _metricNumber(double v) {
    if (v == v.truncateToDouble()) return v.truncate().toString();
    var s = v.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// Converted precision: whole when within 0.05, else one decimal place.
  static String _imperialNumber(double v) {
    if ((v - v.roundToDouble()).abs() < 0.05) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}
