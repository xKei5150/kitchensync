import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

class WasteLogScreen extends ConsumerWidget {
  const WasteLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wasteAsync = ref.watch(wasteHistoryStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Waste log')),
      body: wasteAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('No waste events yet.'));
          }
          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = events[index];
              final qty = QuantityFormatter.format(event.quantity);
              final unit = event.unit.name;
              final date = event.date;
              final dateLabel =
                  '${date.year.toString().padLeft(4, '0')}'
                  '-${date.month.toString().padLeft(2, '0')}'
                  '-${date.day.toString().padLeft(2, '0')}';
              return ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('$qty $unit of ${event.ingredientId}'),
                subtitle: Text('${event.reason.name} • $dateLabel'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
