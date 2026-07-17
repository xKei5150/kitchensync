part of 'ks_nav.dart';

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final KsNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final color = selected ? ks.brandPrimary : ks.textTertiary;
    final icon = selected
        ? (destination.activeIcon ?? destination.icon)
        : destination.icon;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KsTokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: KsTokens.space4),
                Text(
                  destination.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: KsTokens.labelSmall.copyWith(
                    color: color,
                    fontSize: 9,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
