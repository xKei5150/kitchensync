import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

class PantryItemTile extends ConsumerWidget {
  const PantryItemTile({required this.item, this.onTap, super.key});

  final PantryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientAsync = ref.watch(
      pantryIngredientProvider(item.ingredientId),
    );

    final ingredient = ingredientAsync.when(
      data: (result) => switch (result) {
        Success(:final value) => value,
        ResultFailure() => null,
      },
      loading: () => null,
      error: (_, __) => null,
    );

    final category = ingredient?.category;

    final name = ingredient?.displayNames['en'] ?? item.ingredientId;

    final freshness = FreshnessHelper.fromExpiry(item.expiryDate);
    final expiryLabel = FreshnessHelper.relativeLabel(item.expiryDate);
    final freshnessLabel = expiryLabel.isEmpty
        ? freshness.label
        : '${freshness.label} · $expiryLabel';
    final measurement = ref.watch(localeFormattersProvider).measurement;
    final quantityLabel = measurement.formatUnit(
      item.quantity,
      item.unit,
      localUnitDefinitions:
          ingredient?.localUnitDefinitions ?? const <UnitDefinition>[],
    );
    final isLowStock = item.quantity <= 1;
    final ks = context.ksColors;

    return Semantics(
      label: '$name $quantityLabel ${freshness.label}',
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius16),
          child: Container(
            decoration: BoxDecoration(
              color: ks.surfaceRaised,
              borderRadius: BorderRadius.circular(KsTokens.radius16),
              border: Border.all(color: ks.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KsFreshnessBar(freshness: freshness),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: KsTokens.space8,
                      top: KsTokens.space12,
                      bottom: KsTokens.space12,
                    ),
                    child: KsThumbnail(
                      imageUrl: item.imageUrl,
                      categoryColor: category?.color ?? KsTokens.catOther,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KsTokens.space12,
                        vertical: KsTokens.space12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Header(name: name, category: category),
                          const SizedBox(height: KsTokens.space6),
                          _QuantityRow(
                            text: quantityLabel,
                            isLowStock: isLowStock,
                          ),
                          if (expiryLabel.isNotEmpty) ...[
                            const SizedBox(height: KsTokens.space6),
                            KsExpiryBadge(
                              freshness: freshness,
                              label: freshnessLabel,
                            ),
                          ] else ...[
                            const SizedBox(height: KsTokens.space6),
                            KsExpiryBadge(
                              freshness: freshness,
                              label: freshness.label,
                            ),
                          ],
                          if (item.lastPurchaseDate != null) ...[
                            const SizedBox(height: KsTokens.space6),
                            _LastPurchased(date: item.lastPurchaseDate!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LastPurchased extends StatelessWidget {
  const _LastPurchased({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shopping_bag_outlined, size: 14, color: ks.textTertiary),
        const SizedBox(width: KsTokens.space4),
        Flexible(
          child: Text(
            'Last purchased ${_formatDate(date)}',
            style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  const _Header({required this.name, this.category});

  final String name;
  final IngredientCategory? category;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (category != null) ...[
          const SizedBox(width: KsTokens.space8),
          KsTag.category(category!, size: KsTagSize.sm),
        ],
      ],
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({required this.text, this.isLowStock = false});

  /// The formatted quantity and unit, e.g. `800 g` or `1.8 lb`.
  final String text;
  final bool isLowStock;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          text,
          style: KsTokens.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: context.ksColors.textPrimary,
          ),
        ),
        if (isLowStock) ...[
          const SizedBox(width: KsTokens.space8),
          KsTag.lowStock(),
        ],
      ],
    );
  }
}
