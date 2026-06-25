import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.1 contrast maths, ported from the Phase-5 design verification surface
/// ("KitchenSync — P3 Accessibility & Forms") so the same ratios the design
/// proved in HTML can be re-proved at runtime against the live token values.
///
/// Pure Dart — no Flutter widget dependency — so it stays unit-testable.

/// Relative luminance of [color] per the WCAG 2.1 definition.
///
/// Channels are linearised (the sRGB gamma curve) then weighted
/// 0.2126 R + 0.7152 G + 0.0722 B. The alpha channel is ignored: contrast is
/// only meaningful between fully-resolved opaque colours, so callers must
/// alpha-composite tints onto their surface first.
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  final r = channel((color.r * 255.0).round() / 255.0);
  final g = channel((color.g * 255.0).round() / 255.0);
  final b = channel((color.b * 255.0).round() / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// The WCAG contrast ratio between [a] and [b], in the range 1:1 … 21:1.
///
/// Symmetric in its arguments — `(L_hi + 0.05) / (L_lo + 0.05)`.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The pass/fail band a contrast ratio lands in, by WCAG normal-text rules.
///
/// AAA ≥ 7:1, AA ≥ 4.5:1, "AA Large" ≥ 3:1 (only sufficient for ≥24px or
/// ≥18.66px-bold text), and Fail below 3:1.
enum WcagVerdict {
  aaa,
  aa,
  aaLarge,
  fail;

  /// Classify [ratio] using the normal-text thresholds.
  static WcagVerdict forRatio(double ratio) {
    if (ratio >= 7.0) return WcagVerdict.aaa;
    if (ratio >= 4.5) return WcagVerdict.aa;
    if (ratio >= 3.0) return WcagVerdict.aaLarge;
    return WcagVerdict.fail;
  }

  /// Whether this verdict clears AA for normal body text.
  bool get passesAa => this == WcagVerdict.aaa || this == WcagVerdict.aa;

  /// Short uppercase label for the audit table badge.
  String get label => switch (this) {
    WcagVerdict.aaa => 'AAA',
    WcagVerdict.aa => 'AA',
    WcagVerdict.aaLarge => 'AA Large',
    WcagVerdict.fail => 'Fail',
  };
}
