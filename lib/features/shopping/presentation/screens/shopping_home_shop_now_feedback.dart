part of 'shopping_screen.dart';

class _ShopNowPreviewSummary extends ConsumerWidget {
  const _ShopNowPreviewSummary({required this.preview});

  final ShoppingListPlan? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = preview?.items.length;
    final text = count == null
        ? 'Preparing your preview...'
        : count == 0
        ? 'Nothing to buy for this range.'
        : '$count ${count == 1 ? 'item' : 'items'} to buy.';
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (count != null && count > 0) ...[
            const SizedBox(height: KsTokens.space8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.ksColors.border),
                  borderRadius: BorderRadius.circular(KsTokens.radius12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: preview!.items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.ksColors.hairline),
                  itemBuilder: (context, index) {
                    final item = preview!.items[index];
                    final ingredient = ref
                        .watch(
                          _shoppingPreviewIngredientProvider(item.ingredientId),
                        )
                        .valueOrNull;
                    return ListTile(
                      dense: true,
                      title: Text(
                        ingredient == null
                            ? item.ingredientId
                            : _shoppingPreviewIngredientName(
                                context,
                                ingredient,
                              ),
                      ),
                      trailing: Text(
                        _shoppingPreviewQuantity(
                          item.quantity,
                          item.unit,
                          ingredient?.localUnitDefinitions ??
                              const <UnitDefinition>[],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          if (count == 0) ...[
            const SizedBox(height: KsTokens.space4),
            Text(
              'Choose a longer range or plan meals before generating a list.',
              style: KsTokens.bodySmall.copyWith(
                color: context.ksColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopNowPreviewError extends StatelessWidget {
  const _ShopNowPreviewError({
    required this.error,
    required this.onRetry,
    required this.message,
  });

  final Object error;
  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      KsErrorAlert(message: message),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}
