import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/ks_dashed.dart';

/// The calendar's 4th semantic status system, carried by a day cell's
/// fill + edge + glyph.
///
/// Each status pairs a colour with a redundant, non-colour glyph so the
/// almanac stays legible in greyscale and for colour-vision deficiency —
/// planned = check, problem = triangle, shopping = bag, missed = clock-slash
/// (on a dashed edge), leftover = dome. [empty] is an un-planned future day.
enum CalendarDayStatus { planned, problem, shopping, missed, leftover, empty }

/// Resolved visual treatment for a [CalendarDayStatus] under the active theme.
@immutable
class _DayStyle {
  const _DayStyle({
    required this.fill,
    required this.edge,
    required this.edgeWidth,
    required this.dashed,
    required this.accent,
    required this.glyph,
    this.barColor,
  });

  final Color fill;
  final Color edge;
  final double edgeWidth;
  final bool dashed;

  /// The status hue — used for the glyph, caption, and (when present) top bar.
  final Color accent;
  final IconData? glyph;

  /// The 3px top accent bar, when the status carries one.
  final Color? barColor;
}

_DayStyle _resolveDayStyle(BuildContext context, CalendarDayStatus status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ks = context.ksColors;
  final raised = ks.surfaceRaised;
  final fillAmt = isDark ? 0.18 : 0.12;
  final edgeAmt = isDark ? 0.45 : 0.40;

  Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  switch (status) {
    case CalendarDayStatus.planned:
      final c = ks.calPlanned;
      return _DayStyle(
        fill: mix(raised, c, fillAmt),
        edge: mix(ks.border, c, edgeAmt),
        edgeWidth: 1,
        dashed: false,
        accent: c,
        glyph: Icons.check_rounded,
        barColor: c,
      );
    case CalendarDayStatus.problem:
      final c = ks.calProblem;
      return _DayStyle(
        fill: mix(raised, c, fillAmt),
        edge: mix(ks.border, c, edgeAmt),
        edgeWidth: 1,
        dashed: false,
        accent: c,
        glyph: Icons.warning_amber_rounded,
        barColor: c,
      );
    case CalendarDayStatus.shopping:
      final c = ks.calShopping;
      return _DayStyle(
        fill: mix(raised, c, fillAmt),
        edge: mix(ks.border, c, edgeAmt),
        edgeWidth: 1,
        dashed: false,
        accent: c,
        glyph: Icons.shopping_bag_outlined,
        barColor: c,
      );
    case CalendarDayStatus.missed:
      final c = ks.calMissed;
      return _DayStyle(
        fill: mix(raised, c, isDark ? 0.16 : 0.12),
        edge: c,
        edgeWidth: 1.5,
        dashed: true,
        // Darken the mustard caption/glyph on light for ≥4.5:1; keep the
        // luminance-lifted token on dark.
        accent: isDark ? c : mix(c, Colors.black, 0.30),
        glyph: Icons.timer_off_outlined,
      );
    case CalendarDayStatus.leftover:
      return _DayStyle(
        fill: raised,
        edge: ks.border,
        edgeWidth: 1,
        dashed: false,
        accent: KsTokens.sectionLeftover,
        glyph: Icons.room_service_outlined,
      );
    case CalendarDayStatus.empty:
      return _DayStyle(
        fill: raised,
        edge: ks.border,
        edgeWidth: 1,
        dashed: false,
        accent: ks.textTertiary,
        glyph: null,
      );
  }
}

/// A single calendar day cell — the module's signature piece.
///
/// Status reads by fill + edge + glyph; the day number is set in the display
/// serif. [isToday] overlays a brand ring and recolours the numeral.
/// From "Components II (Modules)", Calendar day cell.
class KsCalendarDayCell extends StatelessWidget {
  const KsCalendarDayCell({
    required this.day,
    required this.status,
    this.caption,
    this.isToday = false,
    super.key,
  });

  /// The day-of-month numeral.
  final int day;
  final CalendarDayStatus status;

  /// Short status caption beneath the numeral (e.g. "Ragù · 4", "2 missing").
  final String? caption;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final style = _resolveDayStyle(context, status);

    final dayColor = isToday
        ? ks.brandPrimary
        : status == CalendarDayStatus.leftover
        ? ks.textSecondary
        : ks.textPrimary;

