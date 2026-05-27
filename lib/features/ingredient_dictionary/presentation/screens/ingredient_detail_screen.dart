import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ing.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: ing.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            ing.displayNames['en'] ?? ing.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _chip(context, ing.category.name),
              _chip(context, 'default ${ing.defaultUnit.name}'),
              if (ing.isBulkCandidate) _chip(context, 'bulk'),
              if (ing.isNonFood) _chip(context, 'non-food'),
            ],
          ),
          if (ing.aliases.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Also known as'),
            Text(ing.aliases.join(', ')),
          ],
          if (ing.allergens.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Allergens'),
            Text(ing.allergens.map((a) => a.name).join(', ')),
          ],
          if (ing.defaultShelfLifeDays != null) ...[
            const SizedBox(height: 16),
            const Text('Typical shelf life'),
            Text('${ing.defaultShelfLifeDays} days'),
          ],
          if (ing.imageAttribution != null) ...[
            const SizedBox(height: 24),
            Text(
              'Image: ${ing.imageAttribution!.source},'
              ' ${ing.imageAttribution!.license}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) =>
      Chip(label: Text(label));
}
