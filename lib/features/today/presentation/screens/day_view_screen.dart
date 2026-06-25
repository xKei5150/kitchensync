import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 03 · Dish-in-Date · daily view — a day as a lifecycle filmstrip.
///
/// A vertical day-timeline, dishes threaded down a rail rather than stacked
/// cards. Each shows its lifecycle state; tonight's dish expands to its full
/// actions. Presentational P0 with representative sample data.
class DayViewScreen extends StatelessWidget {
  const DayViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            KsFolioHeader(
              eyebrow: 'The Day',
              title: 'Wednesday 25',
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space20),
            const _TimelineEntry(
              time: '8a',
              node: _NodeKind.done,
              child: _ConsumedRow(name: 'Yogurt & berries'),
            ),
            const _TimelineEntry(
              time: '1p',
              node: _NodeKind.leftover,
              child: _LeftoverBlock(),
            ),
            _TimelineEntry(
              time: '7p',
              node: _NodeKind.scheduled,
              isLast: true,
              child: _TonightExpanded(
                onMarkCooked: () => context.pop(),
                // The recipe detail ("Closer Look") is a full-screen route over
                // the root navigator, so it pushes cleanly without re-entering
                // the shell — unlike the `/recipes` branch, which must be
                // switched with `go`.
                onRecipe: () => context.push('/recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NodeKind { done, leftover, scheduled }

/// A single rail entry: a time gutter, the rail node + connector, and content.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.time,
    required this.node,
    required this.child,
    this.isLast = false,
  });

  final String time;
  final _NodeKind node;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final nodeColor = switch (node) {
      _NodeKind.done => ks.brandPrimary,
      _NodeKind.leftover => KsTokens.sectionLeftover,
      _NodeKind.scheduled => ks.brandPrimary,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                time,
                style: KsTokens.labelSmall.copyWith(
                  color: ks.textTertiary,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: KsTokens.space8),
          _Rail(color: nodeColor, ring: node == _NodeKind.scheduled),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : KsTokens.space16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.color, required this.ring});

  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SizedBox(
      width: 14,
      child: Column(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: ring ? ks.surfaceRaised : color,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: ring ? 2.5 : 0),
            ),
          ),
          Expanded(child: Container(width: 2, color: ks.hairline)),
        ],
      ),
    );
  }
}

class _ConsumedRow extends StatelessWidget {
  const _ConsumedRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: KsTokens.titleSmall.copyWith(
              color: ks.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          'Eaten',
          style: KsTokens.labelSmall.copyWith(
            color: ks.textTertiary,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LeftoverBlock extends StatelessWidget {
  const _LeftoverBlock();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Leftover pad thai',
                style: KsTokens.titleSmall.copyWith(
                  color: ks.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.room_service_outlined,
              size: 12,
              color: KsTokens.sectionLeftover,
            ),
            const SizedBox(width: KsTokens.space4),
            Text(
              'Leftover',
              style: KsTokens.labelSmall.copyWith(
                color: KsTokens.sectionLeftover,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space2),
        Text(
          '2 portions — eat by tomorrow',
          style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
        ),
      ],
    );
  }
}

/// Tonight's dish, expanded to its full action surface.
class _TonightExpanded extends StatelessWidget {
  const _TonightExpanded({required this.onMarkCooked, required this.onRecipe});

  final VoidCallback onMarkCooked;
  final VoidCallback onRecipe;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
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
            children: [
              Expanded(
                child: Text(
                  'Tonight · Dinner'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.brandPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Icon(
                Icons.check_circle_outline,
                size: 13,
                color: KsTokens.fresh,
              ),
              const SizedBox(width: KsTokens.space4),
              Text(
                'all in pantry',
                style: KsTokens.labelSmall.copyWith(
                  color: KsTokens.fresh,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            'Tomato & white bean braise',
            style: KsTokens.displaySmall.copyWith(
              color: ks.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              height: 1.1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: KsTokens.space3),
          Text(
            '45 min · serves 4',
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMarkCooked,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Mark cooked'),
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              OutlinedButton(onPressed: onRecipe, child: const Text('Recipe')),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          const Wrap(
            spacing: KsTokens.space16,
            runSpacing: KsTokens.space8,
            children: [
              _MiniAction(icon: Icons.tune_rounded, label: 'Servings'),
              _MiniAction(icon: Icons.swap_horiz_rounded, label: 'Swap'),
              _MiniAction(icon: Icons.close_rounded, label: 'Cancel'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ks.textSecondary),
        const SizedBox(width: KsTokens.space4),
        Text(
          label,
          style: KsTokens.labelSmall.copyWith(
            color: ks.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
