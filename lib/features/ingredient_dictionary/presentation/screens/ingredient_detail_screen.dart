import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

class IngredientDetailScreen extends ConsumerWidget {
  const IngredientDetailScreen({super.key, required this.id, this.householdId});

  final String id;
  final String? householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final getIngredient = ref.watch(getIngredientProvider);
    final activeHouseholdId =
        householdId ?? ref.watch(activeHouseholdIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ingredient')),
      body: FutureBuilder(
        future: getIngredient.forHousehold(id, householdId: activeHouseholdId),
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
    final defaultUnitLabel =
        UnitRegistry.find(ing.defaultUnit)?.label ?? ing.defaultUnit.value;

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
              child: ColoredBox(
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
                    KsTag(label: ing.category.name, color: categoryColor),
                    KsTag(label: 'default $defaultUnitLabel'),
                    if (ing.isBulkCandidate)
                      const KsTag(label: 'bulk', color: KsTokens.sectionBulk),
                    if (ing.isNonFood)
                      const KsTag(
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
                      children: ing.aliases.map(KsTag.alias).toList(),
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
                            (a) =>
                                KsTag(label: a.name, color: KsTokens.expired),
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
                if (ing.defaultPurchaseIntervalDays != null) ...[
                  const SizedBox(height: KsTokens.space20),
                  _MetadataSection(
                    label: 'Typical purchase interval',
                    child: Text(
                      'Every ${ing.defaultPurchaseIntervalDays} days',
                      style: KsTokens.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (ing.pricePerUnitHint != null) ...[
                  const SizedBox(height: KsTokens.space20),
                  _MetadataSection(
                    label: 'Price hint',
                    child: Text(
                      '${ing.pricePerUnitHint!.toStringAsFixed(2)} per '
                      '$defaultUnitLabel',
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
                            (d) => KsTag(label: d.name, color: KsTokens.fresh),
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
                      color: context.ksColors.textTertiary,
                    ),
                  ),
                ],
                if (ing.scope == IngredientScope.householdCustom) ...[
                  const SizedBox(height: KsTokens.space24),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/ingredient/create', extra: ing),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit ingredient'),
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
          style: KsTokens.labelLarge.copyWith(
            color: context.ksColors.textTertiary,
          ),
        ),
        const SizedBox(height: KsTokens.space8),
        child,
      ],
    );
  }
}
