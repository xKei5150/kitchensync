import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// One ingredient line in a [KsServingScaler], with a base amount measured at
/// the recipe's base serving count.
@immutable
class KsScalableIngredient {
  const KsScalableIngredient({
    required this.name,
    required this.baseAmount,
    this.unit = '',
  });

  final String name;

  /// Amount at the recipe's [KsServingScaler.baseServings].
  final double baseAmount;
  final String unit;
}

/// The serving-size scaler — a display-serif serving numeral over a slider,
/// with the ingredient amounts tumbling live as you drag.
///
/// Honours reduced-motion: when the platform requests it, the numerals update
/// on release rather than continuously. From "Components II (Modules)",
/// Serving-size scaler.
class KsServingScaler extends StatefulWidget {
  const KsServingScaler({
    required this.baseServings,
    required this.ingredients,
    this.initialServings,
    this.min = 1,
    this.max = 12,
    this.onChanged,
    super.key,
  });

  /// Serving count the [ingredients] amounts are quoted at.
  final int baseServings;
  final List<KsScalableIngredient> ingredients;

  /// Starting serving count; defaults to [baseServings].
  final int? initialServings;
  final int min;
  final int max;

  /// Fires with the committed serving count as the slider settles.
  final ValueChanged<int>? onChanged;

  @override
  State<KsServingScaler> createState() => _KsServingScalerState();
}

class _KsServingScalerState extends State<KsServingScaler> {
  late int _committed = (widget.initialServings ?? widget.baseServings).clamp(
    widget.min,
    widget.max,
  );
  late double _dragValue = _committed.toDouble();

  /// The serving count shown right now: the live drag value when motion is
  /// allowed, the last committed value when reduced-motion is requested.
  int _displayServings(bool reduceMotion) =>
      reduceMotion ? _committed : _dragValue.round();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final servings = _displayServings(reduceMotion);
    final ratio = servings / widget.baseServings;

    return Container(
      padding: const EdgeInsets.all(KsTokens.space20),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$servings',
                style: KsTokens.displayLarge.copyWith(
                  color: isDark ? ks.brandPrimary : ks.textPrimary,
                  fontSize: 48,
                  height: 0.9,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              Text(
                'SERVINGS',
                style: KsTokens.labelMedium.copyWith(
                  color: ks.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: ks.brandPrimary,
              inactiveTrackColor: ks.neutralSubtle,
              thumbColor: ks.surfaceRaised,
              overlayColor: ks.brandPrimary.withValues(alpha: 0.12),
              thumbShape: _RingThumbShape(
                ringColor: ks.brandPrimary,
                fillColor: ks.surfaceRaised,
              ),
            ),
            child: Slider(
              value: _dragValue.clamp(
                widget.min.toDouble(),
                widget.max.toDouble(),
              ),
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.max - widget.min,
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                setState(() {
                  _dragValue = v;
                  _committed = v.round();
                });
                widget.onChanged?.call(_committed);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.min}', style: _boundStyle(ks)),
              Text('${widget.max}', style: _boundStyle(ks)),
            ],
          ),
          const SizedBox(height: KsTokens.space16),
          Divider(height: 1, thickness: 1, color: ks.hairline),
          const SizedBox(height: KsTokens.space16),
          for (final ingredient in widget.ingredients) ...[
            _IngredientRow(ingredient: ingredient, ratio: ratio),
            if (ingredient != widget.ingredients.last)
              const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  TextStyle _boundStyle(KsColors ks) => KsTokens.labelSmall.copyWith(
    color: ks.textTertiary,
    fontSize: 10,
    letterSpacing: 0,
    height: 1,
  );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.ratio});

  final KsScalableIngredient ingredient;
  final double ratio;

  static String _fmt(double v) {
    if ((v - v.roundToDouble()).abs() < 0.05) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final amount = ingredient.baseAmount * ratio;
    final value = ingredient.unit.isEmpty
        ? _fmt(amount)
        : '${_fmt(amount)} ${ingredient.unit}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          ingredient.name,
          style: KsTokens.bodySmall.copyWith(
            color: ks.textSecondary,
            fontSize: 13,
            height: 1.3,
          ),
        ),
        Text(
          value,
          style: KsTokens.labelMedium.copyWith(
            color: ks.textPrimary,
            fontSize: 13,
            letterSpacing: 0,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// A ringed slider thumb — a raised disc with a brand-coloured ring, matching
/// the design-system slider knob.
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({required this.ringColor, required this.fillColor});

  final Color ringColor;
  final Color fillColor;

  static const double _radius = 11;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas
      ..drawCircle(center, _radius, Paint()..color = fillColor)
      ..drawCircle(
        center,
        _radius - 1,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }
}
