import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
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

  IconData _iconFor(PantrySection section) => switch (section) {
    PantrySection.food => Icons.restaurant_outlined,
    PantrySection.bulk => Icons.inventory_2_outlined,
    PantrySection.nonFood => Icons.cleaning_services_outlined,
    PantrySection.leftover => Icons.lunch_dining_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSection = ref.watch(pantryTabControllerProvider);
    final sectionAsync = ref.watch(pantrySectionStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pantry')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pantry/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          _SectionSelector(
            sections: PantrySection.values,
            selected: selectedSection,
            onSelect: (s) =>
                ref.read(pantryTabControllerProvider.notifier).select(s),
            labelFor: _labelFor,
            iconFor: _iconFor,
          ),
          Expanded(
            child: sectionAsync.when(
              data: (items) => items.isEmpty
                  ? _emptyState(context, selectedSection)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        KsTokens.space16,
                        KsTokens.space12,
                        KsTokens.space16,
                        KsTokens.space32,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KsTokens.space8),
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
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, PantrySection section) {
    return KsEmptyState(
      icon: _iconFor(section),
      title: 'Your ${_labelFor(section).toLowerCase()} pantry\nis waiting',
      subtitle: 'Tap Add to stock your first item.',
      color: section.color,
    );
  }
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.labelFor,
    required this.iconFor,
  });

  final List<PantrySection> sections;
  final PantrySection selected;
  final ValueChanged<PantrySection> onSelect;
  final String Function(PantrySection) labelFor;
  final IconData Function(PantrySection) iconFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KsTokens.surfaceBase,
        border: Border(bottom: BorderSide(color: KsTokens.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space16,
        vertical: KsTokens.space12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sections.map((section) {
            final isSelected = section == selected;
            final color = section.color;
            return Padding(
              padding: const EdgeInsets.only(right: KsTokens.space8),
              child: KsSectionTab(
                label: labelFor(section),
                icon: iconFor(section),
                color: color,
                isSelected: isSelected,
                onTap: () => onSelect(section),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
