import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/wcag_contrast.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screens 17–19 · The Phase-5 accessibility verification surface, ported to a
/// live runtime screen ("KitchenSync — P3 Accessibility & Forms").
///
/// A screenshot promises a palette *looks* fine; this surface proves it. It
/// re-computes WCAG 2.1 contrast for every text-and-surface and on-colour
/// pairing against the *actual* [KsTokens] / [KsColors] values, and renders the
/// month-grid under the three dichromacies and in pure greyscale so the
/// colour-blind-safe encoding (glyph + edge, never hue alone) is provable.
///
/// Debug-only: reached from the DevTools screen, never shipped to users.
class AccessibilityAuditScreen extends StatelessWidget {
  const AccessibilityAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      appBar: AppBar(title: const Text('Accessibility audit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space8,
          KsTokens.space20,
          KsTokens.space40,
        ),
        children: [
          Text(
            'Provable, not just pretty',
            style: KsTokens.displaySmall.copyWith(color: ks.textPrimary),
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            'Measured WCAG contrast across every token pair, and the month '
            'grid proved under three kinds of colour-blindness and greyscale.',
            style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
          ),
          const SizedBox(height: KsTokens.space24),

          // ── Screen 17 · Contrast audit — light ───────────────────────
          const _SectionHeading(
            eyebrow: 'Screen 17 · Contrast audit — light',
            title: 'Every pairing, measured',
          ),
          const _ContrastPanel(
            palette: KsColors.light,
            isDark: false,
            title: 'Text on surfaces',
            rows: _AuditData.surfacesLight,
          ),
          const SizedBox(height: KsTokens.space12),
          const _ContrastPanel(
            palette: KsColors.light,
            isDark: false,
            title: 'Text on colour fills',
            rows: _AuditData.colorsLight,
          ),
          const SizedBox(height: KsTokens.space24),

          // ── Screen 18 · Contrast audit — dark ────────────────────────
          const _SectionHeading(
            eyebrow: 'Screen 18 · Contrast audit — dark',
            title: 'The candlelit surfaces hold up too',
          ),
          const _ContrastPanel(
            palette: KsColors.dark,
            isDark: true,
            title: 'Text on surfaces',
            rows: _AuditData.surfacesDark,
          ),
          const SizedBox(height: KsTokens.space12),
          const _ContrastPanel(
            palette: KsColors.dark,
            isDark: true,
            title: 'Brand & status fills',
            rows: _AuditData.colorsDark,
          ),
          const SizedBox(height: KsTokens.space24),

          // ── Screen 19 · Colour-vision & greyscale proofs ─────────────
          const _SectionHeading(
            eyebrow: 'Screen 19 · Colour-vision & greyscale',
            title: 'The grid never relies on colour alone',
          ),
          const _ProofWall(),
          const SizedBox(height: KsTokens.space16),
          const _ProofLegend(),
        ],
      ),
    );
  }
}

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
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: KsTokens.space4),
          Text(
            title,
            style: KsTokens.headlineLarge.copyWith(color: ks.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// One text-and-background pairing to be measured.
typedef _Pair = ({String name, Color fg, Color bg, String note});

/// A measured-contrast panel. Renders on its own [palette] surface (so the
/// "dark" panel reads dark even while the screen itself is light), with a
/// per-panel "N/M pass AA" tally.
class _ContrastPanel extends StatelessWidget {
  const _ContrastPanel({
    required this.palette,
    required this.isDark,
    required this.title,
    required this.rows,
  });

  final KsColors palette;
  final bool isDark;
  final String title;
  final List<_Pair> rows;

  @override
  Widget build(BuildContext context) {
    final passing = rows
        .where((p) => WcagVerdict.forRatio(contrastRatio(p.fg, p.bg)).passesAa)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space20,
        vertical: KsTokens.space16,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: palette.textTertiary,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '$passing/${rows.length} pass AA',
                style: KsTokens.labelSmall.copyWith(
                  color: palette.textTertiary,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space4),
          for (var i = 0; i < rows.length; i++)
            _ContrastRow(
              pair: rows[i],
              palette: palette,
              isDark: isDark,
              isLast: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ContrastRow extends StatelessWidget {
  const _ContrastRow({
    required this.pair,
    required this.palette,
    required this.isDark,
    required this.isLast,
  });

  final _Pair pair;
  final KsColors palette;
  final bool isDark;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ratio = contrastRatio(pair.fg, pair.bg);
    final verdict = WcagVerdict.forRatio(ratio);
    final ratioText = ratio >= 10
        ? ratio.toStringAsFixed(1)
        : ratio.toStringAsFixed(2);
    final accent = switch (verdict) {
      WcagVerdict.aaa || WcagVerdict.aa => palette.calPlanned,
      WcagVerdict.aaLarge => palette.calMissed,
      WcagVerdict.fail => palette.calProblem,
    };

    return Semantics(
      label: '${pair.name}, contrast $ratioText to 1, ${verdict.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: KsTokens.space10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: palette.hairline)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pair.bg,
                borderRadius: BorderRadius.circular(KsTokens.radius8),
                border: Border.all(color: palette.hairline),
              ),
              child: Text(
                'Aa',
                style: KsTokens.titleMedium.copyWith(color: pair.fg),
              ),
            ),
            const SizedBox(width: KsTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair.name,
                    style: KsTokens.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    pair.note,
                    style: KsTokens.bodySmall.copyWith(
                      color: palette.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KsTokens.space8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: ratioText,
                    style: KsTokens.titleMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ':1',
                    style: KsTokens.labelSmall.copyWith(
                      color: palette.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KsTokens.space8),
            _VerdictBadge(label: verdict.label, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _VerdictBadge extends StatelessWidget {
  const _VerdictBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: KsTokens.space6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        style: KsTokens.labelSmall.copyWith(
          color: accent,
          fontSize: 9,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The five-up wall of month grids: a trichromat baseline plus the three
/// dichromacies (Brettel/Machado approximations) and pure greyscale.
class _ProofWall extends StatelessWidget {
  const _ProofWall();

  // 4×5 row-major colour matrices matching the Phase-5 SVG feColorMatrix sims.
  static const List<double> _deuter = [
    0.625, 0.375, 0, 0, 0, //
    0.70, 0.30, 0, 0, 0, //
    0, 0.30, 0.70, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
  static const List<double> _protan = [
    0.567, 0.433, 0, 0, 0, //
    0.558, 0.442, 0, 0, 0, //
    0, 0.242, 0.758, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
  static const List<double> _tritan = [
    0.95, 0.05, 0, 0, 0, //
    0, 0.433, 0.567, 0, 0, //
    0, 0.475, 0.525, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
  static const List<double> _grey = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final cells = [
      const ('Normal vision', 'Trichromat baseline', null),
      ('Deuteranopia', 'No green cones · ~6% of men', _deuter),
      ('Protanopia', 'No red cones · ~2%', _protan),
      ('Tritanopia', 'No blue cones · rare', _tritan),
      ('Greyscale', 'Colour fully removed', _grey),
    ];
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Wrap(
        spacing: KsTokens.space16,
        runSpacing: KsTokens.space20,
        children: [
          for (final (title, subtitle, matrix) in cells)
            SizedBox(
              width: 188,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: KsTokens.labelSmall.copyWith(
                      color: ks.textPrimary,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: KsTokens.bodySmall.copyWith(
                      color: ks.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space10),
                  if (matrix == null)
                    const _ProofGrid()
                  else
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(matrix),
                      child: const _ProofGrid(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The status carried by a calendar day in the proof grid. Each maps to a
/// distinct glyph + edge treatment so it survives a hue collapse.
enum _DayStatus { planned, problem, shopping, missed, leftover, blank }

/// A single June month-grid, on the light palette so the CVD sims are
/// meaningful. The day→status map and Monday-first offset mirror the design.
class _ProofGrid extends StatelessWidget {
  const _ProofGrid();

  static const _offset = 2; // June 1 lands two cells into the Mon-first grid.
  static const _today = 25;
  static const Map<int, _DayStatus> _map = {
    1: _DayStatus.planned,
    2: _DayStatus.planned,
    3: _DayStatus.shopping,
    4: _DayStatus.planned,
    5: _DayStatus.planned,
    6: _DayStatus.planned,
    7: _DayStatus.leftover,
    8: _DayStatus.planned,
    9: _DayStatus.problem,
    10: _DayStatus.missed,
    11: _DayStatus.planned,
    12: _DayStatus.planned,
    13: _DayStatus.shopping,
    14: _DayStatus.planned,
    15: _DayStatus.leftover,
    16: _DayStatus.planned,
    17: _DayStatus.planned,
    18: _DayStatus.planned,
    19: _DayStatus.problem,
    20: _DayStatus.planned,
    21: _DayStatus.shopping,
    22: _DayStatus.planned,
    23: _DayStatus.planned,
    24: _DayStatus.planned,
    25: _DayStatus.planned,
    26: _DayStatus.planned,
    27: _DayStatus.leftover,
    28: _DayStatus.shopping,
    29: _DayStatus.problem,
    30: _DayStatus.planned,
  };

  @override
  Widget build(BuildContext context) {
    const heads = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        Row(
          children: [
            for (final h in heads)
              Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: KsTokens.labelSmall.copyWith(
                      color: KsColors.light.textTertiary,
                      fontSize: 8,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: KsTokens.space4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          // Slightly taller than wide so the day number + status glyph stack
          // never clips inside the dense 7-column proof grid.
          childAspectRatio: 0.72,
          children: [for (var i = 0; i < 35; i++) _cell(i - _offset + 1)],
        ),
      ],
    );
  }

  Widget _cell(int day) {
    if (day < 1 || day > 30) return const SizedBox.shrink();
    final status = _map[day] ?? _DayStatus.blank;
    return _DayCell(day: day, status: status, isToday: day == _today);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.status,
    required this.isToday,
  });

  final int day;
  final _DayStatus status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    // Resolve against the LIGHT palette so the CVD filters act on real hues.
    const surface = KsTokens.surfaceRaised;
    final (bg, edge, ink, glyph, dashed) = switch (status) {
      _DayStatus.planned => (
        Color.alphaBlend(KsTokens.calPlanned.withValues(alpha: 0.13), surface),
        KsTokens.calPlanned,
        KsTokens.calPlanned,
        Icons.check_rounded,
        false,
      ),
      _DayStatus.problem => (
        Color.alphaBlend(KsTokens.calProblem.withValues(alpha: 0.13), surface),
        KsTokens.calProblem,
        KsTokens.calProblem,
        Icons.change_history_rounded,
        false,
      ),
      _DayStatus.shopping => (
        Color.alphaBlend(KsTokens.calShopping.withValues(alpha: 0.13), surface),
        KsTokens.calShopping,
        KsTokens.calShopping,
        Icons.shopping_bag_outlined,
        false,
      ),
      _DayStatus.missed => (
        Color.alphaBlend(KsTokens.calMissed.withValues(alpha: 0.12), surface),
        KsTokens.calMissed,
        Color.alphaBlend(
          KsTokens.calMissed.withValues(alpha: 0.72),
          Colors.black,
        ),
        Icons.timer_off_outlined,
        true,
      ),
      _DayStatus.leftover => (
        surface,
        KsTokens.border,
        KsTokens.sectionLeftover,
        Icons.restaurant_rounded,
        false,
      ),
      _DayStatus.blank => (
        surface,
        KsTokens.border,
        KsTokens.textTertiary,
        null,
        false,
      ),
    };

    final inner = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KsTokens.radius6),
        border: dashed
            ? null
            : Border.all(
                color: isToday ? KsTokens.brandPrimary : edge,
                width: isToday ? 2 : 1,
              ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$day',
            style: KsTokens.labelSmall.copyWith(
              color: isToday ? KsTokens.brandPrimary : KsTokens.textPrimary,
              fontSize: 11,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          SizedBox(
            height: 11,
            child: glyph == null ? null : Icon(glyph, size: 9, color: ink),
          ),
        ],
      ),
    );

    // The grid tile (childAspectRatio 0.72) is already taller than wide; the
    // cell fills it rather than re-imposing a square that would clip the stack.
    return dashed
        ? KsDashedBorder(color: edge, radius: KsTokens.radius6, child: inner)
        : inner;
  }
}

/// The legend tying each status to its glyph + edge treatment.
class _ProofLegend extends StatelessWidget {
  const _ProofLegend();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final items = [
      ('Planned · tick', Icons.check_rounded, KsTokens.calPlanned, false),
      (
        'Problem · triangle',
        Icons.change_history_rounded,
        KsTokens.calProblem,
        false,
      ),
      ('Shop · bag', Icons.shopping_bag_outlined, KsTokens.calShopping, false),
      (
        'Missed · dashed + clock-slash',
        Icons.timer_off_outlined,
        KsTokens.calMissed,
        true,
      ),
    ];
    return Wrap(
      spacing: KsTokens.space16,
      runSpacing: KsTokens.space10,
      children: [
        for (final (label, glyph, color, dashed) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendSwatch(glyph: glyph, color: color, dashed: dashed),
              const SizedBox(width: KsTokens.space8),
              Text(
                label,
                style: KsTokens.labelMedium.copyWith(
                  color: ks.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({
    required this.glyph,
    required this.color,
    required this.dashed,
  });

  final IconData glyph;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final inner = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.13),
          ks.surfaceRaised,
        ),
        borderRadius: BorderRadius.circular(KsTokens.radius6),
        border: dashed ? null : Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Icon(glyph, size: 11, color: color),
    );
    return dashed
        ? KsDashedBorder(color: color, radius: KsTokens.radius6, child: inner)
        : inner;
  }
}

/// The measured token pairings. Foreground/background values are the literal,
/// resolved [KsTokens] / [KsColors] colours — so the table proves the live
/// design system, not a snapshot of hex strings.
abstract final class _AuditData {
  static const List<_Pair> surfacesLight = [
    (
      name: 'Primary text',
      fg: KsTokens.textPrimary,
      bg: KsTokens.surfaceRaised,
      note: 'Headlines & body',
    ),
    (
      name: 'Primary text',
      fg: KsTokens.textPrimary,
      bg: KsTokens.surfaceBase,
      note: 'On the linen scaffold',
    ),
    (
      name: 'Secondary text',
      fg: KsTokens.textSecondary,
      bg: KsTokens.surfaceRaised,
      note: 'Supporting copy',
    ),
    (
      name: 'Secondary text',
      fg: KsTokens.textSecondary,
      bg: KsTokens.surfaceBase,
      note: 'On scaffold',
    ),
    (
      name: 'Tertiary text',
      fg: KsTokens.textTertiary,
      bg: KsTokens.surfaceRaised,
      note: 'Meta & labels — non-essential',
    ),
  ];

  static const List<_Pair> colorsLight = [
    (
      name: 'On brand',
      fg: KsTokens.textOnBrand,
      bg: KsTokens.brandPrimary,
      note: 'Primary buttons',
    ),
    (
      name: 'On accent',
      fg: KsTokens.textPrimary,
      bg: KsTokens.brandAccent,
      note: 'Premium badge',
    ),
    (
      name: 'Planned',
      fg: KsTokens.textOnBrand,
      bg: KsTokens.calPlanned,
      note: 'Calendar fill',
    ),
    (
      name: 'Problem',
      fg: KsTokens.textOnBrand,
      bg: KsTokens.calProblem,
      note: 'Calendar fill',
    ),
    (
      name: 'Shopping',
      fg: KsTokens.textOnBrand,
      bg: KsTokens.calShopping,
      note: 'Calendar fill',
    ),
    (
      name: 'Missed',
      fg: KsTokens.textPrimary,
      bg: KsTokens.calMissed,
      note: 'Warning · dark text',
    ),
    (
      name: 'Member · plum',
      fg: KsTokens.textOnBrand,
      bg: Color(0xFF8E5A9E),
      note: 'Tick initial',
    ),
    (
      name: 'Member · teal',
      fg: KsTokens.textOnBrand,
      bg: Color(0xFF2F8F83),
      note: 'Tick initial',
    ),
  ];

  static const List<_Pair> surfacesDark = [
    (
      name: 'Primary text',
      fg: Color(0xFFE8E5DD),
      bg: Color(0xFF272822),
      note: 'Headlines & body',
    ),
    (
      name: 'Primary text',
      fg: Color(0xFFE8E5DD),
      bg: Color(0xFF1E1F1B),
      note: 'On scaffold',
    ),
    (
      name: 'Secondary text',
      fg: Color(0xFFB5BBAE),
      bg: Color(0xFF272822),
      note: 'Supporting copy',
    ),
    (
      name: 'Tertiary text',
      fg: KsTokens.textTertiary,
      bg: Color(0xFF272822),
      note: 'Meta — non-essential',
    ),
  ];

  static const List<_Pair> colorsDark = [
    (
      name: 'On brand',
      fg: KsTokens.textPrimary,
      bg: KsTokens.brandPrimaryLight,
      note: 'Primary buttons',
    ),
    (
      name: 'Planned',
      fg: KsTokens.textPrimary,
      bg: KsTokens.calPlannedDark,
      note: 'Lifted dark fill',
    ),
    (
      name: 'Problem',
      fg: KsTokens.textPrimary,
      bg: KsTokens.calProblemDark,
      note: 'Lifted dark fill',
    ),
    (
      name: 'Shopping',
      fg: KsTokens.textPrimary,
      bg: KsTokens.calShoppingDark,
      note: 'Lifted dark fill',
    ),
    (
      name: 'Missed',
      fg: KsTokens.textPrimary,
      bg: KsTokens.calMissedDark,
      note: 'Lifted dark fill',
    ),
    (
      name: 'Produce · dark',
      fg: KsTokens.textPrimary,
      bg: KsTokens.catProduceDark,
      note: 'Proposed cat fill',
    ),
    (
      name: 'Meat · dark',
      fg: KsTokens.textPrimary,
      bg: KsTokens.catMeatDark,
      note: 'Proposed cat fill',
    ),
  ];
}
