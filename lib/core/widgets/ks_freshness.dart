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
        ? context.ksColors.border
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

/// Freshness icon + relative-expiry label (e.g. "2 days left").
///
/// Leads with the per-state [FreshnessX.icon] — not a bare colour dot — so the
/// state is legible without relying on hue. The redundant icon + day-count is
/// the accessible pairing from "Components I (Primitives)", Freshness.
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
    final isUnknown = freshness == Freshness.unknown;
    final color = isUnknown
        ? context.ksColors.textTertiary
        : freshness.color.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(freshness.icon, size: 14, color: color),
        const SizedBox(width: KsTokens.space4),
        Text(
          label,
          style: KsTokens.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
