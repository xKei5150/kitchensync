import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Wraps a focusable [child] (typically a [TextField]) in an accessible focus
/// ring — a solid 3px [KsColors.focusRing] band painted around the field when
/// its [focusNode] holds focus.
///
/// Mirrors the spec's `box-shadow: 0 0 0 3px focus-ring@24%` — a dual-tone
/// indicator that clears 3:1 contrast on any surface. From
/// "KitchenSync — Components I (Primitives)", Inputs.
class KsFocusRing extends StatefulWidget {
  const KsFocusRing({
    required this.focusNode,
    required this.child,
    this.borderRadius = KsTokens.radius10,
    super.key,
  });

  /// The same node attached to the wrapped field. The ring reacts to it.
  final FocusNode focusNode;

  /// The field to wrap.
  final Widget child;

  /// Corner radius of the ring — match the field's own radius.
  final double borderRadius;

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
    final ring = context.ksColors.focusRing;
    return AnimatedContainer(
      duration: KsTokens.durationFast,
      curve: KsTokens.curveStandard,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: _focused
            ? [BoxShadow(color: ring.withValues(alpha: 0.24), spreadRadius: 3)]
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
