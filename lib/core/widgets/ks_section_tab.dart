import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// A pantry section selector tab with animated selected / unselected states.
///
/// Selected: filled with [color], [KsTokens.textOnBrand] label. Unselected:
/// [KsTokens.surfaceRaised] fill, hairline border, [KsTokens.textPrimary]
/// label and a `color@70%` glyph. Transitions over [KsTokens.durationMedium].
class KsSectionTab extends StatelessWidget {
  const KsSectionTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: AnimatedContainer(
          duration: KsTokens.durationMedium,
          curve: KsTokens.curveStandard,
          padding: const EdgeInsets.symmetric(
            horizontal: KsTokens.space16,
            vertical: KsTokens.space10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? color : KsTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: isSelected ? color : KsTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? KsTokens.textOnBrand
                    : color.withValues(alpha: 0.7),
              ),
              const SizedBox(width: KsTokens.space8),
              Text(
                label,
                style: KsTokens.labelLarge.copyWith(
                  color: isSelected
                      ? KsTokens.textOnBrand
                      : KsTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
