import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Screen 30 · Reading the pantry back.
///
/// One datum in a KitchenSync chart: a [label], its [value], and the [color]
/// it borrows from the app's own freshness / category / section tokens. Data-viz
/// never invents a chart palette, and every series carries a value or text
/// label so it survives colour-blindness and greyscale.
@immutable
class KsChartDatum {
  const KsChartDatum({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// A composition donut — the freshness mix or section split read as one whole.
///
/// The ring borrows freshness/section tokens; the hero numeral in the well uses
/// the Fraunces display face, axis-free and chart-junk-free. Pair with a
/// [KsChartLegend] so each arc is named and counted.
class KsDonutChart extends StatelessWidget {
  const KsDonutChart({
    required this.data,
    required this.centerValue,
    required this.centerLabel,
    this.size = 96,
    this.thickness = 16,
    super.key,
  });

  final List<KsChartDatum> data;
  final String centerValue;
  final String centerLabel;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              data: data,
              thickness: thickness,
              track: ks.neutralSubtle,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: KsTokens.displaySmall.copyWith(
                  color: ks.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              Text(
                centerLabel,
                style: KsTokens.labelSmall.copyWith(
                  color: ks.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.data,
    required this.thickness,
    required this.track,
  });

  final List<KsChartDatum> data;
  final double thickness;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      thickness / 2,
      thickness / 2,
      size.width - thickness,
      size.height - thickness,
    );
    final total = data.fold<double>(0, (sum, d) => sum + d.value);

    // Empty pantry → a single calm track ring, never a void.
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..color = track,
      );
      return;
    }

    var start = -math.pi / 2; // 12 o'clock
    for (final datum in data) {
      if (datum.value <= 0) continue;
      final sweep = datum.value / total * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt
          ..color = datum.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.data != data || old.thickness != thickness || old.track != track;
}

/// A single 100%-wide segmented rail — one whole split into parts.
///
/// Borrows the section/category tokens; pair with a [KsChartLegend] of percents.
class KsSegmentedBar extends StatelessWidget {
  const KsSegmentedBar({required this.data, this.height = 14, super.key});

  final List<KsChartDatum> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final total = data.fold<double>(0, (sum, d) => sum + d.value);
    final positive = data.where((d) => d.value > 0).toList();

    if (total <= 0 || positive.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: ks.neutralSubtle,
          borderRadius: BorderRadius.circular(KsTokens.radiusFull),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(KsTokens.radiusFull),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final datum in positive)
              Expanded(
                flex: math.max(1, (datum.value / total * 1000).round()),
                child: ColoredBox(color: datum.color),
              ),
          ],
        ),
      ),
    );
  }
}

/// The chart's key — a swatch, a label, and (optionally) a value or percent for
/// every series, so the chart reads in greyscale and for colour-vision
/// deficiency. Lays out as a wrap of chips or a vertical stack.
class KsChartLegend extends StatelessWidget {
  const KsChartLegend({
    required this.data,
    this.trailing = KsLegendTrailing.value,
    this.wrap = false,
    super.key,
  });

  final List<KsChartDatum> data;
  final KsLegendTrailing trailing;

  /// Lay the entries out as a [Wrap] of inline chips rather than a vertical
  /// stack of full-width rows.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (sum, d) => sum + d.value);
    if (wrap) {
      return Wrap(
        spacing: KsTokens.space12,
        runSpacing: KsTokens.space8,
        children: [
          for (final datum in data)
            _LegendEntry(
              datum: datum,
              total: total,
              trailing: trailing,
              inline: true,
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final datum in data)
          Padding(
            padding: const EdgeInsets.only(bottom: KsTokens.space8),
            child: _LegendEntry(
              datum: datum,
              total: total,
              trailing: trailing,
              inline: false,
            ),
          ),
      ],
    );
  }
}

/// What a [KsChartLegend] entry shows after its label.
enum KsLegendTrailing { value, percent, none }

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.datum,
    required this.total,
    required this.trailing,
    required this.inline,
  });

  final KsChartDatum datum;
  final double total;
  final KsLegendTrailing trailing;
  final bool inline;

  String? get _trailingText => switch (trailing) {
    KsLegendTrailing.none => null,
    KsLegendTrailing.value => datum.value.toStringAsFixed(
      datum.value % 1 == 0 ? 0 : 1,
    ),
    KsLegendTrailing.percent =>
      total <= 0 ? '0%' : '${(datum.value / total * 100).round()}%',
  };

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final swatch = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: datum.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    final label = Text(
      datum.label,
      style: KsTokens.bodySmall.copyWith(
        color: ks.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: inline ? 11 : 12,
      ),
    );
    final value = _trailingText;

    if (inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(width: KsTokens.space6),
          label,
          if (value != null) ...[
            const SizedBox(width: KsTokens.space4),
            Text(
              value,
              style: KsTokens.labelSmall.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                fontSize: 11,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        swatch,
        const SizedBox(width: KsTokens.space8),
        Expanded(child: label),
        if (value != null)
          Text(
            value,
            style: KsTokens.labelMedium.copyWith(
              color: ks.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
