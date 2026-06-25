import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/motion.dart';

/// Screen 27 · Honest waiting.
///
/// A shimmer placeholder over [KsColors.neutralSubtle] for content whose shape
/// is already known — lists, item cards, recipe detail. A skeleton mirrors the
/// real layout so nothing jumps when content lands; it is never a blank screen
/// or a lonely spinner.
///
/// Motion is compositor-friendly: a left-to-right highlight sweep on the
/// gradient (1.4s linear) by default, collapsing to a calm opacity pulse under
/// the platform reduce-motion setting — there is no travel to make someone
/// queasy. Reads `context.reduceMotion`, so it yields with the rest of the app
/// (the "Loading" row of the P4 motion map).
class KsSkeleton extends StatefulWidget {
  const KsSkeleton({
    this.width,
    this.height,
    this.radius = KsTokens.radius6,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  /// A circular skeleton of [size] — for avatars, status dots, and glyph discs.
  const KsSkeleton.circle({required double size, Key? key})
    : this(width: size, height: size, shape: BoxShape.circle, key: key);

  /// A single text line of [width], pill-capped — for titles and meta rows.
  const KsSkeleton.line({double? width, double height = 12, Key? key})
    : this(width: width, height: height, radius: KsTokens.radiusFull, key: key);

  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;

  @override
  State<KsSkeleton> createState() => _KsSkeletonState();
}

class _KsSkeletonState extends State<KsSkeleton>
    with SingleTickerProviderStateMixin {
  // 1.4s sweep / 1.6s pulse — one shared period so rows built together read as
  // a single surface rather than a field of independently-flickering boxes.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final reduced = context.reduceMotion;
    final base = ks.neutralSubtle;
    final highlight = Color.lerp(base, ks.surfaceRaised, 0.55)!;
    final isCircle = widget.shape == BoxShape.circle;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Reduced motion: a stationary opacity pulse, nothing travels.
        if (reduced) {
          final t = (_controller.value * 2 - 1).abs(); // triangle 0→1→0
          return Opacity(
            opacity: lerpDouble(0.55, 1, t)!,
            child: _box(base, isCircle, null),
          );
        }
        // Default: a highlight band sweeps left→right across the fill.
        final dx = lerpDouble(-2, 2, _controller.value)!;
        final gradient = LinearGradient(
          begin: Alignment(dx - 1, 0),
          end: Alignment(dx + 1, 0),
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
        );
        return _box(base, isCircle, gradient);
      },
    );
  }

  Widget _box(Color base, bool isCircle, Gradient? gradient) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: gradient == null ? base : null,
        gradient: gradient,
        shape: widget.shape,
        borderRadius: isCircle ? null : BorderRadius.circular(widget.radius),
      ),
    );
  }
}
