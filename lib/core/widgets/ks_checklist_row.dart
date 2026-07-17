import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/ks_dashed.dart';
import 'package:kitchensync/core/widgets/ks_member.dart';

part 'ks_checklist_row_checkbox.dart';

/// The lifecycle of a shopping-list line.
enum ChecklistItemState { toBuy, bought, substituted, unavailable, skipped }

/// A shared, tactile shopping checklist row.
///
/// Five states — to buy · bought · substituted · unavailable · skipped — each
/// reading by checkbox form + text treatment, never colour alone. Premium adds
/// a per-member tick ([memberInitial] + [memberSeat]) so the household sees who
/// grabbed what. From "Components II (Modules)", Shopping checklist row.
///
/// This renders a single row; compose rows in a bordered container and divide
/// them with [KsTokens]-tinted hairlines for the full list.
class KsChecklistRow extends StatelessWidget {
  const KsChecklistRow({
    required this.name,
    required this.state,
    this.quantity,
    this.note,
    this.memberInitial,
    this.memberSeat,
    this.onToggle,
    this.onLongPress,
    this.onAction,
    this.onTap,
    this.isBusy = false,
    this.actionTooltip = 'More item actions',
    super.key,
  });

  final String name;
  final ChecklistItemState state;

  /// Trailing amount shown for the [ChecklistItemState.toBuy] state.
  final String? quantity;

  /// Inline note — the substitution ("got risoni") or the reason it's
  /// unavailable ("couldn't find").
  final String? note;

  /// Member tick — shown for bought / substituted lines when [memberSeat] is
  /// set. Pairs the seat colour with this initial.
  final String? memberInitial;
  final int? memberSeat;

  /// Tap handler for the checkbox.
  final VoidCallback? onToggle;

  /// Optional row action handler, used for secondary checklist states.
  final VoidCallback? onLongPress;

  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final bool isBusy;
  final String actionTooltip;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final opacity = state == ChecklistItemState.skipped ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isBusy ? null : onTap,
        // Keep a long press from falling through to [onTap] on read-only rows.
        // This lets rows remain navigable without making completed/cancelled
        // shopping lists expose mutation actions.
        onLongPress: isBusy
            ? null
            : onLongPress ?? (onTap == null ? null : () {}),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              _Checkbox(state: state, onTap: isBusy ? null : onToggle),
              const SizedBox(width: 13),
              Expanded(child: _label(context)),
              ..._trailing(context, ks),
              if (isBusy) ...[
                const SizedBox(width: KsTokens.space10),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ] else if (onAction != null) ...[
                const SizedBox(width: KsTokens.space4),
                IconButton(
                  tooltip: actionTooltip,
                  onPressed: isBusy ? null : onAction,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context) {
    final ks = context.ksColors;
    final struck = state == ChecklistItemState.bought;
    final nameColor = switch (state) {
      ChecklistItemState.bought => ks.textTertiary,
      ChecklistItemState.skipped => ks.textSecondary,
      _ => ks.textPrimary,
    };

    final nameText = Text(
      name,
      style: KsTokens.bodyMedium.copyWith(
        color: nameColor,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 1.3,
        decoration: struck ? TextDecoration.lineThrough : null,
      ),
    );

    if (note == null) return nameText;

    final (Color noteColor, IconData? noteIcon) = switch (state) {
      ChecklistItemState.substituted => (ks.info, Icons.swap_horiz),
      ChecklistItemState.unavailable => (ks.danger, null),
      _ => (ks.textTertiary, null),
    };

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: KsTokens.space8,
      children: [
        nameText,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (noteIcon != null) ...[
              Icon(noteIcon, size: 12, color: noteColor),
              const SizedBox(width: KsTokens.space4),
            ],
            Text(
              note!,
              style: KsTokens.labelSmall.copyWith(
                color: noteColor,
                fontSize: 11,
                letterSpacing: 0,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _trailing(BuildContext context, KsColors ks) {
    final showTick =
        memberSeat != null &&
        (state == ChecklistItemState.bought ||
            state == ChecklistItemState.substituted);
    if (showTick) {
      return [
        const SizedBox(width: KsTokens.space10),
        KsMemberAvatar(
          initial: memberInitial ?? '',
          seat: memberSeat!,
          size: 22,
        ),
      ];
    }
    if (state == ChecklistItemState.toBuy && quantity != null) {
      return [
        const SizedBox(width: KsTokens.space10),
        Text(
          quantity!,
          style: KsTokens.labelMedium.copyWith(
            color: ks.textTertiary,
            letterSpacing: 0,
            height: 1.3,
          ),
        ),
      ];
    }
    if (state == ChecklistItemState.skipped) {
      return [
        const SizedBox(width: KsTokens.space10),
        Text(
          'skipped',
          style: KsTokens.labelSmall.copyWith(
            color: ks.textTertiary,
            fontSize: 11,
            letterSpacing: 0,
            height: 1.2,
          ),
        ),
      ];
    }
    return const [];
  }
}
