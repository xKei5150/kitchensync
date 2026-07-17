part of 'shopping_screen.dart';

class _UpcomingShop {
  const _UpcomingShop({
    required this.title,
    required this.when,
    required this.type,
  });

  factory _UpcomingShop.fromRecord(ShoppingListRecord list) {
    return _UpcomingShop(
      title: _typeLabel(list.type),
      when: list.items.isEmpty
          ? 'Nothing to buy'
          : '${_shortDate(list.shoppingDate)} · ${list.items.length} '
                '${list.items.length == 1 ? 'item' : 'items'}',
      type: list.type,
    );
  }

  final String title;
  final String when;
  final ShoppingListType type;
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.shop, required this.onTap});

  final _UpcomingShop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: KsTokens.shoppingHomeListTilePadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Row(
            children: [
              Container(
                width: KsTokens.shoppingHomeListLeadingSize,
                height: KsTokens.shoppingHomeListLeadingSize,
                decoration: BoxDecoration(
                  color: _typeColor(ks, shop.type).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: KsTokens.shoppingHomeListIconSize,
                  color: _typeColor(ks, shop.type),
                ),
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.title,
                      style: KsTokens.shoppingHomeListTitle.copyWith(
                        color: ks.textPrimary,
                      ),
                    ),
                    const SizedBox(height: KsTokens.space2),
                    Text(
                      shop.when,
                      style: KsTokens.shoppingHomeListMetadata.copyWith(
                        color: ks.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: KsTokens.shoppingHomeListIconSize,
                color: ks.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.list,
    required this.onAccept,
    this.onIgnore,
  });

  final ShoppingListRecord list;
  final VoidCallback onAccept;
  final VoidCallback? onIgnore;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final accent = _typeColor(ks, list.type);
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          ks.surfaceRaised,
        ),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: KsTokens.shoppingHomeListLeadingSize,
            height: KsTokens.shoppingHomeListLeadingSize,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(KsTokens.radius10),
            ),
            child: Icon(
              list.type == ShoppingListType.emergency
                  ? Icons.warning_amber_rounded
                  : Icons.auto_awesome_rounded,
              size: KsTokens.shoppingHomeListIconSize,
              color: accent,
            ),
          ),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(list.type),
                  style: KsTokens.shoppingHomeListTitle.copyWith(
                    color: ks.textPrimary,
                  ),
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  '${list.items.length} '
                  '${list.items.length == 1 ? 'item' : 'items'} · '
                  '${_shortDate(list.shoppingDate)}',
                  style: KsTokens.shoppingHomeListMetadata.copyWith(
                    color: ks.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Open suggestion',
            onPressed: onAccept,
            icon: const Icon(
              Icons.list_alt_rounded,
              size: KsTokens.shoppingHomeListIconSize,
            ),
          ),
          if (onIgnore != null) ...[
            const SizedBox(width: KsTokens.space4),
            IconButton(
              tooltip: 'Ignore suggestion',
              onPressed: onIgnore,
              icon: const Icon(
                Icons.close_rounded,
                size: KsTokens.shoppingHomeListIconSize,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
