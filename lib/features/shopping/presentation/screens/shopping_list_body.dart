part of 'shopping_list_screen.dart';

class _ShoppingListBody extends StatelessWidget {
  const _ShoppingListBody({
    required this.list,
    required this.lines,
    required this.totalFallback,
    required this.onToggle,
    required this.onDone,
    required this.canEdit,
    required this.canComplete,
    required this.canDelete,
    required this.isCompleting,
    required this.isMutating,
    required this.busyItemId,
    required this.completionError,
    required this.onAdd,
    required this.completedByName,
    required this.onRemoveList,
    this.onStatus,
    this.onEditNeeded,
    this.onEditPurchased,
    this.onRemove,
    this.onSubstitute,
  });

  final ShoppingListRecord list;
  final List<_ShopLine> lines;
  final int totalFallback;
  final ValueChanged<String> onToggle;
  final VoidCallback onDone;
  final bool canEdit;
  final bool canComplete;
  final bool canDelete;
  final bool isCompleting;
  final bool isMutating;
  final String? busyItemId;
  final String? completionError;
  final VoidCallback onAdd;
  final String completedByName;
  final VoidCallback onRemoveList;
  final void Function(
    String itemId,
    ShoppingListItemStatus status,
    double? purchasedQuantity,
  )?
  onStatus;
  final Future<void> Function(String itemId)? onEditNeeded;
  final Future<void> Function(String itemId)? onEditPurchased;
  final Future<void> Function(String itemId)? onRemove;
  final Future<void> Function(String itemId)? onSubstitute;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final done = lines
        .where(
          (line) =>
              line.state == ChecklistItemState.bought ||
              line.state == ChecklistItemState.substituted,
        )
        .length;
    final total = totalFallback;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            KsFolioHeader(
              eyebrow: _listMetadata(list),
              title: _shoppingListTypeLabel(list.type),
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
                if (canEdit)
                  KsHeaderAction(
                    icon: Icons.add_rounded,
                    tooltip: 'Add ingredient',
                    onTap: onAdd,
                  ),
                if (canDelete)
                  KsHeaderAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Remove list',
                    onTap: isMutating ? null : onRemoveList,
                  ),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            if (list.status == ShoppingListStatus.completed) ...[
              _CompletedShoppingSummary(
                list: list,
                completedByName: completedByName,
              ),
              const SizedBox(height: KsTokens.space12),
            ],
            _ProgressBar(done: done, total: total),
            const SizedBox(height: KsTokens.space16),
            if (lines.isEmpty)
              KsEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Nothing to buy',
                subtitle: canEdit
                    ? 'Add an ingredient when needed.'
                    : 'This list has no shopping items.',
                action: canEdit
                    ? FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add ingredient'),
                      )
                    : null,
              )
            else
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: ks.surfaceRaised,
                  borderRadius: BorderRadius.circular(KsTokens.radius16),
                  border: Border.all(color: ks.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: ks.hairline),
                      _ShoppingChecklistRow(
                        line: lines[i],
                        isBusy: busyItemId == lines[i].key,
                        onToggle: canEdit ? () => onToggle(lines[i].key) : null,
                        onLongPress: canEdit
                            ? () => _openItemActions(context, lines[i])
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: KsTokens.space16),
            if (list.status == ShoppingListStatus.pending &&
                !canEdit &&
                !canComplete) ...[
              Text(
                'Shopper access required to update or finish this list.',
                style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
              ),
              const SizedBox(height: KsTokens.space12),
            ],
            if (isMutating) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: KsTokens.space12),
            ],
            if (completionError != null) ...[
              KsErrorAlert(message: completionError!),
              const SizedBox(height: KsTokens.space12),
            ],
            if (list.status == ShoppingListStatus.pending && canComplete)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canComplete && !isCompleting ? onDone : null,
                  style: isCompleting
                      ? FilledButton.styleFrom(
                          disabledBackgroundColor: ks.disabledFill,
                          disabledForegroundColor: ks.textPrimary,
                        )
                      : null,
                  child: Text(
                    isCompleting ? 'Finishing shop...' : 'Done shopping',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openItemActions(BuildContext context, _ShopLine line) async {
    final action = await showModalBottomSheet<_ShoppingItemAction>(
      context: context,
      builder: (_) => _ShoppingItemActionSheet(line: line),
    );
    if (action == null) return;
    switch (action) {
      case _ShoppingItemAction.bought:
        onStatus?.call(
          line.key,
          ShoppingListItemStatus.bought,
          line.purchasedQuantity ?? line.quantityValue,
        );
      case _ShoppingItemAction.toBuy:
        onStatus?.call(line.key, ShoppingListItemStatus.unchecked, null);
      case _ShoppingItemAction.editNeeded:
        await onEditNeeded?.call(line.key);
      case _ShoppingItemAction.editPurchased:
        await onEditPurchased?.call(line.key);
      case _ShoppingItemAction.unavailable:
        onStatus?.call(line.key, ShoppingListItemStatus.unavailable, null);
      case _ShoppingItemAction.skipped:
        onStatus?.call(line.key, ShoppingListItemStatus.skipped, null);
      case _ShoppingItemAction.substitute:
        await onSubstitute?.call(line.key);
      case _ShoppingItemAction.remove:
        await onRemove?.call(line.key);
    }
  }
}

class _CompletedShoppingSummary extends StatelessWidget {
  const _CompletedShoppingSummary({
    required this.list,
    required this.completedByName,
  });

  final ShoppingListRecord list;
  final String completedByName;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final completedAt = DateFormat(
      'd MMM y, h:mm a',
    ).format(list.completionTime);
    final range =
        '${DateFormat('d MMM').format(list.generatedForRangeStart)}'
        ' - ${DateFormat('d MMM y').format(list.generatedForRangeEnd)}';
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed $completedAt',
            style: KsTokens.labelMedium.copyWith(color: ks.textPrimary),
          ),
          const SizedBox(height: KsTokens.space4),
          Text(
            'Completed by $completedByName · '
            '${_shoppingListTypeLabel(list.type)} · $range',
            style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
          ),
        ],
      ),
    );
  }
}