    // Today always wears a planned-style accent bar + brand ring.
    final barColor = isToday ? ks.calPlanned : style.barColor;
    final glyph = isToday ? Icons.check_rounded : style.glyph;
    final glyphColor = isToday ? ks.calPlanned : style.accent;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (barColor != null) Container(height: 3, color: barColor),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KsTokens.space10,
            vertical: 9,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$day',
                    style: KsTokens.displaySmall.copyWith(
                      color: dayColor,
                      fontSize: 20,
                      height: 1,
                    ),
                  ),
                  if (glyph != null) Icon(glyph, size: 15, color: glyphColor),
                ],
              ),
              if (caption != null && caption!.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  caption!,
                  style: KsTokens.labelSmall.copyWith(
                    color: isToday ? ks.textTertiary : style.accent,
                    fontSize: 10,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (style.dashed && !isToday) {
      return KsDashedBorder(
        color: style.edge,
        strokeWidth: style.edgeWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          child: ColoredBox(color: style.fill, child: content),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isToday ? ks.surfaceRaised : style.fill,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(
          color: isToday ? ks.brandPrimary : style.edge,
          width: isToday ? 2 : style.edgeWidth,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: ks.brandPrimary.withValues(alpha: 0.14),
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: content,
    );
  }
}

/// One day in the [KsAlmanacGrid]. A null [status] renders a blank leading or
/// trailing pad cell (no numeral).
@immutable
class KsAlmanacDay {
  const KsAlmanacDay(this.status, {this.isToday = false});

  /// Null = a blank pad cell that carries no day number.
  final CalendarDayStatus? status;
  final bool isToday;

  /// A blank leading/trailing pad cell.
  static const KsAlmanacDay blank = KsAlmanacDay(null);
}

/// The almanac glance — a month grid whose colour + glyph *rhythm* lets a
/// stranger read the household's month in under two seconds.
///
/// Pad the leading days of the month with [KsAlmanacDay.blank]. Real days
/// number sequentially. From "Components II (Modules)", The almanac glance.
class KsAlmanacGrid extends StatelessWidget {
  const KsAlmanacGrid({required this.days, this.showLegend = true, super.key});

  final List<KsAlmanacDay> days;

  /// Show the planned / problem / shop / missed legend beneath the grid.
  final bool showLegend;

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;

    final rows = <Widget>[];
    var dayNum = 0;
    for (var i = 0; i < days.length; i += 7) {
      final week = <Widget>[];
      for (var j = 0; j < 7; j++) {
        final index = i + j;
        if (index >= days.length) {
          week.add(const Expanded(child: SizedBox.shrink()));
          continue;
        }
        final day = days[index];
        if (day.status == null) {
          week.add(const Expanded(child: AspectRatio(aspectRatio: 1)));
        } else {
          dayNum++;
          week.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _AlmanacCell(
                    day: dayNum,
                    status: day.status!,
                    isToday: day.isToday,
                  ),
                ),
              ),
            ),
          );
        }
      }
      rows.add(Row(children: week));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final d in _weekdays)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.textTertiary,
                    fontSize: 9,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: KsTokens.space6),
        ...rows,
        if (showLegend) ...[
          const SizedBox(height: KsTokens.space16),
          Wrap(
            spacing: KsTokens.space10,
            runSpacing: KsTokens.space6,
            children: [
              _LegendSwatch(color: ks.calPlanned, label: 'Planned'),
              _LegendSwatch(color: ks.calProblem, label: 'Problem'),
              _LegendSwatch(color: ks.calShopping, label: 'Shop'),
              _LegendSwatch(color: ks.calMissed, label: 'Missed', dashed: true),
            ],
          ),
        ],
      ],
    );
  }
}

class _AlmanacCell extends StatelessWidget {
  const _AlmanacCell({
    required this.day,
    required this.status,
    required this.isToday,
  });

  final int day;
  final CalendarDayStatus status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final style = _resolveDayStyle(context, status);
    final glyph = isToday ? Icons.check_rounded : style.glyph;

