import 'package:kitchensync/core/locale/unit_system.dart';

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

  /// Formats [amount] (quoted in the metric [unit]) for the active system.
  ///
  /// Returns just the number when [unit] is empty, else `"<number> <unit>"`.
  String format(double amount, String unit) {
    final key = unit.trim().toLowerCase();

    if (system == UnitSystem.imperial) {
      final converted = _toImperial(amount, key);
      if (converted != null) {
        // Converted figures are inexact, so a single decimal reads cleanest.
        return _join(_imperialNumber(converted.$1), converted.$2);
      }
    }

    // Pass-through keeps the authored precision (two-decimal trim), so the
    // metric default is byte-for-byte unchanged.
    return _join(_metricNumber(amount), unit);
  }

  /// Converts a metric mass/volume amount to imperial, or null when [key] is a
  /// unit that should pass through unchanged.
  (double, String)? _toImperial(double amount, String key) {
    switch (key) {
      case 'g':
        return _massFromGrams(amount);
      case 'kg':
        return _massFromGrams(amount * 1000);
      case 'ml':
        return _volumeFromMl(amount);
      case 'l':
        return _volumeFromMl(amount * 1000);
      default:
        return null;
    }
  }

  (double, String) _massFromGrams(double grams) => grams >= _gramsPerLb
      ? (grams / _gramsPerLb, 'lb')
      : (grams / _gramsPerOz, 'oz');

  (double, String) _volumeFromMl(double ml) =>
      ml >= _mlPerCup ? (ml / _mlPerCup, 'cups') : (ml / _mlPerFlOz, 'fl oz');

  String _join(String number, String unit) =>
      unit.isEmpty ? number : '$number $unit';

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
