import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Shared [ButtonStyle] recipes that aren't expressible as a single global
/// theme — chiefly the *destructive* treatment, which carries the theme's
/// [KsColors.danger] accent instead of the brand green.
///
/// From "KitchenSync — Components I (Primitives)", Buttons & actions: the
/// filled destructive ("Mark as waste") and its calmer outlined entry point.
final class KsButtonStyles {
  const KsButtonStyles._();

  /// A filled destructive button — [KsColors.danger] fill, on-brand label.
  static ButtonStyle destructive(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: context.ksColors.danger,
        foregroundColor: KsTokens.textOnBrand,
        disabledBackgroundColor: context.ksColors.disabledFill,
        disabledForegroundColor: context.ksColors.disabledText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space24,
          vertical: KsTokens.space12,
        ),
        textStyle: KsTokens.labelLarge,
      );

  /// A calmer destructive entry point — danger-tinted outline, no fill.
  /// Used where tapping opens a confirmation rather than committing.
  static ButtonStyle destructiveOutline(BuildContext context) {
    final danger = context.ksColors.danger;
    return OutlinedButton.styleFrom(
      foregroundColor: danger,
      side: BorderSide(color: danger.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space24,
        vertical: KsTokens.space12,
      ),
      textStyle: KsTokens.labelLarge,
    );
  }
}
