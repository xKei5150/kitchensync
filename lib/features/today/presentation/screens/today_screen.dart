import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 01 · Home / "Today" — a kitchen journal, not a dashboard.
///
/// An oversized Fraunces greeting, one hero focus for tonight, then a calm
/// urgency-ranked stack. Presentational P0: the content is representative
/// sample data, exactly as the design canvas frames it.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space6,
          KsTokens.space16,
          KsTokens.space24,
        ),
        children: [
          const _GreetingHeader(
            greeting: 'Good evening, Ana',
            subtitle: 'Tuesday, 25 June · the shelves are calm',
          ),
          const SizedBox(height: KsTokens.space16),
          _TonightHero(onStartCooking: () => context.push('/day')),
          const _SprigDivider(),
          const _SectionLabel('Use soon'),
          const SizedBox(height: KsTokens.space10),
          const _UseSoonRow(
            name: 'Spinach',
            note: 'on its last day — soup tonight?',
            daysLabel: '1d',
          ),
          const SizedBox(height: KsTokens.space12),
          const Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '2',
                  label: 'days until next shop',
                  accent: _StatAccent.shopping,
                ),
              ),
              SizedBox(width: KsTokens.space10),
              Expanded(
                child: _StatCard(
                  value: '3',
                  label: 'saved from the bin',
                  accent: _StatAccent.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The eyebrow + avatar row, the oversized greeting, and an italic Fraunces
/// status line. Shared by the calm and busy day layouts.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.greeting, required this.subtitle});

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'The Kitchen'.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            _HeaderTapTarget(
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
              child: const _HeaderDisc(icon: Icons.notifications_none_rounded),
            ),
            _HeaderTapTarget(
              label: 'Settings',
              onTap: () => context.push('/settings'),
              child: const _HeaderDisc(icon: Icons.settings_outlined),
            ),
            _HeaderTapTarget(
              label: 'Account · Ana',
              onTap: () => context.push('/settings'),
              child: const KsMemberAvatar(initial: 'A', seat: 0, size: 32),
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space12),
        Text(
          greeting,
          style: KsTokens.displayMedium.copyWith(
            color: ks.textPrimary,
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: KsTokens.space2),
        Text(
          subtitle,
          style: KsTokens.displaySmall.copyWith(
            color: ks.textSecondary,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// A header chrome entry point — keeps the small disc / avatar visual but
/// guarantees a 48×48 tap target and an accessible label (WCAG 2.5.5).
class _HeaderTapTarget extends StatelessWidget {
  const _HeaderTapTarget({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// The small neutral disc behind a header glyph, matching `KsHeaderAction`.
class _HeaderDisc extends StatelessWidget {
  const _HeaderDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ks.neutralSubtle,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: ks.textSecondary),
    );
  }
}

/// The hero "tonight" card — a category-tinted cover band, the recipe, an
/// at-a-glance pantry-readiness line, and the primary action.
class _TonightHero extends StatelessWidget {
  const _TonightHero({required this.onStartCooking});

  final VoidCallback onStartCooking;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
        boxShadow: KsTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 108,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.all(KsTokens.space12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(ks.surfaceRaised, KsTokens.catProduce, 0.34)!,
                  Color.lerp(ks.surfaceRaised, KsTokens.catGrain, 0.30)!,
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KsTokens.space10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: KsTokens.brandPrimaryDark,
                borderRadius: BorderRadius.circular(KsTokens.radiusFull),
              ),
              child: Text(
                'Tonight · Dinner'.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: KsTokens.textOnBrand,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tomato & white bean braise',
                  style: KsTokens.displaySmall.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 21,
                    height: 1.12,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: KsTokens.space8),
                Row(
                  children: [
                    Text(
                      '45 min · serves 4',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: KsTokens.space12),
                    const Icon(
                      Icons.check_circle_outline,
                      size: 13,
                      color: KsTokens.fresh,
                    ),
                    const SizedBox(width: KsTokens.space4),
                    Text(
                      'All 8 in pantry',
                      style: KsTokens.labelSmall.copyWith(
                        color: KsTokens.fresh,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KsTokens.space12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStartCooking,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Start cooking'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A wheat-sprig rule that breaks the urgent hero from the calm stack below.
class _SprigDivider extends StatelessWidget {
  const _SprigDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    final sprig = isDark ? KsTokens.brandAccent : ks.brandPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space2,
        KsTokens.space20,
        KsTokens.space2,
        KsTokens.space16,
      ),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: ks.hairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KsTokens.space10),
            child: Icon(Icons.eco_outlined, size: 14, color: sprig),
          ),
          Expanded(child: Container(height: 1, color: ks.hairline)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

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

/// A single "use soon" nudge — a freshness-barred row with an italic prompt
/// and a days-remaining stamp.
class _UseSoonRow extends StatelessWidget {
  const _UseSoonRow({
    required this.name,
    required this.note,
    required this.daysLabel,
  });

  final String name;
  final String note;
  final String daysLabel;

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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: KsTokens.expiringSoon),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: KsTokens.titleSmall.copyWith(
                              color: ks.textPrimary,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          Text(
                            note,
                            style: KsTokens.displaySmall.copyWith(
                              color: ks.textSecondary,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KsTokens.space8),
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: KsTokens.expiringSoon,
                    ),
                    const SizedBox(width: KsTokens.space4),
                    Text(
                      daysLabel,
                      style: KsTokens.labelMedium.copyWith(
                        color: KsTokens.lowStock,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StatAccent { shopping, brand }

/// A small "by the numbers" card — an oversized Fraunces numeral over a quiet
/// caption.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final _StatAccent accent;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final color = switch (accent) {
      _StatAccent.shopping => ks.calShopping,
      _StatAccent.brand => ks.brandPrimary,
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: KsTokens.displayMedium.copyWith(
              color: color,
              fontSize: 26,
              height: 1,
            ),
          ),
          const SizedBox(height: KsTokens.space3),
          Text(
            label,
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
