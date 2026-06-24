import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// A circular 44px +/- step button used by [KsQuantityStepper].
///
/// Decrement buttons tint [KsTokens.lowStock]; increment buttons tint
/// [KsTokens.brandPrimary]. Fill is the tint at 10%; the glyph is full.
class KsStepButton extends StatelessWidget {
  const KsStepButton({
    required this.icon,
    this.onTap,
    this.isDecrement = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isDecrement;

  @override
  Widget build(BuildContext context) {
    final color = isDecrement
        ? KsTokens.lowStock
        : context.ksColors.brandPrimary;
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

/// A quantity stepper — minus / value+unit / plus inside a raised card.
///
/// The value uses [KsTokens.displayMedium]; the unit uses
/// [KsTokens.labelMedium] in [KsTokens.textTertiary].
class KsQuantityStepper extends StatelessWidget {
  const KsQuantityStepper({
    required this.qty,
    required this.unit,
    this.onDecrease,
    this.onIncrease,
    super.key,
  });

  final String qty;
  final String unit;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space16,
        vertical: KsTokens.space12,
      ),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          KsStepButton(
            icon: Icons.remove_rounded,
            onTap: onDecrease,
            isDecrement: true,
          ),
          Column(
            children: [
              Text(qty, style: KsTokens.displayMedium),
              const SizedBox(height: KsTokens.space2),
              Text(
                unit,
                style: KsTokens.labelMedium.copyWith(color: ks.textTertiary),
              ),
            ],
          ),
          KsStepButton(icon: Icons.add_rounded, onTap: onIncrease),
        ],
      ),
    );
  }
}
