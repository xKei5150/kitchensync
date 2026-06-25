import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

enum KsInsightKind { jar, stack, almanac }

/// A premium insight tile — a single metric tied to *food*, never the
/// number-plus-sparkline cliché.
///
/// Three signatures: days-until-empty as a [KsInsightTile.jar] (depleting),
/// money-saved as a [KsInsightTile.stack] (growing), and waste as a
/// [KsInsightTile.almanac] strip. The viz lives in the linen/serif world: a
/// display-serif numeral over an italic serif caption. From
/// "Components II (Modules)", Insight tiles.
class KsInsightTile extends StatelessWidget {
  const KsInsightTile._({
    required this.kind,
    required this.value,
    required this.caption,
    this.fill = 0.3,
    this.jarColor,
    this.wasteDays,
    super.key,
  });

  /// Days-until-empty as a depleting jar. [fill] is the 0–1 remaining level.
  const KsInsightTile.jar({
    required String value,
    required String caption,
    double fill = 0.3,
    Color? color,
    Key? key,
  }) : this._(
         kind: KsInsightKind.jar,
         value: value,
         caption: caption,
         fill: fill,
         jarColor: color,
         key: key,
       );

  /// Money-saved as a growing stack of bars.
  const KsInsightTile.stack({
    required String value,
    required String caption,
    Key? key,
  }) : this._(
         kind: KsInsightKind.stack,
         value: value,
         caption: caption,
         key: key,
       );

  /// Waste as a small almanac strip — fresh days short and green, binned days
  /// tall and red. [wasteDays] flags which of the seven days saw waste.
  const KsInsightTile.almanac({
    required String value,
    required String caption,
    required List<bool> wasteDays,
    Key? key,
  }) : this._(
         kind: KsInsightKind.almanac,
         value: value,
         caption: caption,
         wasteDays: wasteDays,
         key: key,
       );

  final KsInsightKind kind;
  final String value;
  final String caption;
  final double fill;
  final Color? jarColor;
  final List<bool>? wasteDays;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 50, child: Center(child: _viz(context))),
          const SizedBox(height: KsTokens.space10),
          Text(
            value,
            textAlign: TextAlign.center,
            style: KsTokens.displayMedium.copyWith(
              color: ks.textPrimary,
              fontSize: 28,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: KsTokens.displaySmall.copyWith(
              color: ks.textSecondary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _viz(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    switch (kind) {
      case KsInsightKind.jar:
        final base =
            jarColor ?? (isDark ? KsTokens.catDairyDark : KsTokens.catDairy);
        final outline = isDark ? base : Color.lerp(base, Colors.black, 0.45)!;
        return CustomPaint(
          size: const Size(40, 50),
          painter: _JarPainter(
            outline: outline,
            fillColor: base.withValues(alpha: 0.55),
            level: fill.clamp(0.0, 1.0),
          ),
        );
      case KsInsightKind.stack:
        final accent = isDark ? KsTokens.brandAccent : ks.brandPrimary;
        const heights = [18.0, 28.0, 38.0, 48.0];
        const alphas = [0.35, 0.5, 0.7, 1.0];
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < heights.length; i++) ...[
              Container(
                width: 9,
                height: heights[i],
                decoration: BoxDecoration(
                  color: i == heights.length - 1
                      ? accent
                      : ks.brandPrimary.withValues(alpha: alphas[i]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (i != heights.length - 1)
                const SizedBox(width: KsTokens.space4),
            ],
          ],
        );
      case KsInsightKind.almanac:
        final days = wasteDays ?? const [];
        final fresh = KsTokens.fresh.withValues(alpha: isDark ? 0.6 : 0.55);
        final waste = isDark
            ? Color.lerp(ks.danger, Colors.white, 0.25)!
            : KsTokens.expired;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++) ...[
              Container(
                width: 7,
                height: days[i] ? 40 : 30,
                decoration: BoxDecoration(
                  color: days[i] ? waste : fresh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (i != days.length - 1) const SizedBox(width: KsTokens.space3),
            ],
          ],
        );
    }
  }
}

/// Paints a small jar — lid, outlined body, and a fill level rising from the
/// base — for the days-until-empty insight.
class _JarPainter extends CustomPainter {
  const _JarPainter({
    required this.outline,
    required this.fillColor,
    required this.level,
  });

  final Color outline;
  final Color fillColor;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final lidRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, 0, w * 0.6, 5),
      const Radius.circular(3),
    );
    // Body outline (slightly more rounded at the foot).
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(1, 6, w - 2, h - 6),
      topLeft: const Radius.circular(5),
      topRight: const Radius.circular(5),
      bottomLeft: const Radius.circular(9),
      bottomRight: const Radius.circular(9),
    );
    final fillHeight = (h - 8) * level;
    final fillRect = Rect.fromLTWH(0, h - fillHeight, w, fillHeight);

    final fillPaint = Paint()..color = fillColor;
    final strokePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas
      ..drawRRect(lidRRect, Paint()..color = outline)
      ..save()
      ..clipRRect(bodyRect)
      ..drawRect(fillRect, fillPaint)
      ..restore()
      ..drawRRect(bodyRect, strokePaint);
  }

  @override
  bool shouldRepaint(_JarPainter old) =>
      old.outline != outline ||
      old.fillColor != fillColor ||
      old.level != level;
}
