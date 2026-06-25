import 'package:flutter/material.dart';

/// Guarantees an accessible pressable area of at least [minSize] logical pixels
/// around a smaller [child] visual — the rule made literal in
/// "KitchenSync — P4 Accessibility States", Screen 22: the *pressable area* is
/// sized for a fingertip (≥44/48px) even when the *glyph* is deliberately
/// smaller. The dashed box in the spec is this widget's bounds; the icon is the
/// visual that floats centred inside it.
///
/// Use this to keep small header discs, close buttons, and avatars tappable and
/// labelled without inflating their visual weight. It always exposes a
/// [Semantics] button with [label] so screen readers announce a real target.
class KsHitTarget extends StatelessWidget {
  const KsHitTarget({
    required this.onTap,
    required this.child,
    this.label,
    this.minSize = 48,
    this.shape = BoxShape.circle,
    super.key,
  });

  /// Tapped when the area is pressed. A null callback renders a disabled
  /// (non-interactive) target that still reserves the space.
  final VoidCallback? onTap;

  /// The visual — typically smaller than [minSize] — centred in the target.
  final Widget child;

  /// Accessible label, surfaced as a tooltip and the semantics label.
  final String? label;

  /// The minimum width and height of the pressable area (WCAG 2.5.5 / 2.5.8).
  final double minSize;

  /// Splash and ink shape. Circle for discs/avatars, rectangle for square
  /// chrome buttons.
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == BoxShape.circle;
    final inkShape = isCircle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(minSize));

    Widget target = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: inkShape,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );

    if (label != null) {
      target = Tooltip(message: label, child: target);
    }

    // Merge into a single node: the explicit button + label here, plus the
    // InkWell's tap action below — so the whole target announces as one
    // labelled control rather than a label node wrapping a separate button.
    return MergeSemantics(
      child: Semantics(button: true, label: label, child: target),
    );
  }
}
