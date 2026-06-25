import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/ks_badge.dart';
import 'package:kitchensync/core/widgets/ks_dashed.dart';

/// One day in a [KsMenuSetCard] preview strip — a weekday letter and the
/// category hues of that day's planned meals (one bar per meal).
@immutable
class KsMenuDay {
  const KsMenuDay({required this.weekday, required this.dishColors});

  /// Single-letter weekday header (M, T, W…).
  final String weekday;

  /// Category hue per meal on this day. The first tints the block; each adds a
  /// filled bar at the foot.
  final List<Color> dishColors;
}

/// A Menu Set card — a saved week, carrying a 7-day preview strip that is
/// deliberately unlike a recipe card so the two never blur.
///
/// From "Components II (Modules)", Menu Set card & slot editor (a premium
/// feature). Reuses [KsBadge.premium] for the tier marker.
class KsMenuSetCard extends StatelessWidget {
  const KsMenuSetCard({
    required this.title,
    required this.meta,
    required this.days,
    this.premium = true,
    this.onApply,
    this.onDuplicate,
    super.key,
  });

  final String title;

  /// Summary line, e.g. "7 days · 14 meals · £61".
  final String meta;
  final List<KsMenuDay> days;
  final bool premium;
  final VoidCallback? onApply;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
        boxShadow: KsTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: KsTokens.headlineMedium.copyWith(
                        color: ks.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 19,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: KsTokens.labelSmall.copyWith(
                        color: ks.textTertiary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (premium) ...[
                const SizedBox(width: KsTokens.space8),
                const KsBadge.premium(),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _PreviewColumn(day: day),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: ks.brandPrimary,
                    foregroundColor: KsTokens.textOnBrand,
                    textStyle: KsTokens.labelMedium.copyWith(letterSpacing: 0),
                    padding: const EdgeInsets.symmetric(
                      vertical: KsTokens.space10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KsTokens.radius8),
                    ),
                  ),
                  child: const Text('Apply to calendar'),
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              OutlinedButton(
                onPressed: onDuplicate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ks.textPrimary,
                  side: BorderSide(color: ks.borderStrong),
                  textStyle: KsTokens.labelMedium.copyWith(letterSpacing: 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KsTokens.space12,
                    vertical: KsTokens.space10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KsTokens.radius8),
                  ),
                ),
                child: const Text('Duplicate'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({required this.day});

  final KsMenuDay day;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    final primary = day.dishColors.isEmpty ? ks.border : day.dishColors.first;
    final blockBg = Color.lerp(ks.surfaceBase, primary, isDark ? 0.22 : 0.28)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          day.weekday,
          style: KsTokens.labelSmall.copyWith(
            color: ks.textTertiary,
            fontSize: 8,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: blockBg,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final c in day.dishColors) ...[
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? c : Color.lerp(c, Colors.black, 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (c != day.dishColors.last) const SizedBox(height: 2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One day column in a [KsMenuSlotEditor].
@immutable
class KsMenuSlot {
  const KsMenuSlot({
    required this.weekday,
    this.entries = const [],
    this.isDropTarget = false,
  });

  /// Short weekday label (Mon, Tue…).
  final String weekday;
  final List<KsMenuSlotEntry> entries;

  /// When true the slot shows the dashed "Drop here" affordance.
  final bool isDropTarget;
}

/// A recipe placed into a day slot — a label with a category hue.
@immutable
class KsMenuSlotEntry {
  const KsMenuSlotEntry({required this.label, required this.color});

  final String label;
  final Color color;
}

/// The mini-calendar slot editor — drop recipes into day slots to build a
/// week. Shows a dashed drop target on the active day, and an optional
/// "dragging" affordance for the recipe currently in hand.
///
/// From "Components II (Modules)", Menu Set card & slot editor.
class KsMenuSlotEditor extends StatelessWidget {
  const KsMenuSlotEditor({
    required this.slots,
    this.draggingLabel,
    this.draggingColor,
    super.key,
  });

  final List<KsMenuSlot> slots;

  /// When set, renders the "Dragging: …" affordance below the grid.
  final String? draggingLabel;
  final Color? draggingColor;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final slot in slots)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SlotColumn(slot: slot),
                ),
              ),
          ],
        ),
        if (draggingLabel != null) ...[
          const SizedBox(height: KsTokens.space16),
          Row(
            children: [
              Text(
                'Dragging:',
                style: KsTokens.bodySmall.copyWith(
                  color: ks.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: KsTokens.space10),
              Transform.rotate(
                angle: -0.035,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: ks.surfaceRaised,
                    borderRadius: BorderRadius.circular(KsTokens.radius8),
                    border: Border.all(color: ks.brandPrimary),
                    boxShadow: KsTokens.elevation2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: (draggingColor ?? ks.brandPrimary).withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(KsTokens.radius4),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        draggingLabel!,
                        style: KsTokens.labelMedium.copyWith(
                          color: ks.textPrimary,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SlotColumn extends StatelessWidget {
  const _SlotColumn({required this.slot});

  final KsMenuSlot slot;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          slot.weekday,
          style: KsTokens.labelSmall.copyWith(
            color: ks.textTertiary,
            fontSize: 10,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        const SizedBox(height: KsTokens.space6),
        if (slot.isDropTarget)
          KsDashedBorder(
            color: ks.brandPrimary,
            radius: KsTokens.radius10,
            strokeWidth: 2,
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(KsTokens.space6),
              decoration: BoxDecoration(
                color: ks.brandPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(KsTokens.radius10),
              ),
              child: Text(
                'Drop here',
                textAlign: TextAlign.center,
                style: KsTokens.labelSmall.copyWith(
                  color: ks.brandPrimary,
                  fontSize: 10,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(KsTokens.space6),
            decoration: BoxDecoration(
              color: ks.surfaceRaised,
              borderRadius: BorderRadius.circular(KsTokens.radius10),
              border: Border.all(color: ks.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in slot.entries) ...[
                  _SlotChip(entry: entry),
                  if (entry != slot.entries.last)
                    const SizedBox(height: KsTokens.space4),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.entry});

  final KsMenuSlotEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: KsTokens.space4,
      ),
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(KsTokens.radius4),
      ),
      child: Text(
        entry.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KsTokens.labelSmall.copyWith(
          color: entry.color,
          fontSize: 10,
          letterSpacing: 0,
          height: 1.2,
        ),
      ),
    );
  }
}
