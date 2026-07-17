part of 'shopping_screen.dart';

class _ShoppingHomeBody extends ConsumerWidget {
  const _ShoppingHomeBody({
    required this.upcoming,
    required this.suggestions,
    required this.history,
    required this.canShopNow,
    required this.canManageLists,
    required this.canManageSchedule,
    required this.onShopNow,
  });

  final List<ShoppingListRecord> upcoming;
  final List<ShoppingListRecord> suggestions;
  final List<ShoppingListRecord> history;
  final bool canShopNow;
  final bool canManageLists;
  final bool canManageSchedule;
  final VoidCallback onShopNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space8,
        KsTokens.space16,
        KsTokens.space24,
      ),
      children: [
        const KsFolioHeader(eyebrow: 'The Shop', title: 'Shopping'),
        const SizedBox(height: KsTokens.space16),
        _ShopNowCard(
          onStart: canShopNow ? onShopNow : null,
          locked: !canShopNow,
        ),
        const SizedBox(height: KsTokens.space20),
        if (suggestions.isNotEmpty) ...[
          const _SectionLabel('Suggestions'),
          const SizedBox(height: KsTokens.space10),
          for (final list in suggestions) ...[
            _SuggestionTile(
              list: list,
              onAccept: () => context.push('/shop/list/${list.id}'),
              onIgnore:
                  canManageLists &&
                      list.originId == ShoppingSuggestionOrigin.coreRecovery.id
                  ? () => _ignoreSuggestion(context, ref, list)
                  : null,
            ),
            const SizedBox(height: KsTokens.space8),
          ],
          const SizedBox(height: KsTokens.space12),
        ],
        const _SectionLabel('Upcoming'),
        const SizedBox(height: KsTokens.space10),
        if (upcoming.isEmpty)
          KsEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No shopping lists yet',
            subtitle: canManageSchedule
                ? 'Schedule meals, set a weekly shop day, or start a Shop Now '
                      'list.'
                : 'Schedule meals or start a Shop Now list. An Admin manages '
                      'the weekly schedule.',
            action: canManageSchedule
                ? FilledButton.icon(
                    onPressed: () =>
                        context.push('/calendar/shopping-schedule'),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Set weekly shop day'),
                  )
                : null,
          )
        else
          for (final list in upcoming) ...[
            _UpcomingTile(
              shop: _UpcomingShop.fromRecord(list),
              onTap: () => context.push('/shop/list/${list.id}'),
            ),
            const SizedBox(height: KsTokens.space8),
          ],
        const SizedBox(height: KsTokens.space12),
        Row(
          children: [
            const _SectionLabel('History'),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/shop/history'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space10),
        if (history.isEmpty)
          const _HistoryRow(label: 'No completed shops yet.')
        else
          for (final list in history.take(3))
            _HistoryRow(
              label: _historyLabel(list),
              onTap: () => context.push('/shop/list/${list.id}'),
            ),
      ],
    );
  }

  Future<void> _ignoreSuggestion(
    BuildContext context,
    WidgetRef ref,
    ShoppingListRecord list,
  ) async {
    try {
      await ref
          .read(shoppingPlanningControllerProvider)
          .cancelRecoverySuggestion(list);
      ref.invalidate(activeShoppingListsProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_typeLabel(list.type)} ignored')),
      );
    } on ShoppingCommandFailure catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            const ShoppingCommandFailure(
              ShoppingCommandFailureKind.unknown,
            ).userMessage,
          ),
        ),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: KsTokens.shoppingHomeSectionLabel.copyWith(
        color: context.ksColors.textTertiary,
      ),
    );
  }
}
