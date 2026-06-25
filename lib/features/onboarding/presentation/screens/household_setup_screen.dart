import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 13 (step 2) · Onboarding — set up your kitchen.
///
/// Solo, joint (premium), or join with a code. Presentational P2; choosing a
/// kitchen lands in the app at Today.
class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

enum _KitchenKind { solo, joint }

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  _KitchenKind _kind = _KitchenKind.solo;

  void _finish() => context.go('/today');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, KsTokens.space16, 22, 22),
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
                  'Step 2 of 2'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            Text(
              'Set up your kitchen',
              style: KsTokens.displayMedium.copyWith(
                color: ks.textPrimary,
                fontSize: 27,
                height: 1.05,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: KsTokens.space2),
            Text(
              'Cook alone, or with your people.',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textSecondary,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: KsTokens.space20),
            _KitchenOption(
              icon: Icons.person_outline_rounded,
              title: 'Just me',
              subtitle: 'A private, one-person kitchen',
              selected: _kind == _KitchenKind.solo,
              onTap: () => setState(() => _kind = _KitchenKind.solo),
            ),
            const SizedBox(height: KsTokens.space12),
            _KitchenOption(
              icon: Icons.groups_outlined,
              title: 'Create a household',
              subtitle: 'Up to 6 people, shared lists',
              selected: _kind == _KitchenKind.joint,
              premium: true,
              onTap: () => setState(() => _kind = _KitchenKind.joint),
            ),
            const SizedBox(height: KsTokens.space12),
            const _JoinWithCode(),
            const SizedBox(height: KsTokens.space24),
            FilledButton(
              onPressed: _finish,
              child: const Text('Enter the kitchen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitchenOption extends StatelessWidget {
  const _KitchenOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.premium = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool premium;
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
            color: selected
                ? Color.lerp(ks.surfaceRaised, ks.brandPrimary, 0.14)
                : ks.surfaceRaised,
            borderRadius: BorderRadius.circular(KsTokens.radius16),
            border: Border.all(
              color: selected ? ks.brandPrimary : ks.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? ks.brandPrimary.withValues(alpha: 0.22)
                      : ks.neutralSubtle,
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? ks.brandPrimary : ks.textSecondary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: KsTokens.titleSmall.copyWith(
                              color: ks.textPrimary,
                            ),
                          ),
                        ),
                        if (premium) ...[
                          const SizedBox(width: KsTokens.space6),
                          const KsBadge.premium(),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: KsTokens.space8),
                Icon(Icons.check_rounded, size: 18, color: ks.brandPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Join with a code" card — an icon row over a code well + Join action.
class _JoinWithCode extends StatelessWidget {
  const _JoinWithCode();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ks.neutralSubtle,
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: ks.textSecondary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Join with a code',
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                      ),
                    ),
                    Text(
                      'Got an invite?',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: ks.surfaceBase,
                    borderRadius: BorderRadius.circular(KsTokens.radius8),
                    border: Border.all(color: ks.borderStrong),
                  ),
                  child: Text(
                    'SAGE-417',
                    style: KsTokens.headlineLarge.copyWith(
                      color: ks.textTertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KsTokens.space16,
                    vertical: 14,
                  ),
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