    final inner = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$day',
          style: KsTokens.displaySmall.copyWith(
            color: isToday ? ks.brandPrimary : ks.textPrimary,
            fontSize: 13,
            height: 1,
          ),
        ),
        if (glyph != null) ...[
          const SizedBox(height: 1),
          Icon(glyph, size: 11, color: style.accent),
        ],
      ],
    );

    if (style.dashed) {
      return KsDashedBorder(
        color: style.edge,
        radius: KsTokens.radius8,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KsTokens.radius8),
          child: ColoredBox(
            color: style.fill,
            child: Center(child: inner),
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(KsTokens.radius8),
        border: Border.all(color: style.edge, width: style.edgeWidth),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: ks.brandPrimary.withValues(alpha: 0.9),
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: inner,
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: dashed ? null : color,
            borderRadius: BorderRadius.circular(3),
            border: dashed ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: KsTokens.space4),
        Text(
          label,
          style: KsTokens.labelSmall.copyWith(
            color: ks.textSecondary,
            fontSize: 10,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// The lifecycle of a planned meal, named 1:1 with the app.
enum DishState { scheduled, cooked, leftover, waste, cancelled }

extension DishStateX on DishState {
  String get label => switch (this) {
    DishState.scheduled => 'Scheduled',
    DishState.cooked => 'Cooked',
    DishState.leftover => 'Leftover',
    DishState.waste => 'Waste',
    DishState.cancelled => 'Cancelled',
  };
}

/// A meal / dish chip — recipe + meta carrying its lifecycle state.
///
/// The state pill on the right pairs colour with a glyph (and the row dims for
/// waste, strikes through for cancelled) so the lifecycle never travels by hue
/// alone. From "Components II (Modules)", Meal / dish chip.
class KsDishChip extends StatelessWidget {
  const KsDishChip({
    required this.title,
    required this.subtitle,
    required this.state,
    this.swatchColor,
    super.key,
  });

  final String title;

  /// Secondary line — meal + servings, or "2 portions left", "went off".
  final String subtitle;
  final DishState state;

  /// Category tint for the leading swatch (rendered at 15% alpha). Waste and
  /// cancelled override this with their own neutral/danger treatment.
  final Color? swatchColor;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final dimmed = state == DishState.waste;
    final cancelled = state == DishState.cancelled;

    final swatchBg = switch (state) {
      DishState.waste => ks.danger.withValues(alpha: 0.12),
      DishState.cancelled => ks.neutralSubtle,
      _ => (swatchColor ?? ks.brandPrimary).withValues(alpha: 0.15),
    };

    final titleColor = dimmed
        ? ks.textSecondary
        : cancelled
        ? ks.textTertiary
        : ks.textPrimary;

    return Opacity(
      opacity: dimmed ? 0.8 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: ks.surfaceRaised,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          border: Border.all(color: ks.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: swatchBg,
                borderRadius: BorderRadius.circular(KsTokens.radius8),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KsTokens.titleSmall.copyWith(
                      color: titleColor,
                      fontSize: 13,
                      height: 1.25,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KsTokens.labelSmall.copyWith(
                      color: ks.textTertiary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KsTokens.space8),
            _DishStatePill(state: state),
          ],
        ),
      ),
    );
  }
}

class _DishStatePill extends StatelessWidget {
  const _DishStatePill({required this.state});

  final DishState state;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;

    final (
      Color fill,
      Color textColor,
      BoxBorder? border,
      IconData? glyph,
    ) = switch (state) {
      DishState.scheduled => (
        Colors.transparent,
        ks.textSecondary,
        Border.all(color: ks.borderStrong),
        Icons.schedule,
      ),
      DishState.cooked => (
        ks.brandPrimary,
        KsTokens.textOnBrand,
        null,
        Icons.check_rounded,
      ),
      DishState.leftover => (
        KsTokens.sectionLeftover.withValues(alpha: 0.14),
        KsTokens.sectionLeftover,
        null,
        Icons.room_service_outlined,
      ),
      DishState.waste => (
        ks.danger.withValues(alpha: 0.10),
        ks.danger,
        null,
        Icons.delete_outline,
      ),
      DishState.cancelled => (
        Colors.transparent,
        ks.textTertiary,
        Border.all(color: ks.border),
        null,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space8,
        vertical: KsTokens.space4,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 11, color: textColor),
            const SizedBox(width: KsTokens.space4),
          ],
          Text(
            state.label.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.3,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
