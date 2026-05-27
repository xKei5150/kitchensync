import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    return Semantics(
      button: onTap != null,
      label: name,
      child: ListTile(
        contentPadding: EdgeInsets.fromLTRB(indent ? 32 : 16, 4, 16, 4),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: ingredient.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ingredient.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFFEEEEEE)),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 24),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_grocery_store, size: 20),
                ),
        ),
        title: Text(name),
        subtitle: Text(
          ingredient.category.name,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onTap,
      ),
    );
  }
}
