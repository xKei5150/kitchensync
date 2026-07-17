part of 'ks_checklist_row.dart';

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.state, this.onTap});

  final ChecklistItemState state;
  final VoidCallback? onTap;
  static const double _size = 22;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final Widget box = switch (state) {
      ChecklistItemState.bought || ChecklistItemState.substituted => Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ks.brandPrimary,
          borderRadius: BorderRadius.circular(KsTokens.radius6),
        ),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      ),
      ChecklistItemState.unavailable => Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KsTokens.radius6),
          border: Border.all(color: ks.danger, width: 2),
        ),
        child: Icon(Icons.close_rounded, size: 13, color: ks.danger),
      ),
      ChecklistItemState.skipped => KsDashedBorder(
        color: ks.borderStrong,
        radius: KsTokens.radius6,
        strokeWidth: 2,
        child: const SizedBox(width: _size, height: _size),
      ),
      ChecklistItemState.toBuy => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KsTokens.radius6),
          border: Border.all(color: ks.borderStrong, width: 2),
        ),
      ),
    };
    return onTap == null
        ? box
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: box,
          );
  }
}
