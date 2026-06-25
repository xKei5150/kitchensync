import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/ks_freshness.dart';

/// A raised surface card — [KsTokens.surfaceRaised] fill, [KsTokens.radius16],
/// hairline [KsTokens.border]. Stretches to its parent's width by default.
class KsCard extends StatelessWidget {
  const KsCard({
    required this.child,
    this.padding = const EdgeInsets.all(KsTokens.space16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: child,
    );
  }
}

/// A label / value row for use inside a [KsCard].
///
/// Two layouts share one widget. Pass an [icon] for the spec's
/// `icon · label · value` row (icon + flexed secondary label + trailing
/// value); omit it for the legacy fixed-width label column. When [color] is
/// set the value renders in that colour at [FontWeight.w600]; [showDot]
/// prefixes a [KsStatusDot] in the icon-less layout.
class KsMetadataRow extends StatelessWidget {
  const KsMetadataRow({
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.showDot = false,
    super.key,
  });

  final String label;
  final String value;

  /// Optional leading glyph. When set, switches to the icon · label · value
  /// layout from "Components I (Primitives)", Cards & metadata rows.
  final IconData? icon;
  final Color? color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final valueColor = color;
    final valueStyle = KsTokens.bodyMedium.copyWith(
      color: valueColor ?? ks.textPrimary,
      fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.w400,
    );

    if (icon != null) {
      return Row(
        children: [
          Icon(icon, size: 15, color: ks.textTertiary),
          const SizedBox(width: KsTokens.space8),
          Expanded(
            child: Text(
              label,
              style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
            ),
          ),
          const SizedBox(width: KsTokens.space8),
          Flexible(
            child: Text(value, style: valueStyle, textAlign: TextAlign.end),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: KsTokens.bodySmall.copyWith(
              color: ks.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (showDot && valueColor != null) ...[
                KsStatusDot(color: valueColor),
                const SizedBox(width: KsTokens.space6),
              ],
              Flexible(child: Text(value, style: valueStyle)),
            ],
          ),
        ),
      ],
    );
  }
}
