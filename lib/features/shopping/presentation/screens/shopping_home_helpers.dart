part of 'shopping_screen.dart';

String _typeLabel(ShoppingListType type) => switch (type) {
  ShoppingListType.scheduled => 'Scheduled list',
  ShoppingListType.shopNow => 'Shop Now',
  ShoppingListType.suggested => 'Suggested list',
  ShoppingListType.emergency => 'Emergency list',
};

Color _typeColor(KsColors ks, ShoppingListType type) => switch (type) {
  ShoppingListType.emergency => ks.danger,
  ShoppingListType.suggested => ks.warning,
  _ => ks.calShopping,
};

String _historyLabel(ShoppingListRecord list) =>
    '${_shortDate(list.updatedAt)} · ${list.items.length} '
    '${list.items.length == 1 ? 'item' : 'items'} · ${_typeLabel(list.type)}';

String _shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KsTokens.space4),
          child: Row(
            children: [
              const Icon(Icons.check_rounded, size: 16, color: KsTokens.fresh),
              const SizedBox(width: KsTokens.space10),
              Expanded(
                child: Text(
                  label,
                  style: KsTokens.bodySmall.copyWith(
                    color: ks.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: ks.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
