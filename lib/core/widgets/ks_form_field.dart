import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

part 'ks_form_field_error.dart';

/// The error-summary banner shown at the top of a form once a submit attempt
/// surfaces validation problems — a count, a danger glyph, and a pointer to the
/// highlighted fields below.
///
/// From "KitchenSync — P4 Accessibility States", Screen 25 ("Two things need a
/// look · Fix the highlighted fields below to save"). The count is spoken in
/// the house voice; the [errorCount] drives the headline.
class KsErrorSummary extends StatelessWidget {
  const KsErrorSummary({
    required this.errorCount,
    this.message = 'Fix the highlighted fields below to save.',
    super.key,
  });

  final int errorCount;
  final String message;

  String get _headline => errorCount == 1
      ? 'One thing needs a look'
      : '$errorCount things need a look';

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final danger = ks.danger;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space12,
          vertical: KsTokens.space12,
        ),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            danger.withValues(alpha: 0.09),
            ks.surfaceRaised,
          ),
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          border: Border.all(color: danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 17, color: danger),
            ),
            const SizedBox(width: KsTokens.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline,
                    style: KsTokens.labelMedium.copyWith(
                      color: danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space2),
                  Text(
                    message,
                    style: KsTokens.bodySmall.copyWith(
                      color: ks.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small uppercase caps label that sits above every input on the graduated
/// form surfaces ("Add to pantry", "Create ingredient").
///
/// From "KitchenSync — P3 Accessibility & Forms": `.fld-label` — 10px, 600,
/// 0.6px tracking, tertiary ink.
class KsFieldLabel extends StatelessWidget {
  const KsFieldLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KsTokens.space8),
      child: Text(
        text.toUpperCase(),
        style: KsTokens.labelSmall.copyWith(
          color: color ?? context.ksColors.textTertiary,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A selectable pill used for the category / section / storage / unit rows on
/// the form surfaces. Selected pills carry their [color] as a tonal fill plus a
/// solid colour border and a leading tick; the rest sit on a hairline outline.
///
/// Pairs colour with a glyph (tick when selected, optional leading [dotColor])
/// so selection never travels by hue alone — the §9 accessibility rule. The
/// 44pt minimum height keeps it inside the touch-target floor.
///
/// From "KitchenSync — P3 Accessibility & Forms", the category & storage chips.
class KsSelectChip extends StatelessWidget {
  const KsSelectChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.color,
    this.dotColor,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Accent for the selected fill / border / tick. Defaults to the brand green.
  final Color? color;

  /// Optional leading dot (e.g. the category hue) shown in both states.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final enabled = onTap != null;
    final accent = color ?? ks.brandPrimary;
    final fill = !enabled
        ? ks.disabledFill
        : selected
        ? Color.alphaBlend(accent.withValues(alpha: 0.15), ks.surfaceRaised)
        : ks.surfaceRaised;
    final borderColor = !enabled
        ? ks.border
        : selected
        ? accent
        : ks.borderStrong;
    final textColor = !enabled
        ? ks.disabledText
        : selected
        ? accent
        : ks.textSecondary;
    final indicatorColor = enabled ? accent : ks.disabledText;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(KsTokens.radius8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: KsTokens.space12,
              vertical: KsTokens.space10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KsTokens.radius8),
              border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: KsTokens.space6),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: indicatorColor,
                    ),
                  )
                else if (dotColor != null)
                  Padding(
                    padding: const EdgeInsets.only(right: KsTokens.space6),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: enabled ? dotColor : ks.disabledText,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Text(
                  label,
                  style: KsTokens.labelMedium.copyWith(
                    color: textColor,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
