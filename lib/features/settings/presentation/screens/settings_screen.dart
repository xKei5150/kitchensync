import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 15 · Settings — the quiet, useful corners.
///
/// A calm profile header, a Premium invitation that sells capability, and the
/// grouped settings list. Presentational P2; "Sign out" returns to the front
/// door so the onboarding flow stays reachable.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  'Settings'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.brandPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            const _ProfileRow(),
            const SizedBox(height: KsTokens.space16),
            _PremiumBanner(onTap: () => context.push('/settings/premium')),
            const SizedBox(height: KsTokens.space16),
            _SettingsGroup(
              rows: [
                _SettingsRow(
                  icon: Icons.groups_outlined,
                  label: 'Household & roles',
                  onTap: () => context.push('/household'),
                ),
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications'),
                ),
                const _SettingsRow(
                  icon: Icons.brightness_6_outlined,
                  label: 'Appearance',
                  trailingText: 'Auto',
                ),
                const _SettingsRow(
                  icon: Icons.public_rounded,
                  label: 'Units & locale',
                  trailingText: 'Metric · £',
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space20),
            OutlinedButton(
              onPressed: () => context.go('/onboarding'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ks.danger,
                side: BorderSide(color: ks.borderStrong),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KsTokens.radius12),
                ),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        const KsMemberAvatar(initial: 'A', seat: 0, size: 48),
        const SizedBox(width: KsTokens.space12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ana Holloway',
              style: KsTokens.headlineLarge.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 19,
                height: 1,
              ),
            ),
            const SizedBox(height: KsTokens.space2),
            Text(
              'ana@home · Admin',
              style: KsTokens.labelSmall.copyWith(
                color: ks.textTertiary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The warm "Try Premium" invitation — a wheat-and-amber gradient card that
/// sells the capability rather than gating it.
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(ks.surfaceRaised, KsTokens.brandAccent, 0.26)!,
                Color.lerp(ks.surfaceRaised, KsTokens.catGrain, 0.26)!,
              ],
            ),
            borderRadius: BorderRadius.circular(KsTokens.radius16),
            border: Border.all(
              color: KsTokens.brandAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 26,
                color: KsTokens.brandPrimaryDark,
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Try Premium',
                      style: KsTokens.headlineMedium.copyWith(
                        color: KsTokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Menu Sets, insights & joint households',
                      style: KsTokens.bodySmall.copyWith(
                        color: KsTokens.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: KsTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: ks.hairline),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ks.textSecondary),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Text(
                  label,
                  style: KsTokens.bodyMedium.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: ks.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
