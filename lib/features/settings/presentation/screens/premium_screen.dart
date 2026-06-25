import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 15 (premium) · KitchenSync Premium — an upgrade that sells
/// capability, not a paywall.
///
/// A centred star mark, the four headline capabilities, an annual/monthly
/// price toggle, and the trial CTA. Presentational P2.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

enum _Plan { annual, monthly }

class _PremiumScreenState extends State<PremiumScreen> {
  _Plan _plan = _Plan.annual;

  static const _benefits = [
    ('Menu Sets', 'reusable meal-plan templates'),
    ('Pantry intelligence', 'days-until-empty & waste analytics'),
    ('Joint households', 'up to 6, per-member ticks'),
    ('Paste & Parse', '+ budget recipe search'),
  ];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, KsTokens.space8, 22, 22),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: KsHeaderAction(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onTap: () => context.pop(),
              ),
            ),
            const SizedBox(height: KsTokens.space8),
            Column(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 34,
                  color: KsTokens.brandAccent,
                ),
                const SizedBox(height: KsTokens.space8),
                Text(
                  'KitchenSync Premium',
                  textAlign: TextAlign.center,
                  style: KsTokens.displayMedium.copyWith(
                    color: ks.textPrimary,
                    fontSize: 28,
                    height: 1.02,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: KsTokens.space4),
                Text(
                  'Reuse a week you loved.',
                  style: KsTokens.displaySmall.copyWith(
                    color: ks.textSecondary,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space20),
            for (final (title, rest) in _benefits) ...[
              _BenefitRow(title: title, rest: rest),
              const SizedBox(height: 11),
            ],
            const SizedBox(height: KsTokens.space8),
            _PlanToggle(
              plan: _plan,
              onSelect: (p) => setState(() => _plan = p),
            ),
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('Start 7-day free trial'),
            ),
            const SizedBox(height: KsTokens.space8),
            TextButton.icon(
              onPressed: () => context.push('/insights'),
              icon: const Icon(Icons.insights_outlined, size: 17),
              label: const Text('Preview pantry insights'),
            ),
            const SizedBox(height: KsTokens.space8),
            Text(
              _plan == _Plan.annual
                  ? 'Cancel anytime · then £29/year'
                  : 'Cancel anytime · then £3.99/month',
              textAlign: TextAlign.center,
              style: KsTokens.labelSmall.copyWith(
                color: ks.textTertiary,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.title, required this.rest});

  final String title;
  final String rest;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_rounded, size: 17, color: ks.brandPrimary),
        const SizedBox(width: 11),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: KsTokens.bodyMedium.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                TextSpan(
                  text: ' — $rest',
                  style: KsTokens.bodyMedium.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The annual / monthly segmented price toggle.
class _PlanToggle extends StatelessWidget {
  const _PlanToggle({required this.plan, required this.onSelect});

  final _Plan plan;
  final ValueChanged<_Plan> onSelect;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space4),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlanOption(
              title: 'Annual',
              subtitle: '£29 · save 40%',
              selected: plan == _Plan.annual,
              onTap: () => onSelect(_Plan.annual),
            ),
          ),
          Expanded(
            child: _PlanOption(
              title: 'Monthly',
              subtitle: '£3.99',
              selected: plan == _Plan.monthly,
              onTap: () => onSelect(_Plan.monthly),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final fg = selected ? KsTokens.textOnBrand : ks.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? ks.brandPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(KsTokens.radius8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: KsTokens.labelMedium.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: KsTokens.space2),
              Text(
                subtitle,
                style: KsTokens.labelSmall.copyWith(
                  color: selected
                      ? KsTokens.textOnBrand.withValues(alpha: 0.85)
                      : ks.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
