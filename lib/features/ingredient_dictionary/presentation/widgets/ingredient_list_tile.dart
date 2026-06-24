import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

class IngredientListTile extends StatelessWidget {
  const IngredientListTile({
    super.key,
    required this.ingredient,
    this.onTap,
    this.indent = false,
  });

  final Ingredient ingredient;
  final VoidCallback? onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final name = ingredient.displayNames['en'] ?? ingredient.name;
    final category = ingredient.category;

    return Semantics(
      button: onTap != null,
      label: name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              indent ? KsTokens.space24 : KsTokens.space16,
              KsTokens.space10,
              KsTokens.space16,
              KsTokens.space10,
            ),
            child: Row(
              children: [
                if (indent) ...[
                  Container(
                    width: 2,
                    height: 36,
                    margin: const EdgeInsets.only(right: KsTokens.space12),
                    decoration: BoxDecoration(
                      color: KsTokens.borderStrong,
                      borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                    ),
                  ),
                ],
                _Thumbnail(
                  imageUrl: ingredient.imageUrl,
                  categoryColor: category.color,
                ),
                const SizedBox(width: KsTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: KsTokens.space2),
                      _Subtitle(
                        category: category,
                        indent: indent,
                        isBulk: ingredient.isBulkCandidate,
                        isNonFood: ingredient.isNonFood,
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: KsTokens.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl, required this.categoryColor});

  final String? imageUrl;
  final Color categoryColor;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(KsTokens.radius10),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Placeholder(color: categoryColor),
                errorWidget: (_, __, ___) => _Placeholder(color: categoryColor),
              ),
            )
          : _Placeholder(color: categoryColor),
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
        borderRadius: BorderRadius.circular(KsTokens.radius10),
      ),
      child: Icon(
        Icons.local_grocery_store_outlined,
        size: 20,
        color: color.withValues(alpha: 0.7),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.category,
    required this.indent,
    required this.isBulk,
    required this.isNonFood,
  });

  final IngredientCategory category;
  final bool indent;
  final bool isBulk;
  final bool isNonFood;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: KsTokens.space6,
      runSpacing: KsTokens.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (indent) _MiniTag(label: 'Variant', color: KsTokens.brandAccent),
        _MiniTag(label: category.name, color: category.color),
        if (isBulk) _MiniTag(label: 'Bulk', color: KsTokens.sectionBulk),
        if (isNonFood)
          _MiniTag(label: 'Non-food', color: KsTokens.sectionNonFood),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space6,
        vertical: KsTokens.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KsTokens.radius4),
      ),
      child: Text(
        label,
        style: KsTokens.labelSmall.copyWith(
          color: color.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
