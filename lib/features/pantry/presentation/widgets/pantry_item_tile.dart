import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
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

    final name = ingredientAsync.when(
      data: (result) => switch (result) {
        Success(:final value) => value.displayNames['en'] ?? item.ingredientId,
        ResultFailure() => item.ingredientId,
      },
      loading: () => item.ingredientId,
      error: (_, __) => item.ingredientId,
    );

    final category = ingredientAsync.when(
      data: (result) => switch (result) {
        Success(:final value) => value.category,
        ResultFailure() => null,
      },
      loading: () => null,
      error: (_, __) => null,
    );

    final freshness = FreshnessHelper.fromExpiry(item.expiryDate);
    final expiryLabel = FreshnessHelper.relativeLabel(item.expiryDate);
    final qty = QuantityFormatter.format(item.quantity);
    final unit = item.unit.name;
    final isLowStock = item.quantity <= 1;

    return Semantics(
      label: '$name $qty $unit ${freshness.label}',
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius16),
          child: Container(
            decoration: BoxDecoration(
              color: KsTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(KsTokens.radius16),
              border: Border.all(color: KsTokens.border),
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
                            qty: qty,
                            unit: unit,
                            isLowStock: isLowStock,
                          ),
                          if (expiryLabel.isNotEmpty) ...[
                            const SizedBox(height: KsTokens.space6),
                            KsExpiryBadge(
                              freshness: freshness,
                              label: expiryLabel,
                            ),
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
  const _QuantityRow({
    required this.qty,
    required this.unit,
    this.isLowStock = false,
  });

  final String qty;
  final String unit;
  final bool isLowStock;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$qty $unit',
          style: KsTokens.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: KsTokens.textPrimary,
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
