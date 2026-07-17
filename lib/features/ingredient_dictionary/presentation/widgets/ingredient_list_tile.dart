import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

class IngredientListTile extends StatelessWidget {
  const IngredientListTile({
    super.key,
    required this.ingredient,
    this.onTap,
    this.onDetails,
    this.indent = false,
  });

  final Ingredient ingredient;
  final VoidCallback? onTap;
  final VoidCallback? onDetails;
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
                      color: context.ksColors.borderStrong,
                      borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                    ),
                  ),
                ],
                KsThumbnail(
                  imageUrl: ingredient.imageUrl,
                  categoryColor: category.color,
                  size: 44,
                  radius: KsTokens.radius10,
                  icon: Icons.local_grocery_store_outlined,
                  iconSize: 20,
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
                if (onDetails != null)
                  IconButton(
                    tooltip: 'Ingredient details',
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline, size: 20),
                  )
                else if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: context.ksColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
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
        if (indent)
          const KsTag(
            label: 'Variant',
            color: KsTokens.brandAccent,
            size: KsTagSize.sm,
          ),
        KsTag.category(category, size: KsTagSize.sm),
        if (isBulk)
          const KsTag(
            label: 'Bulk',
            color: KsTokens.sectionBulk,
            size: KsTagSize.sm,
          ),
        if (isNonFood)
          const KsTag(
            label: 'Non-food',
            color: KsTokens.sectionNonFood,
            size: KsTagSize.sm,
          ),
      ],
    );
  }
}
