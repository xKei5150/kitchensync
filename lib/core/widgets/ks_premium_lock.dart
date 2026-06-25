import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/ks_member.dart';

/// A premium lock — never a grey scrim + padlock.
///
/// It shows the feature [child] *working*, softly veiled behind a warm linen
/// gradient + a light blur, with one inviting call to action. From
/// "Components II (Modules)", Premium lock & notifications.
class KsPremiumLock extends StatelessWidget {
  const KsPremiumLock({
    required this.child,
    required this.title,
    required this.body,
    this.buttonLabel = 'Unlock Premium',
    this.onUnlock,
    super.key,
  });

  /// The real feature, rendered live beneath the veil.
  final Widget child;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(KsTokens.radius16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KsTokens.radius16),
          border: Border.all(color: ks.border),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: ks.surfaceRaised)),
            // The feature, working.
            child,
            // Warm veil + invitation.
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          ks.surfaceBase.withValues(alpha: 0.55),
                          ks.surfaceBase.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(KsTokens.space20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: KsTokens.brandAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 19,
                              color: KsTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: KsTokens.space12),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: KsTokens.headlineLarge.copyWith(
                              color: ks.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 21,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: KsTokens.space6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              body,
                              textAlign: TextAlign.center,
                              style: KsTokens.bodySmall.copyWith(
                                color: ks.textSecondary,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: KsTokens.space16),
                          FilledButton(
                            onPressed: onUnlock,
                            style: FilledButton.styleFrom(
                              backgroundColor: ks.brandPrimary,
                              foregroundColor: KsTokens.textOnBrand,
                              textStyle: KsTokens.labelLarge.copyWith(
                                letterSpacing: 0,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: KsTokens.space12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  KsTokens.radius12,
                                ),
                              ),
                            ),
                            child: Text(buttonLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A notification row — a leading glyph disc *or* a member avatar, a title +
/// body, and a trailing relative timestamp.
///
/// From "Components II (Modules)", Premium lock & notifications. [emphasized]
/// tints the row border with the accent for higher-urgency alerts.
class KsNotificationRow extends StatelessWidget {
  const KsNotificationRow._({
    required this.title,
    required this.body,
    required this.time,
    this.icon,
    this.accentColor,
    this.memberInitial,
    this.memberSeat,
    this.emphasized = false,
    super.key,
  });

  /// An alert led by a tonal glyph disc tinted with [accent].
  const KsNotificationRow.icon({
    required IconData icon,
    required Color accent,
    required String title,
    required String body,
    required String time,
    bool emphasized = false,
    Key? key,
  }) : this._(
         icon: icon,
         accentColor: accent,
         title: title,
         body: body,
         time: time,
         emphasized: emphasized,
         key: key,
       );

  /// A "who did this" alert led by a member avatar.
  const KsNotificationRow.member({
    required String initial,
    required int seat,
    required String title,
    required String body,
    required String time,
    Key? key,
  }) : this._(
         memberInitial: initial,
         memberSeat: seat,
         title: title,
         body: body,
         time: time,
         key: key,
       );

  final String title;
  final String body;
  final String time;
  final IconData? icon;
  final Color? accentColor;
  final String? memberInitial;
  final int? memberSeat;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;

    final Widget leading;
    if (memberSeat != null) {
      leading = KsMemberAvatar(
        initial: memberInitial ?? '',
        seat: memberSeat!,
        size: 34,
      );
    } else {
      final accent = accentColor ?? ks.brandPrimary;
      final iconColor = isDark
          ? accent
          : Color.lerp(accent, Colors.black, 0.35)!;
      leading = Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: iconColor),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(
          color: emphasized && accentColor != null
              ? Color.lerp(ks.border, accentColor, 0.28)!
              : ks.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: KsTokens.titleSmall.copyWith(
                    color: ks.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                Text(
                  body,
                  style: KsTokens.bodySmall.copyWith(
                    color: ks.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KsTokens.space12),
          Text(
            time,
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
