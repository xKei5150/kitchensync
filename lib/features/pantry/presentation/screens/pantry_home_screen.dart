import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/widgets/pantry_item_tile.dart';

class PantryHomeScreen extends ConsumerWidget {
  const PantryHomeScreen({super.key});

  String _labelFor(PantrySection section) => switch (section) {
    PantrySection.food => 'Food',
    PantrySection.bulk => 'Bulk',
    PantrySection.nonFood => 'Non-food',
    PantrySection.leftover => 'Leftovers',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSection = ref.watch(pantryTabControllerProvider);
    final sectionAsync = ref.watch(pantrySectionStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: PantrySection.values.map((section) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_labelFor(section)),
                    selected: section == selectedSection,
                    onSelected: (_) => ref
                        .read(pantryTabControllerProvider.notifier)
                        .select(section),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pantry/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: sectionAsync.when(
        data: (items) => items.isEmpty
            ? _emptyState(context, selectedSection)
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return PantryItemTile(
                    key: ValueKey(item.id),
                    item: item,
                    onTap: () => context.push('/pantry/${item.id}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _emptyState(BuildContext context, PantrySection section) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.kitchen, size: 48),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                '${_labelFor(section)} pantry is empty',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the Add button to track your first item.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
