import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/ks_dashed.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';

/// A circular member avatar carrying the member's [seat] tick colour and a
/// single uppercased [initial].
///
/// The tick hue is resolved per-theme from [KsColors.memberTick]; the initial
/// is always white for a stable ≥4.5:1 on every member hue. Colour never
/// travels alone — the initial is the redundant, non-colour signal, which is
/// why the avatar pairs the two everywhere it appears (members, checklist
/// ticks, "who did this" notifications).
class KsMemberAvatar extends StatelessWidget {
  const KsMemberAvatar({
    required this.initial,
    required this.seat,
    this.size = 40,
    super.key,
  });

  /// Member display initial. Rendered uppercased, truncated to one glyph.
  final String initial;

  /// 0-based household seat; selects the tick hue (wraps the 6-way set).
  final int seat;

  /// Diameter in logical pixels. The initial scales to ~⅜ of this.
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.ksColors.memberTick(seat);
    final glyph = initial.isEmpty ? '' : initial.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        glyph,
        style: KsTokens.labelMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.375,
          letterSpacing: 0,
          height: 1,
        ),
      ),
    );
  }
}

/// A member row — avatar + name/handle + a trailing role badge.
///
/// From "Components II (Modules)", Members · roles · invite.
class KsMemberRow extends StatelessWidget {
  const KsMemberRow({
    required this.name,
    required this.handle,
    required this.role,
    required this.seat,
    this.initial,
    super.key,
  });

  final String name;

  /// Secondary line — typically an email/handle.
  final String handle;
  final HouseholdRole role;

  /// 0-based seat driving the avatar tick colour.
  final int seat;

  /// Avatar initial; defaults to the first letter of [name].
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        KsMemberAvatar(initial: initial ?? name, seat: seat),
        const SizedBox(width: KsTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
              ),
              Text(
                handle,
                style: KsTokens.labelSmall.copyWith(
                  color: ks.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: KsTokens.space8),
        _RoleBadge(role: role),
      ],
    );
  }
}

/// The role pill. Admin is a tonal brand badge; the rest are neutral outlines.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final HouseholdRole role;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    final isAdmin = role == HouseholdRole.admin;

    final Color fill = isAdmin
        ? ks.brandPrimary.withValues(alpha: isDark ? 0.20 : 0.12)
        : Colors.transparent;
    final Color textColor = isAdmin
        ? (isDark ? ks.brandPrimary : KsTokens.brandPrimaryDark)
        : ks.textSecondary;
    final BoxBorder? border = isAdmin
        ? null
        : Border.all(color: ks.borderStrong);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
        border: border,
      ),
      child: Text(
        role.label.toUpperCase(),
        style: KsTokens.labelSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1,
        ),
      ),
    );
  }
}

/// The "invite to this kitchen" card — a warm, shareable code on a sunken
/// linen well with a dashed edge and a copy action.
///
/// From "Components II (Modules)", Members · roles · invite. By default the
/// copy button writes [code] to the clipboard; pass [onCopy] to override.
class KsInviteCode extends StatelessWidget {
  const KsInviteCode({
    required this.code,
    this.label = 'Invite to this kitchen',
    this.copyLabel = 'Copy',
    this.onCopy,
    super.key,
  });

  /// The shareable invite code, e.g. `SAGE-417`.
  final String code;

  /// Uppercased eyebrow above the code.
  final String label;
  final String copyLabel;

  /// Tap handler for the copy button. Defaults to copying [code] to the
  /// system clipboard.
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return KsDashedBorder(
      color: ks.borderStrong,
      strokeWidth: 1,
      child: Container(
        padding: const EdgeInsets.all(KsTokens.space16),
        decoration: BoxDecoration(
          color: ks.surfaceSunken,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: KsTokens.labelSmall.copyWith(
                color: ks.textTertiary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: KsTokens.space8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: KsTokens.displaySmall.copyWith(
                      color: isDark ? KsTokens.brandAccent : ks.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 26,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(width: KsTokens.space12),
                FilledButton.icon(
                  onPressed:
                      onCopy ??
                      () => Clipboard.setData(ClipboardData(text: code)),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(copyLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: ks.brandPrimary,
                    foregroundColor: KsTokens.textOnBrand,
                    textStyle: KsTokens.labelMedium.copyWith(letterSpacing: 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KsTokens.space12,
                      vertical: KsTokens.space8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KsTokens.radius8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
