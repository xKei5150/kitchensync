import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// The 4px left-edge freshness accent on a pantry tile.
///
/// Resolves [Freshness.unknown] to a neutral [KsTokens.border] so unknown
/// items don't read as a freshness state.
class KsFreshnessBar extends StatelessWidget {
  const KsFreshnessBar({required this.freshness, super.key});

  final Freshness freshness;

  @override
  Widget build(BuildContext context) {
    final color = freshness == Freshness.unknown
        ? KsTokens.border
        : freshness.color;

    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(KsTokens.radius16),
          bottomLeft: Radius.circular(KsTokens.radius16),
        ),
      ),
    );
  }
}

/// A small filled status dot.
class KsStatusDot extends StatelessWidget {
  const KsStatusDot({required this.color, this.size = 6, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Freshness dot + relative-expiry label (e.g. "2 days left").
class KsExpiryBadge extends StatelessWidget {
  const KsExpiryBadge({
    required this.freshness,
    required this.label,
    super.key,
  });

  final Freshness freshness;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = freshness.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KsStatusDot(color: color),
        const SizedBox(width: KsTokens.space6),
        Text(
          label,
          style: KsTokens.bodySmall.copyWith(
            color: freshness == Freshness.unknown
                ? KsTokens.textTertiary
                : color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
