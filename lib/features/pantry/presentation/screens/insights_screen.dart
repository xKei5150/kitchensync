import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

/// Screen 30 · Reading the pantry back — the premium Insights surface.
///
/// The charts are *real*: a freshness donut and a section-balance rail measured
/// from the live pantry, plus a four-week waste trend from the waste-history
/// stream. They borrow the app's own freshness/section tokens — no invented
/// chart palette — and every series is paired with a value so it survives
/// greyscale and colour-vision deficiency.
///
/// It is wrapped in [KsPremiumLock]: the feature renders, working, beneath the
/// warm veil. The unlock path writes the same household premium state used by
/// Menu Sets and other premium gates.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final itemsAsync = ref.watch(pantryAllItemsStreamProvider);
    final wasteAsync = ref.watch(wasteHistoryStreamProvider);
    final bulkStatuses = ref.watch(bulkPantryStatusesProvider);

    final items = itemsAsync.asData?.value ?? const <PantryItem>[];
    final events = wasteAsync.asData?.value ?? const <WasteEvent>[];
    final month = _monthNames[DateTime.now().month - 1];

    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space32,
          ),
          children: [
            Row(
              children: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: KsTokens.space12),
                Expanded(
                  child: Text(
                    'Insights',
                    style: KsTokens.displayMedium.copyWith(
                      color: ks.textPrimary,
                      fontSize: 26,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const _PremiumChip(),
              ],
            ),
            const SizedBox(height: KsTokens.space2),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Text(
                'This month · $month',
                style: KsTokens.displaySmall.copyWith(
                  color: ks.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: KsTokens.space20),
            KsPremiumLock(
              title: 'See your pantry, measured',
              body: 'Freshness, balance, and waste — at a glance, every month.',
              onUnlock: () => context.pushNamed('premium'),
              child: Column(
                children: [
                  _FreshnessCard(items: items),
                  const SizedBox(height: KsTokens.space12),
                  _SectionBalanceCard(items: items),
                  const SizedBox(height: KsTokens.space12),
                  _WasteTrendCard(events: events),
                  const SizedBox(height: KsTokens.space12),
                  _BulkPredictionCard(statuses: bulkStatuses),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkPredictionCard extends StatelessWidget {
  const _BulkPredictionCard({required this.statuses});

  final List<BulkPantryStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final visible = statuses.take(3).toList(growable: false);
    final dueCount = statuses
        .where((status) => status.needsPurchaseSoon)
        .length;
    return _InsightCard(
      title: 'Bulk timing',
      trailing: Text(
        dueCount == 1 ? '1 due' : '$dueCount due',
        style: KsTokens.titleSmall.copyWith(
          color: dueCount > 0 ? KsTokens.expiringSoon : ks.textPrimary,
          fontSize: 13,
        ),
      ),
      child: Column(
        children: [
          if (visible.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No bulk items yet',
                style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: KsTokens.space10),
              _BulkPredictionRow(status: visible[i]),
            ],
        ],
      ),
    );
  }
}

class _BulkPredictionRow extends StatelessWidget {
  const _BulkPredictionRow({required this.status});

  final BulkPantryStatus status;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final now = DateTime.now();
    final daysLeft = status.daysLeftFrom(now);
    final interval = status.recommendedPurchaseIntervalDays;
    final leadingColor = status.needsPurchaseSoon
        ? KsTokens.expiringSoon
        : status.item.section.color;
    return Row(
      children: [
        Container(
          width: 8,
          height: 42,
          decoration: BoxDecoration(
            color: leadingColor,
            borderRadius: BorderRadius.circular(KsTokens.radiusFull),
          ),
        ),
        const SizedBox(width: KsTokens.space10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.item.ingredientId,
                style: KsTokens.titleSmall.copyWith(
                  color: ks.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: KsTokens.space2),
              Text(
                interval == null
                    ? 'Learning purchase rhythm'
                    : 'Buy every $interval days',
                style: KsTokens.labelSmall.copyWith(
                  color: ks.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: KsTokens.space10),
        Text(
          daysLeft == null
              ? '--'
              : daysLeft <= 0
              ? '0d'
              : '${daysLeft}d',
          style: KsTokens.headlineLarge.copyWith(
            color: status.needsPurchaseSoon
                ? KsTokens.expiringSoon
                : ks.textPrimary,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class _PremiumChip extends StatelessWidget {
  const _PremiumChip();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark
        ? KsTokens.brandAccent
        : Color.lerp(KsTokens.brandAccent, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: KsTokens.brandAccent.withValues(alpha: isDark ? 0.20 : 0.16),
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: ink),
          const SizedBox(width: KsTokens.space4),
          Text(
            'PREMIUM',
            style: KsTokens.labelSmall.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled chart card — the shared chrome for every insight panel.
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

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
        boxShadow: KsTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.textTertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          child,
        ],
      ),
    );
  }
}

/// The freshness donut — every item bucketed by [FreshnessHelper].
class _FreshnessCard extends StatelessWidget {
  const _FreshnessCard({required this.items});

  final List<PantryItem> items;

  @override
  Widget build(BuildContext context) {
    final counts = <Freshness, int>{};
    for (final item in items) {
      final f = FreshnessHelper.fromExpiry(item.expiryDate);
      counts[f] = (counts[f] ?? 0) + 1;
    }
    // Fixed order so the ring and legend never reshuffle frame-to-frame.
    final data = [
      KsChartDatum(
        label: 'Fresh',
        value: (counts[Freshness.fresh] ?? 0).toDouble(),
        color: KsTokens.fresh,
      ),
      KsChartDatum(
        label: 'Soon',
        value: (counts[Freshness.expiringSoon] ?? 0).toDouble(),
        color: KsTokens.expiringSoon,
      ),
      KsChartDatum(
        label: 'Expired',
        value: (counts[Freshness.expired] ?? 0).toDouble(),
        color: KsTokens.expired,
      ),
      KsChartDatum(
        label: 'No date',
        value: (counts[Freshness.unknown] ?? 0).toDouble(),
        color: context.ksColors.textTertiary,
      ),
    ];

    return _InsightCard(
      title: 'Freshness right now',
      child: Row(
        children: [
          KsDonutChart(
            data: data,
            centerValue: '${items.length}',
            centerLabel: items.length == 1 ? 'item' : 'items',
          ),
          const SizedBox(width: KsTokens.space16),
          Expanded(child: KsChartLegend(data: data)),
        ],
      ),
    );
  }
}

/// The section-balance rail — the pantry split across its four shelves.
///
/// The design's reference uses ingredient *category* tokens; the live
/// [PantryItem] carries its [PantrySection], not its category, so the honest
/// live measure is the section split — which already owns its own token set.
class _SectionBalanceCard extends StatelessWidget {
  const _SectionBalanceCard({required this.items});

  final List<PantryItem> items;

  String _labelFor(PantrySection section) => switch (section) {
    PantrySection.food => 'Food',
    PantrySection.bulk => 'Bulk',
    PantrySection.nonFood => 'Non-food',
    PantrySection.leftover => 'Leftovers',
  };

  @override
  Widget build(BuildContext context) {
    final counts = <PantrySection, int>{};
    for (final item in items) {
      counts[item.section] = (counts[item.section] ?? 0) + 1;
    }
    final data = [
      for (final section in PantrySection.values)
        KsChartDatum(
          label: _labelFor(section),
          value: (counts[section] ?? 0).toDouble(),
          color: section.color,
        ),
    ];

    return _InsightCard(
      title: 'Section balance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KsSegmentedBar(data: data),
          const SizedBox(height: KsTokens.space12),
          KsChartLegend(
            data: data,
            trailing: KsLegendTrailing.percent,
            wrap: true,
          ),
        ],
      ),
    );
  }
}

/// A four-week waste trend — items binned per trailing week, newest at the
/// right. One accent ([KsTokens.expired]); structure stays in hairline + tint.
class _WasteTrendCard extends StatelessWidget {
  const _WasteTrendCard({required this.events});

  final List<WasteEvent> events;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final weeks = _binnedByWeek(events);
    final peak = weeks.fold<int>(1, (m, w) => w > m ? w : m);
    final total = weeks.fold<int>(0, (s, w) => s + w);

    return _InsightCard(
      title: 'Waste · last 4 weeks',
      trailing: Text(
        total == 1 ? '1 item' : '$total items',
        style: KsTokens.titleSmall.copyWith(
          color: ks.textPrimary,
          fontSize: 13,
        ),
      ),
      child: SizedBox(
        height: 72,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < weeks.length; i++) ...[
              if (i > 0) const SizedBox(width: KsTokens.space10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${weeks[i]}',
                      style: KsTokens.labelSmall.copyWith(
                        color: ks.textTertiary,
                        fontSize: 10,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: KsTokens.space4),
                    Container(
                      height: 8 + 40 * (weeks[i] / peak),
                      decoration: BoxDecoration(
                        color: weeks[i] == 0
                            ? ks.neutralSubtle
                            : KsTokens.expired.withValues(
                                alpha: 0.35 + 0.65 * (weeks[i] / peak),
                              ),
                        borderRadius: BorderRadius.circular(KsTokens.radius4),
                      ),
                    ),
                    const SizedBox(height: KsTokens.space6),
                    Text(
                      'W${i + 1}',
                      style: KsTokens.labelSmall.copyWith(
                        color: ks.textTertiary,
                        fontSize: 9,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Four trailing-week buckets (oldest→newest) counting waste events in each
  /// seven-day window back from today.
  static List<int> _binnedByWeek(List<WasteEvent> events, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final weeks = List<int>.filled(4, 0);
    for (final event in events) {
      final daysAgo = reference.difference(event.date).inDays;
      if (daysAgo < 0 || daysAgo >= 28) continue;
      final weekIndex = 3 - (daysAgo ~/ 7); // 0 = oldest, 3 = this week
      weeks[weekIndex]++;
    }
    return weeks;
  }
}
