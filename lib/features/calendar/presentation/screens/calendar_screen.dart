import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 02 · Calendar — an almanac you read in seconds.
///
/// The grid *is* the hero; chrome recedes. Status colour + glyph rhythm tells
/// the household's month at a glance. Presentational P0: a representative
/// June sample, the live planner lands when the calendar feature is built.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  // June 2025 starts on a Sunday — six leading pad cells in a Monday-first
  // grid. The status spread mirrors the design canvas: a calm planned rhythm
  // punctuated by shop days, two problems, a missed shop, and leftover nights.
  static const Map<int, CalendarDayStatus> _statuses = {
    1: CalendarDayStatus.planned,
    2: CalendarDayStatus.planned,
    3: CalendarDayStatus.shopping,
    4: CalendarDayStatus.planned,
    5: CalendarDayStatus.planned,
    6: CalendarDayStatus.planned,
    7: CalendarDayStatus.leftover,
    8: CalendarDayStatus.planned,
    9: CalendarDayStatus.problem,
    10: CalendarDayStatus.missed,
    11: CalendarDayStatus.planned,
    12: CalendarDayStatus.planned,
    13: CalendarDayStatus.shopping,
    14: CalendarDayStatus.planned,
    15: CalendarDayStatus.leftover,
    16: CalendarDayStatus.planned,
    17: CalendarDayStatus.planned,
    18: CalendarDayStatus.planned,
    19: CalendarDayStatus.problem,
    20: CalendarDayStatus.planned,
    21: CalendarDayStatus.shopping,
    22: CalendarDayStatus.planned,
    23: CalendarDayStatus.planned,
    24: CalendarDayStatus.planned,
    25: CalendarDayStatus.planned, // today
    26: CalendarDayStatus.planned,
    27: CalendarDayStatus.leftover,
    28: CalendarDayStatus.shopping,
    29: CalendarDayStatus.problem,
    30: CalendarDayStatus.planned,
  };

  static const int _leadingPad = 6;
  static const int _today = 25;

  List<KsAlmanacDay> get _days => [
    for (var i = 0; i < _leadingPad; i++) KsAlmanacDay.blank,
    for (var d = 1; d <= 30; d++)
      KsAlmanacDay(_statuses[d], isToday: d == _today),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space8,
          KsTokens.space16,
          KsTokens.space24,
        ),
        children: [
          KsFolioHeader(
            eyebrow: 'The Calendar',
            title: 'June 2025',
            actions: [
              KsHeaderAction(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous month',
                onTap: () {},
              ),
              KsHeaderAction(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next month',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space16),
          KsAlmanacGrid(days: _days),
          const SizedBox(height: KsTokens.space16),
          _SelectedDayPeek(onTap: () => context.push('/day')),
        ],
      ),
    );
  }
}

/// The selected-day peek — today's plan in a tappable card that opens the
/// day's lifecycle filmstrip.
class _SelectedDayPeek extends StatelessWidget {
  const _SelectedDayPeek({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Wed 25 · Today'.toUpperCase(),
                      style: KsTokens.labelSmall.copyWith(
                        color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline,
                    size: 12,
                    color: KsTokens.fresh,
                  ),
                  const SizedBox(width: KsTokens.space4),
                  Text(
                    'ready',
                    style: KsTokens.labelSmall.copyWith(
                      color: KsTokens.fresh,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space6),
              Text(
                'Tomato & white bean braise',
                style: KsTokens.headlineMedium.copyWith(
                  color: ks.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
