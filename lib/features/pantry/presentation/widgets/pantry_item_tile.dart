import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';
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
                  _FreshnessBar(freshness: freshness),
                  _Thumbnail(
                    imageUrl: item.imageUrl,
                    categoryColor: category?.color ?? KsTokens.catOther,
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
                            _ExpiryBadge(
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

class _FreshnessBar extends StatelessWidget {
  const _FreshnessBar({required this.freshness});

  final Freshness freshness;

  @override
  Widget build(BuildContext context) {
    final color = freshness == Freshness.unknown
        ? KsTokens.border
        : freshness.color;

    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(KsTokens.radius16),
          bottomLeft: Radius.circular(KsTokens.radius16),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl, required this.categoryColor});

  final String? imageUrl;
  final Color categoryColor;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: KsTokens.space8,
        top: KsTokens.space12,
        bottom: KsTokens.space12,
      ),
      child: SizedBox(
        width: _size,
        height: _size,
        child: imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(KsTokens.radius12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _Placeholder(color: categoryColor),
                  errorWidget: (_, __, ___) =>
                      _Placeholder(color: categoryColor),
                ),
              )
            : _Placeholder(color: categoryColor),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
      child: Icon(
        Icons.local_dining,
        size: 24,
        color: color.withValues(alpha: 0.7),
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
          _CategoryTag(category: category!),
        ],
      ],
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final IngredientCategory category;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space6,
        vertical: KsTokens.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KsTokens.radius4),
      ),
      child: Text(
        category.name,
        style: KsTokens.labelSmall.copyWith(
          color: color.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: KsTokens.textPrimary,
          ),
        ),
        if (isLowStock) ...[
          const SizedBox(width: KsTokens.space8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KsTokens.space6,
              vertical: KsTokens.space2,
            ),
            decoration: BoxDecoration(
              color: KsTokens.lowStock.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KsTokens.radius4),
            ),
            child: Text(
              'Low',
              style: KsTokens.labelSmall.copyWith(
                color: KsTokens.lowStock,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.freshness, required this.label});

  final Freshness freshness;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = freshness.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: KsTokens.space6),
        Text(
          label,
          style: KsTokens.bodySmall.copyWith(
            color: freshness == Freshness.unknown
                ? KsTokens.textTertiary
                : color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
