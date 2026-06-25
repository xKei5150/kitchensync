import 'package:flutter/widgets.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Reduced-motion helpers — the runtime side of "movement that yields on
/// request" (KitchenSync — P4 Accessibility States, Screen 24).
///
/// Under the platform reduce-motion setting
/// ([MediaQueryData.disableAnimations], set by iOS "Reduce Motion" / Android
/// "Remove animations"), travelling
/// transforms become cross-fades and durations shorten. Nothing is *removed* —
/// every state change still reads, it just stops travelling.
class KsMotion {
  const KsMotion._();

  /// Whether the user has asked the system to reduce motion.
  ///
  /// Falls back to `false` when there is no ambient [MediaQuery] (bare widget
  /// tests), so motion is the default and reduced motion is opt-in.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// The duration to use for an animation whose full-motion length is [full],
  /// collapsed to [KsTokens.durationFast] (150ms) when reduced motion is on.
  ///
  /// The mapping is deliberately uniform — a 300ms slide and a 500ms rise both
  /// become a 150ms cross-fade — so the whole app yields consistently.
  static Duration duration(BuildContext context, Duration full) =>
      reduced(context) ? KsTokens.durationFast : full;
}

/// Sugar for reading the reduce-motion preference straight off a context.
extension KsMotionContext on BuildContext {
  /// Shorthand for [KsMotion.reduced].
  bool get reduceMotion => KsMotion.reduced(this);
}
