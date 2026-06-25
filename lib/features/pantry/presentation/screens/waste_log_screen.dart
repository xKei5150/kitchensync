import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

/// Screen 10 · Waste & insights — wasting less, made to feel good.
///
/// A data-editorial spread where the charts *are* the typography: money saved
/// as the headline, waste as a calm weekly almanac. The savings hero is
/// presentational sample data; the weekly almanac is derived from the live
/// waste-history stream.
class WasteLogScreen extends ConsumerWidget {
  const WasteLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final wasteAsync = ref.watch(wasteHistoryStreamProvider);
    final events = wasteAsync.asData?.value ?? const <WasteEvent>[];
    final week = _WeekWaste.fromEvents(events);

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
                  'The Ledger · June'.toUpperCase(),
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
            const _SavedHero(),
            Divider(height: KsTokens.space32, thickness: 1, color: ks.hairline),
            _WasteAlmanac(week: week),
            const SizedBox(height: KsTokens.space16),
            const _SavedFromBinBanner(),
          ],
        ),
      ),
    );
  }
}

/// The hero numeral — money saved this month — over a climbing-bars motif.
class _SavedHero extends StatelessWidget {
  const _SavedHero();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '£42',
          style: KsTokens.displayLarge.copyWith(
            color: ks.textPrimary,
            fontSize: 64,
            height: 0.86,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: KsTokens.space6),
        Text(
          'saved this month by shopping what you had',
          style: KsTokens.displaySmall.copyWith(
            color: ks.textSecondary,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: KsTokens.space16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++) ...[
              _ClimbBar(
                height: const [16.0, 24.0, 32.0, 44.0][i],
                color: i == 3
                    ? (isDark ? KsTokens.brandAccent : ks.brandPrimary)
                    : ks.brandPrimary.withValues(
                        alpha: const [0.30, 0.45, 0.62, 1.0][i],
                      ),
              ),
              const SizedBox(width: 5),
            ],
            const SizedBox(width: 1),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '4 months climbing',
                style: KsTokens.displaySmall.copyWith(
                  color: ks.textTertiary,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClimbBar extends StatelessWidget {
  const _ClimbBar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
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
                    text: week.total == 1 ? 'item' : 'items',
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
          height: 54,
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
              ? "Nothing's slipped past this week — the pantry's holding."
              : 'A couple slipped past — keep an eye on the soft greens.',
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

/// The reassuring brand-tinted close — what was saved from the bin.
class _SavedFromBinBanner extends StatelessWidget {
  const _SavedFromBinBanner();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          ks.brandPrimary.withValues(alpha: 0.08),
          ks.surfaceRaised,
        ),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.brandPrimary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 18, color: ks.brandPrimary),
          const SizedBox(width: KsTokens.space10),
          Expanded(
            child: Text(
              'Three things saved from the bin this week.',
              style: KsTokens.titleSmall.copyWith(
                color: ks.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The week's waste, bucketed by weekday for the almanac. Counts only events
/// from the trailing seven days so the strip reads as "this week".
@immutable
class _WeekWaste {
  const _WeekWaste({required this.binned, required this.total});

  factory _WeekWaste.fromEvents(List<WasteEvent> events) {
    final now = DateTime.now();
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
