import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

class IngredientDetailScreen extends ConsumerWidget {
  const IngredientDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final getIngredient = ref.watch(getIngredientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ingredient')),
      body: FutureBuilder(
        future: getIngredient(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data!;
          if (result is ResultFailure<Ingredient>) {
            return Center(
              child: Text('Could not load ingredient: ${result.failure}'),
            );
          }
          final ing = (result as Success<Ingredient>).value;
          return _detail(context, ing);
        },
      ),
    );
  }

  Widget _detail(BuildContext context, Ingredient ing) {
    final name = ing.displayNames['en'] ?? ing.name;
    final categoryColor = ing.category.color;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ing.imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: ing.imageUrl!,
                fit: BoxFit.cover,
              ),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: categoryColor.withValues(alpha: 0.08),
                child: Icon(
                  Icons.local_grocery_store_outlined,
                  size: 48,
                  color: categoryColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(KsTokens.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: KsTokens.space12),
                Wrap(
                  spacing: KsTokens.space6,
                  runSpacing: KsTokens.space4,
                  children: [
                    _InfoTag(label: ing.category.name, color: categoryColor),
                    _InfoTag(
                      label: 'default ${ing.defaultUnit.name}',
                      color: KsTokens.brandPrimary,
                    ),
                    if (ing.isBulkCandidate)
                      _InfoTag(label: 'bulk', color: KsTokens.sectionBulk),
                    if (ing.isNonFood)
                      _InfoTag(
                        label: 'non-food',
                        color: KsTokens.sectionNonFood,
                      ),
                  ],
                ),
                if (ing.aliases.isNotEmpty) ...[
                  const SizedBox(height: KsTokens.space24),
                  _MetadataSection(
                    label: 'Also known as',
                    child: Wrap(
                      spacing: KsTokens.space6,
                      runSpacing: KsTokens.space4,
                      children: ing.aliases
                          .map((a) => _AliasTag(label: a))
                          .toList(),
                    ),
                  ),
                ],
                if (ing.allergens.isNotEmpty) ...[
                  const SizedBox(height: KsTokens.space20),
                  _MetadataSection(
                    label: 'Allergens',
                    child: Wrap(
                      spacing: KsTokens.space6,
                      runSpacing: KsTokens.space4,
                      children: ing.allergens
                          .map(
                            (a) => _InfoTag(
                              label: a.name,
                              color: KsTokens.expired,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (ing.defaultShelfLifeDays != null) ...[
                  const SizedBox(height: KsTokens.space20),
                  _MetadataSection(
                    label: 'Typical shelf life',
                    child: Text(
                      '${ing.defaultShelfLifeDays} days',
                      style: KsTokens.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (ing.dietaryTags.isNotEmpty) ...[
                  const SizedBox(height: KsTokens.space20),
                  _MetadataSection(
                    label: 'Dietary tags',
                    child: Wrap(
                      spacing: KsTokens.space6,
                      runSpacing: KsTokens.space4,
                      children: ing.dietaryTags
                          .map(
                            (d) =>
                                _InfoTag(label: d.name, color: KsTokens.fresh),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (ing.imageAttribution != null) ...[
                  const SizedBox(height: KsTokens.space32),
                  Text(
                    'Image: ${ing.imageAttribution!.source},'
                    ' ${ing.imageAttribution!.license}',
                    style: KsTokens.bodySmall.copyWith(
                      color: KsTokens.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: KsTokens.space32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space8,
        vertical: KsTokens.space3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KsTokens.radius6),
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

class _AliasTag extends StatelessWidget {
  const _AliasTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space8,
        vertical: KsTokens.space3,
      ),
      decoration: BoxDecoration(
        color: KsTokens.neutralSubtle,
        borderRadius: BorderRadius.circular(KsTokens.radius6),
        border: Border.all(color: KsTokens.border),
      ),
      child: Text(
        label,
        style: KsTokens.labelSmall.copyWith(color: KsTokens.textSecondary),
      ),
    );
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KsTokens.labelLarge.copyWith(color: KsTokens.textTertiary),
        ),
        const SizedBox(height: KsTokens.space8),
        child,
      ],
    );
  }
}
