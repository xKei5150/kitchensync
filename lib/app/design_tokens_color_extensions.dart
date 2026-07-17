part of 'design_tokens.dart';

/// Ergonomic access to the active [KsColors]; falls back to [KsColors.light]
/// when no extension is registered (e.g. a bare [MaterialApp] in a test).
extension BuildContextKsColors on BuildContext {
  KsColors get ksColors =>
      Theme.of(this).extension<KsColors>() ?? KsColors.light;
}

/// Derives a legible foreground from a brand/category hue for a surface of a
/// given brightness, preserving hue + saturation while clamping lightness.
extension ReadableInk on Color {
  Color readableInk(Brightness brightness) {
    final hsl = HSLColor.fromColor(this);
    final lightness = brightness == Brightness.dark
        ? (hsl.lightness < 0.62 ? 0.72 : hsl.lightness)
        : (hsl.lightness > 0.42 ? 0.38 : hsl.lightness);
    return hsl.withLightness(lightness).toColor();
  }
}
