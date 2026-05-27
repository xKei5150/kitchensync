import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

class DevToolsScreen extends ConsumerStatefulWidget {
  const DevToolsScreen({super.key});

  @override
  ConsumerState<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends ConsumerState<DevToolsScreen> {
  bool _running = false;
  String _status = '';

  Future<void> _seed() async {
    setState(() {
      _running = true;
      _status = 'Loading seed asset...';
    });
    final useCase = ref.read(seedGlobalDictionaryProvider);
    final r = await useCase(const NoParams());
    setState(() {
      _running = false;
      _status = switch (r) {
        Success<int>(:final value) => 'Upserted $value ingredients.',
        ResultFailure<int>(:final failure) => 'Failed: $failure',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Dev tools are unavailable in this build.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Dev tools')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: Text(_running ? 'Seeding...' : 'Seed global dictionary'),
              onPressed: _running ? null : _seed,
            ),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
