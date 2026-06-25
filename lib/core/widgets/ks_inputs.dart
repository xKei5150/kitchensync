import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Wraps a focusable [child] (typically a [TextField]) in the app-wide
/// focus-visible treatment — a 2px [KsColors.focusRing] ring with a 2px
/// surface-coloured offset, painted around the [child] while its [focusNode]
/// holds focus.
///
/// This is the single focus treatment used across every interactive primitive
/// (the rule from "KitchenSync — P4 Accessibility States", Screen 22). The 2px
/// offset gap is what makes it read on *any* fill — including a brand-green
/// button, where a ring drawn flush to the edge would otherwise disappear.
/// Mirrors the spec's `box-shadow: 0 0 0 2px <surface>, 0 0 0 4px <ring>`.
class KsFocusRing extends StatefulWidget {
  const KsFocusRing({
    required this.focusNode,
    required this.child,
    this.borderRadius = KsTokens.radius10,
    this.offsetColor,
    super.key,
  });

  /// The same node attached to the wrapped field. The ring reacts to it.
  final FocusNode focusNode;

  /// The field to wrap.
  final Widget child;

  /// Corner radius of the ring — match the field's own radius.
  final double borderRadius;

  /// Colour of the 2px gap between the [child] and the ring. Defaults to the
  /// base surface; override when the field sits on a raised card so the gap
  /// stays invisible against its real backdrop.
  final Color? offsetColor;

  @override
  State<KsFocusRing> createState() => _KsFocusRingState();
}

class _KsFocusRingState extends State<KsFocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(KsFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
      _focused = widget.focusNode.hasFocus;
    }
  }

  void _onFocusChanged() {
    final hasFocus = widget.focusNode.hasFocus;
    if (mounted && hasFocus != _focused) {
      setState(() => _focused = hasFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final ring = ks.focusRing;
    final offset = widget.offsetColor ?? ks.surfaceBase;
    return AnimatedContainer(
      duration: KsTokens.durationFast,
      curve: KsTokens.curveStandard,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        // Painted back-to-front: the 4px ring sits behind, then a 2px gap of
        // the surrounding surface covers its inner edge — leaving a crisp 2px
        // ring floating clear of the field on any fill.
        boxShadow: _focused
            ? [
                BoxShadow(color: ring, spreadRadius: 4),
                BoxShadow(color: offset, spreadRadius: 2),
              ]
            : const [],
      ),
      child: widget.child,
    );
  }
}

/// A calm search field — a leading magnifier glyph, a hint, and the accessible
/// [KsFocusRing]. Consolidates the hand-rolled search `TextField` previously
/// inlined in the ingredient picker.
///
/// From "KitchenSync — Components I (Primitives)", Inputs.
class KsSearchField extends StatefulWidget {
  const KsSearchField({
    this.controller,
    this.hintText = 'Search',
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
    super.key,
  });

  final TextEditingController? controller;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<KsSearchField> createState() => _KsSearchFieldState();
}

class _KsSearchFieldState extends State<KsSearchField> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return KsFocusRing(
      focusNode: _focusNode,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        textInputAction: widget.textInputAction ?? TextInputAction.search,
        style: KsTokens.bodyLarge.copyWith(color: ks.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: ks.textTertiary, size: 20),
          hintText: widget.hintText,
          filled: true,
          fillColor: ks.surfaceRaised,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KsTokens.radius10),
            borderSide: BorderSide(color: ks.borderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KsTokens.radius10),
            borderSide: BorderSide(color: ks.brandPrimary, width: 2),
          ),
        ),
      ),
    );
  }
}
