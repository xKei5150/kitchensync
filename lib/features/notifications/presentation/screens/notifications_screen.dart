import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 16 · Notification inbox — what needs you, gently.
///
/// Expiry nudges, emergency-shop pings and household activity, grouped by time
/// and written in the house voice. Presentational P2 with representative
/// alerts. Leans on [KsNotificationRow] for both glyph-led and member-led rows.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            Row(
              children: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                Text(
                  'Inbox'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.brandPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space8),
            Text(
              'Notifications',
              style: KsTokens.displayMedium.copyWith(
                color: ks.textPrimary,
                fontSize: 26,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: KsTokens.space20),
            const _GroupLabel('Today'),
            const SizedBox(height: KsTokens.space8),
            const KsNotificationRow.icon(
              icon: Icons.eco_rounded,
              accent: KsTokens.expiringSoon,
              title: 'Spinach is on its last day',
              body: 'Soup tonight? Still good for one meal.',
              time: '2h',
            ),
            const SizedBox(height: KsTokens.space8),
            KsNotificationRow.icon(
              icon: Icons.shopping_bag_outlined,
              accent: ks.calProblem,
              title: 'Tonight needs a shop',
              body: '2 ingredients missing for the braise.',
              time: '5h',
              emphasized: true,
            ),
            const SizedBox(height: KsTokens.space20),
            const _GroupLabel('Earlier'),
            const SizedBox(height: KsTokens.space8),
            const Opacity(
              opacity: 0.85,
              child: KsNotificationRow.member(
                initial: 'B',
                seat: 1,
                title: 'Ben finished the shop',
                body: '11 of 12 ticked — next week shrank to 10.',
                time: '1d',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: KsTokens.labelSmall.copyWith(
        color: context.ksColors.textTertiary,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1,
      ),
    );
  }
}
