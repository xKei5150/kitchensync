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

/// A fixed-label / value row for use inside a [KsCard].
///
/// When [color] is set the value renders in that colour at [FontWeight.w600];
/// pass [showDot] to prefix a [KsStatusDot] (e.g. for freshness).
class KsMetadataRow extends StatelessWidget {
  const KsMetadataRow({
    required this.label,
    required this.value,
    this.color,
    this.showDot = false,
    super.key,
  });

  final String label;
  final String value;
  final Color? color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final valueColor = color;
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
              Flexible(
                child: Text(
                  value,
                  style: KsTokens.bodyMedium.copyWith(
                    color: valueColor ?? ks.textPrimary,
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
