import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

/// Visual weight of a [KsTag].
///
/// * [sm] — radius 4, padding 6×2 (mini tags on dense list subtitles).
/// * [md] — radius 6, padding 8×3 (category / info tags on detail surfaces).
enum KsTagSize { sm, md }

/// Fill / text treatment of a [KsTag].
enum KsTagTone { tonal, neutral, solid, outline }

/// A small label — category, low-stock, alias, or info chip.
///
/// Unifies the previously duplicated `_CategoryTag` (×2), `_InfoTag`,
/// `_MiniTag`, and `_AliasTag` into one primitive with consistent padding,
/// radii, and colour treatment. Tonal tags use a `color@12%` fill with
/// `color@85%` text, typeset in [KsTokens.labelSmall].
class KsTag extends StatelessWidget {
  const KsTag({
    required this.label,
    this.color,
    this.icon,
    this.size = KsTagSize.md,
    this.tone = KsTagTone.tonal,
    super.key,
  });

  /// A tonal category tag, coloured by the ingredient [category].
  factory KsTag.category(
    IngredientCategory category, {
    KsTagSize size = KsTagSize.md,
    Key? key,
  }) =>
      KsTag(label: category.name, color: category.color, size: size, key: key);

  /// The "Low" stock pill — leads with a down-arrow so low stock reads
  /// without relying on the brown tint alone (accessibility).
  factory KsTag.lowStock({KsTagSize size = KsTagSize.sm, Key? key}) => KsTag(
    label: 'Low',
    color: KsTokens.lowStock,
    icon: Icons.south_rounded,
    size: size,
    key: key,
  );

  /// A neutral alias chip (e.g. "also: scallion").
  factory KsTag.alias(String label, {Key? key}) =>
      KsTag(label: label, tone: KsTagTone.neutral, key: key);

  /// Visible text.
  final String label;

  /// Drives tonal / solid / outline colouring. Ignored by [KsTagTone.neutral].
  /// Defaults to the theme's brand green when null.
  final Color? color;

  /// Optional leading glyph, tinted to match the label.
  final IconData? icon;

  /// Padding + radius preset.
  final KsTagSize size;

  /// Fill + text treatment.
  final KsTagTone tone;

  @override
  Widget build(BuildContext context) {
    final radius = switch (size) {
      KsTagSize.sm => KsTokens.radius4,
      KsTagSize.md => KsTokens.radius6,
    };
    final padding = switch (size) {
      KsTagSize.sm => const EdgeInsets.symmetric(
        horizontal: KsTokens.space6,
        vertical: KsTokens.space2,
      ),
      KsTagSize.md => const EdgeInsets.symmetric(
        horizontal: KsTokens.space8,
        vertical: KsTokens.space3,
      ),
    };

    final ks = context.ksColors;
    final base = color ?? ks.brandPrimary;
    // Bright category pastels (dairy yellow especially) wash out when used raw
    // as label text; clamp them to a legible ink while keeping the soft tint.
    final ink = base.readableInk(Theme.of(context).brightness);

    final (Color fill, Color textColor, BoxBorder? border) = switch (tone) {
      KsTagTone.tonal => (base.withValues(alpha: 0.12), ink, null),
      KsTagTone.neutral => (
        ks.neutralSubtle,
        ks.textSecondary,
        Border.all(color: ks.border),
      ),
      KsTagTone.solid => (base, KsTokens.textOnBrand, null),
      KsTagTone.outline => (
        Colors.transparent,
        ink,
        Border.all(color: ink.withValues(alpha: 0.55)),
      ),
    };

    final iconSize = size == KsTagSize.sm ? 11.0 : 13.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            const SizedBox(width: KsTokens.space2),
          ],
          Text(label, style: KsTokens.labelSmall.copyWith(color: textColor)),
        ],
      ),
    );
  }
}
