import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Visual kind of a [KsBadge].
enum KsBadgeKind {
  /// A proposed-token / experimental marker — amber accent, lightning glyph.
  proposed,

  /// A premium-feature marker — solid brand fill, star glyph.
  premium,

  /// A caller-coloured status pill (e.g. "New", "Low") — tonal or solid.
  custom,
}

/// A pill badge — a small, uppercased status / feature marker that reads at a
/// glance without shouting.
///
/// Distinct from a `KsTag`: badges are fully-rounded ([KsTokens.radiusFull]),
/// uppercased, and heavier (700). They mark *meta-status* — a proposed token,
/// a premium feature, a "New" flag — rather than an item's category or stock.
/// From "KitchenSync — Components I (Primitives)", Tags & badges.
class KsBadge extends StatelessWidget {
  const KsBadge.custom({
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
    super.key,
  }) : kind = KsBadgeKind.custom;

  /// A "proposed token" badge — amber accent fill with a lightning glyph.
  const KsBadge.proposed({this.label = 'Proposed', super.key})
    : kind = KsBadgeKind.proposed,
      color = null,
      icon = null,
      solid = false;

  /// A premium-feature badge — solid brand fill with a star glyph.
  const KsBadge.premium({this.label = 'Premium', super.key})
    : kind = KsBadgeKind.premium,
      color = null,
      icon = null,
      solid = false;

  /// Badge text. Rendered uppercased.
  final String label;

  /// Which preset this badge renders as.
  final KsBadgeKind kind;

  /// Drives the fill/text for [KsBadgeKind.custom]. Ignored otherwise.
  final Color? color;

  /// Optional leading glyph for [KsBadgeKind.custom]. Presets pick their own.
  final IconData? icon;

  /// When true a custom badge fills solid (text on-brand) instead of tonal.
  final bool solid;

  // Proposed-badge text colours read straight from the component spec
  // (Tags & badges): a dark amber on light, a lifted amber on dark — both
  // chosen for ≥4.5:1 on the accent tint.
  static const Color _proposedTextLight = Color(0xFF8A6300);
  static const Color _proposedTextDark = Color(0xFFFFD27A);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;

    final (
      Color fill,
      Color textColor,
      BoxBorder? border,
      IconData? glyph,
    ) = switch (kind) {
      KsBadgeKind.proposed => (
        KsTokens.brandAccent.withValues(alpha: isDark ? 0.18 : 0.16),
        isDark ? _proposedTextDark : _proposedTextLight,
        Border.all(color: KsTokens.brandAccent.withValues(alpha: 0.4)),
        Icons.bolt,
      ),
      KsBadgeKind.premium => (
        isDark ? KsTokens.brandAccent : KsTokens.brandPrimaryDark,
        isDark ? KsTokens.textPrimary : KsTokens.textOnBrand,
        null,
        Icons.star_rounded,
      ),
      KsBadgeKind.custom =>
        solid
            ? (color ?? ks.brandPrimary, KsTokens.textOnBrand, null, icon)
            : (
                (color ?? ks.brandPrimary).withValues(alpha: 0.14),
                color ?? ks.brandPrimary,
                null,
                icon,
              ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space10,
        vertical: KsTokens.space4,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 12, color: textColor),
            const SizedBox(width: KsTokens.space4),
          ],
          Text(
            label.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
