import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

/// Screen 10 · Waste & insights, derived entirely from waste history.
class WasteLogScreen extends ConsumerWidget {
  const WasteLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final wasteAsync = ref.watch(wasteHistoryStreamProvider);
    final events = wasteAsync.asData?.value ?? const <WasteEvent>[];
    final now = ref.watch(clockProvider).now();
    final week = _WeekWaste.fromEvents(events, now: now);
    final monthCount = events
        .where(
          (event) =>
              event.date.year == now.year && event.date.month == now.month,
        )
        .length;

    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space20,
            KsTokens.space8,
            KsTokens.space20,
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
                const SizedBox(width: KsTokens.space12),
                Text(
                  'The Ledger · ${_months[now.month - 1]}'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.brandPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space16),
            _WasteSummaryHero(eventCount: monthCount),
            Divider(height: KsTokens.space32, thickness: 1, color: ks.hairline),
            _WasteAlmanac(week: week),
          ],
        ),
      ),
    );
  }
}

class _WasteSummaryHero extends StatelessWidget {
  const _WasteSummaryHero({required this.eventCount});

  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$eventCount',
          style: KsTokens.displayLarge.copyWith(
            color: ks.textPrimary,
            fontSize: 64,
            height: 0.86,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: KsTokens.space6),
        Text(
          eventCount == 1
              ? 'waste event recorded this month'
              : 'waste events recorded this month',
          style: KsTokens.displaySmall.copyWith(
            color: ks.textSecondary,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

/// The waste this week strip — fresh days short and green, binned days tall and
/// red — under a header that counts the week's binned items.
class _WasteAlmanac extends StatelessWidget {
  const _WasteAlmanac({required this.week});

  final _WeekWaste week;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fresh = KsTokens.fresh.withValues(alpha: isDark ? 0.5 : 0.45);
    final waste = isDark
        ? Color.lerp(KsTokens.expired, Colors.white, 0.22)!
        : KsTokens.expired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Waste this week'.toUpperCase(),
              style: KsTokens.labelSmall.copyWith(
                color: ks.textTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${week.total} ',
                    style: KsTokens.displaySmall.copyWith(
                      color: ks.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                    ),
                  ),
                  TextSpan(
                    text: week.total == 1 ? 'event' : 'events',
                    style: KsTokens.labelSmall.copyWith(
                      color: ks.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space12),
        SizedBox(
          height: 58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++) ...[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: week.binned[i] ? 42 : 18,
                        decoration: BoxDecoration(
                          color: week.binned[i] ? waste : fresh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: KsTokens.space4),
                      Text(
                        _labels[i],
                        style: KsTokens.labelSmall.copyWith(
                          color: ks.textTertiary,
                          fontSize: 8,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != 6) const SizedBox(width: KsTokens.space6),
              ],
            ],
          ),
        ),
        const SizedBox(height: KsTokens.space12),
        Text(
          week.total == 0
              ? 'No waste events recorded in the last seven days.'
              : '${week.total} waste ${week.total == 1 ? 'event' : 'events'} '
                    'recorded in the last seven days.',
          style: KsTokens.displaySmall.copyWith(
            color: ks.textSecondary,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// The week's waste, bucketed by weekday for the almanac. Counts only events
/// from the trailing seven days so the strip reads as "this week".
@immutable
class _WeekWaste {
  const _WeekWaste({required this.binned, required this.total});

  factory _WeekWaste.fromEvents(
    List<WasteEvent> events, {
    required DateTime now,
  }) {
    final cutoff = now.subtract(const Duration(days: 7));
    final binned = List<bool>.filled(7, false);
    var total = 0;
    for (final event in events) {
      if (event.date.isBefore(cutoff)) continue;
      total++;
      binned[event.date.weekday - 1] = true;
    }
    return _WeekWaste(binned: binned, total: total);
  }

  /// Seven flags, Monday-first, marking which weekdays saw waste.
  final List<bool> binned;
  final int total;
}

const _months = [
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
