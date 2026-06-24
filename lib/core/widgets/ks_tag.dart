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
    this.color = KsTokens.brandPrimary,
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

  /// The "Low" stock pill.
  factory KsTag.lowStock({KsTagSize size = KsTagSize.sm, Key? key}) =>
      KsTag(label: 'Low', color: KsTokens.lowStock, size: size, key: key);

  /// A neutral alias chip (e.g. "also: scallion").
  factory KsTag.alias(String label, {Key? key}) =>
      KsTag(label: label, tone: KsTagTone.neutral, key: key);

  /// Visible text.
  final String label;

  /// Drives tonal / solid / outline colouring. Ignored by [KsTagTone.neutral].
  final Color color;

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

    final (Color fill, Color textColor, BoxBorder? border) = switch (tone) {
      KsTagTone.tonal => (
        color.withValues(alpha: 0.12),
        color.withValues(alpha: 0.85),
        null,
      ),
      KsTagTone.neutral => (
        KsTokens.neutralSubtle,
        KsTokens.textSecondary,
        Border.all(color: KsTokens.border),
      ),
      KsTagTone.solid => (color, KsTokens.textOnBrand, null),
      KsTagTone.outline => (
        Colors.transparent,
        color.withValues(alpha: 0.9),
        Border.all(color: color.withValues(alpha: 0.55)),
      ),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: Text(label, style: KsTokens.labelSmall.copyWith(color: textColor)),
    );
  }
}
