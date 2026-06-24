import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// A centered empty / no-results state.
///
/// Tinted icon circle (`color@10%` fill, `color@60%` glyph), a Fraunces
/// [TextTheme.headlineMedium] title marked as a semantic header, a
/// [TextTheme.bodyMedium] subtitle, and an optional call-to-action below.
class KsEmptyState extends StatelessWidget {
  const KsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = KsTokens.brandPrimary,
    this.circleSize = 80,
    this.iconSize = 36,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final double circleSize;
  final double iconSize;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ks = context.ksColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KsTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: color.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: KsTokens.space20),
            Semantics(
              header: true,
              child: Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  color: ks.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: KsTokens.space8),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(color: ks.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: KsTokens.space24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
