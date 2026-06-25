import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screens 26–30 · The "honest edges" gallery, ported to a live runtime surface
/// ("KitchenSync — P5 System States & Intelligence").
///
/// Three of P5's surfaces have no backend yet — there is no sync-conflict
/// detection, no offline write-queue model, and no role *enforcement* (the
/// app's household roles are admin/cook/shopper/member, not the design's
/// owner/member/viewer). Rather than fake those systems in the live app, they
/// live here as faithful presentational references, beside live demos of the
/// two components that *did* graduate — the skeleton loader and the charts.
///
/// Debug-only: reached from the DevTools screen, never shipped to users.
class SystemStatesScreen extends StatelessWidget {
  const SystemStatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      appBar: AppBar(title: const Text('System states')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space8,
          KsTokens.space20,
          KsTokens.space40,
        ),
        children: [
          Text(
            'The honest edges',
            style: KsTokens.displaySmall.copyWith(color: ks.textPrimary),
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            'Five surfaces the happy path never shows. The skeleton and '
            'charts are live components; the conflict, queue, and role '
            'matrix are presentational — those systems are not built yet.',
            style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
          ),
          const SizedBox(height: KsTokens.space24),

          const _SectionHeading(
            eyebrow: 'Screen 27 · Loading',
            title: 'Honest waiting (live)',
          ),
          const _SkeletonDemoPanel(),
          const SizedBox(height: KsTokens.space32),

          const _SectionHeading(
            eyebrow: 'Screen 30 · Pantry intelligence',
            title: 'Charts that borrow the palette (live)',
          ),
          const _ChartsDemoPanel(),
          const SizedBox(height: KsTokens.space32),

          const _SectionHeading(
            eyebrow: 'Screen 26 · Sync conflict',
            title: 'Two hands, one shelf',
          ),
          const _ConflictPanel(),
          const SizedBox(height: KsTokens.space32),

          const _SectionHeading(
            eyebrow: 'Screen 28 · Offline & queued sync',
            title: 'Works on the subway',
          ),
          const _OfflinePanel(),
          const SizedBox(height: KsTokens.space32),

          const _SectionHeading(
            eyebrow: 'Screen 29 · Permissions',
            title: 'A polite locked door',
          ),
          const _PermissionsPanel(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared chrome (mirrors the P4 accessibility-states gallery)
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: KsTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: ks.brandPrimary,
              letterSpacing: 1.4,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: KsTokens.space4),
          Text(
            title,
            style: KsTokens.headlineMedium.copyWith(color: ks.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.eyebrow, required this.child});

  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: KsTokens.space12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 27 · Skeleton (live)
// ─────────────────────────────────────────────────────────────────────────

class _SkeletonDemoPanel extends StatelessWidget {
  const _SkeletonDemoPanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return _Panel(
      eyebrow: 'KsSkeleton · shimmer (reduced motion → opacity pulse)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: ks.surfaceBase,
              borderRadius: BorderRadius.circular(KsTokens.radius12),
              border: Border.all(color: ks.border),
            ),
            child: const Row(
              children: [
                KsSkeleton(width: 4, height: 34, radius: 2),
                SizedBox(width: KsTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KsSkeleton.line(width: 140),
                      SizedBox(height: KsTokens.space8),
                      KsSkeleton.line(width: 90, height: 10),
                    ],
                  ),
                ),
                SizedBox(width: KsTokens.space12),
                KsSkeleton(width: 52, height: 24, radius: KsTokens.radiusFull),
              ],
            ),
          ),
          const SizedBox(height: KsTokens.space12),
          const Row(
            children: [
              KsSkeleton.circle(size: 40),
              SizedBox(width: KsTokens.space12),
              KsSkeleton.line(width: 120),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 30 · Charts (live, sample data)
// ─────────────────────────────────────────────────────────────────────────

class _ChartsDemoPanel extends StatelessWidget {
  const _ChartsDemoPanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final freshness = [
      const KsChartDatum(label: 'Fresh', value: 30, color: KsTokens.fresh),
      const KsChartDatum(
        label: 'Soon',
        value: 10,
        color: KsTokens.expiringSoon,
      ),
      const KsChartDatum(label: 'Expired', value: 4, color: KsTokens.expired),
      KsChartDatum(label: 'No date', value: 4, color: ks.textTertiary),
    ];
    const sections = [
      KsChartDatum(label: 'Food', value: 24, color: KsTokens.sectionFood),
      KsChartDatum(label: 'Bulk', value: 12, color: KsTokens.sectionBulk),
      KsChartDatum(label: 'Non-food', value: 8, color: KsTokens.sectionNonFood),
      KsChartDatum(
        label: 'Leftovers',
        value: 4,
        color: KsTokens.sectionLeftover,
      ),
    ];

    return _Panel(
      eyebrow: 'Donut + segmented rail · every series labelled & valued',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KsDonutChart(
                data: freshness,
                centerValue: '48',
                centerLabel: 'items',
              ),
              const SizedBox(width: KsTokens.space16),
              Expanded(child: KsChartLegend(data: freshness)),
            ],
          ),
          const SizedBox(height: KsTokens.space20),
          const KsSegmentedBar(data: sections),
          const SizedBox(height: KsTokens.space12),
          const KsChartLegend(
            data: sections,
            trailing: KsLegendTrailing.percent,
            wrap: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 26 · Sync conflict (presentational)
// ─────────────────────────────────────────────────────────────────────────

class _ConflictPanel extends StatelessWidget {
  const _ConflictPanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    // A conflict is two valid truths, not a failure — it wears the indigo
    // member tick (seat 3), never expired red.
    final indigo = ks.memberTick(3);
    return _Panel(
      eyebrow: 'Conflict, not error · indigo + merge, never expired red',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                indigo.withValues(alpha: 0.09),
                ks.surfaceRaised,
              ),
              borderRadius: BorderRadius.circular(KsTokens.radius12),
              border: Border.all(color: indigo.withValues(alpha: 0.32)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.merge_rounded, size: 18, color: indigo),
                const SizedBox(width: KsTokens.space10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Two of you edited this',
                        style: KsTokens.titleSmall.copyWith(
                          color: ks.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: KsTokens.space2),
                      Text(
                        'Both versions are saved. Nothing is lost until you '
                        'choose.',
                        style: KsTokens.bodySmall.copyWith(
                          color: ks.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              Expanded(
                child: _VersionCard(
                  seat: 0,
                  name: 'Ana',
                  meta: 'offline · 2h ago',
                  quantity: '1 carton',
                  bestBy: '28 Jun',
                  highlight: indigo,
                  highlightBestBy: false,
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              Expanded(
                child: _VersionCard(
                  seat: 1,
                  name: 'Ben',
                  meta: 'just now',
                  quantity: '2 cartons',
                  bestBy: '30 Jun',
                  highlight: indigo,
                  highlightBestBy: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: indigo,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.merge_rounded, size: 16),
              label: const Text('Merge — keep newest of each'),
            ),
          ),
          const SizedBox(height: KsTokens.space8),
          Center(
            child: Text(
              'Result: 2 cartons · best by 30 Jun',
              style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.seat,
    required this.name,
    required this.meta,
    required this.quantity,
    required this.bestBy,
    required this.highlight,
    required this.highlightBestBy,
  });

  final int seat;
  final String name;
  final String meta;
  final String quantity;
  final String bestBy;
  final Color highlight;
  final bool highlightBestBy;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ks.border),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ks.surfaceSunken,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KsTokens.radius12),
              ),
            ),
            child: Row(
              children: [
                KsMemberAvatar(initial: name[0], seat: seat, size: 22),
                const SizedBox(width: KsTokens.space8),
                Expanded(
                  child: Text(
                    name,
                    style: KsTokens.titleSmall.copyWith(
                      color: ks.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta,
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.textTertiary,
                    fontSize: 9,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: KsTokens.space8),
                _Field(label: 'Quantity', value: quantity, highlight: null),
                const SizedBox(height: KsTokens.space6),
                _Field(
                  label: 'Best by',
                  value: bestBy,
                  highlight: highlightBestBy ? highlight : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlight == null
            ? Colors.transparent
            : highlight!.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KsTokens.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: highlight ?? ks.textTertiary,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: KsTokens.space2),
          Text(
            value,
            style: KsTokens.titleSmall.copyWith(
              color: ks.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 28 · Offline & queued sync (banner is live; queue is presentational)
// ─────────────────────────────────────────────────────────────────────────

class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return _Panel(
      eyebrow: 'Warm-brown informational · the live banner, then the queue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The live offline banner, shown unconditionally for reference.
          ClipRRect(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            child: const OfflineBanner(),
          ),
          const SizedBox(height: KsTokens.space12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  KsTokens.lowStock.withValues(alpha: 0.14),
                  ks.surfaceRaised,
                ),
                borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                border: Border.all(
                  color: KsTokens.lowStock.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: KsTokens.lowStock,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '3',
                      style: KsTokens.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: KsTokens.space8),
                  Text(
                    'changes waiting to sync',
                    style: KsTokens.titleSmall.copyWith(
                      color: Color.alphaBlend(
                        KsTokens.lowStock.withValues(alpha: 0.8),
                        ks.textPrimary,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          Text(
            'BACK ONLINE · SYNC QUEUE',
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: KsTokens.space8),
          const _QueueRow(label: 'Added Carrots', status: 'Synced', done: true),
          const SizedBox(height: KsTokens.space6),
          const _QueueRow(label: 'Used Spinach', status: 'Synced', done: true),
          const SizedBox(height: KsTokens.space6),
          const _QueueRow(
            label: 'Edited Whole milk',
            status: 'Sending…',
            done: false,
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.label,
    required this.status,
    required this.done,
  });

  final String label;
  final String status;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius10),
        border: Border.all(
          color: done ? ks.border : ks.brandPrimary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          if (done)
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KsTokens.fresh.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 13,
                color: KsTokens.fresh,
              ),
            )
          else
            SizedBox(
              width: 22,
              height: 22,
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: ks.brandPrimary,
                  ),
                ),
              ),
            ),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Text(
              label,
              style: KsTokens.titleSmall.copyWith(
                color: ks.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            status,
            style: KsTokens.labelSmall.copyWith(
              color: done ? ks.textTertiary : ks.brandPrimary,
              fontSize: 10,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 29 · Permissions (presentational — no enforcement exists)
// ─────────────────────────────────────────────────────────────────────────

class _PermissionsPanel extends StatelessWidget {
  const _PermissionsPanel();

  static const _rows = [
    ('View pantry', [true, true, true]),
    ('Add & edit items', [true, true, false]),
    ('Edit calendar', [true, true, false]),
    ('Invite members', [true, false, false]),
    ('Manage roles · delete', [true, false, false]),
  ];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return _Panel(
      eyebrow:
          'Grey lock, not red · name the boundary, who lifts it, a way '
          'through',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MatrixHeaderRow(),
          for (final (action, can) in _rows)
            _MatrixRow(action: action, can: can),
          const SizedBox(height: KsTokens.space16),
          // The denial dialog — calm, with a way through.
          Container(
            padding: const EdgeInsets.all(KsTokens.space16),
            decoration: BoxDecoration(
              color: ks.surfaceBase,
              borderRadius: BorderRadius.circular(KsTokens.radius16),
              border: Border.all(color: ks.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ks.neutralSubtle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 22,
                    color: ks.textSecondary,
                  ),
                ),
                const SizedBox(height: KsTokens.space12),
                Text(
                  'Only owners can do that',
                  textAlign: TextAlign.center,
                  style: KsTokens.headlineMedium.copyWith(
                    color: ks.textPrimary,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: KsTokens.space6),
                Text(
                  "You're a Member of The Kitchen. Deleting the household is "
                  'reserved for its owner.',
                  textAlign: TextAlign.center,
                  style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                ),
                const SizedBox(height: KsTokens.space12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ks.surfaceSunken,
                    borderRadius: BorderRadius.circular(KsTokens.radius12),
                  ),
                  child: Row(
                    children: [
                      const KsMemberAvatar(initial: 'A', seat: 0, size: 30),
                      const SizedBox(width: KsTokens.space10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ana',
                              style: KsTokens.titleSmall.copyWith(
                                color: ks.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Owner · can change this',
                              style: KsTokens.labelSmall.copyWith(
                                color: ks.textTertiary,
                                fontSize: 10,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KsTokens.space12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Ask Ana'),
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Not now')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixHeaderRow extends StatelessWidget {
  const _MatrixHeaderRow();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    TextStyle style() => KsTokens.labelSmall.copyWith(
      color: ks.textTertiary,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: KsTokens.space8),
      child: Row(
        children: [
          Expanded(flex: 17, child: Text('ACTION', style: style())),
          Expanded(
            flex: 7,
            child: Text('OWNER', style: style(), textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 7,
            child: Text('MEMBER', style: style(), textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 7,
            child: Text('VIEWER', style: style(), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({required this.action, required this.can});

  final String action;
  final List<bool> can;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    Widget cell({required bool allowed}) => Icon(
      allowed ? Icons.check_rounded : Icons.remove_rounded,
      size: 15,
      color: allowed ? KsTokens.fresh : ks.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KsTokens.space8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: ks.hairline)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: KsTokens.space8),
          child: Row(
            children: [
              Expanded(
                flex: 17,
                child: Text(
                  action,
                  style: KsTokens.bodySmall.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Center(child: cell(allowed: can[0])),
              ),
              Expanded(
                flex: 7,
                child: Center(child: cell(allowed: can[1])),
              ),
              Expanded(
                flex: 7,
                child: Center(child: cell(allowed: can[2])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
