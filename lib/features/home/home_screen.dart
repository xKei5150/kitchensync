import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KitchenSync')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Pick an ingredient'),
              onPressed: () => context.push('/ingredient/pick'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create custom ingredient'),
              onPressed: () => context.push('/ingredient/create'),
            ),
            const SizedBox(height: 24),
            if (kDebugMode)
              OutlinedButton.icon(
                icon: const Icon(Icons.build),
                label: const Text('Dev tools'),
                onPressed: () => context.push('/dev'),
              ),
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.bug_report),
              label: const Text('Force a test crash'),
              onPressed: () => FirebaseCrashlytics.instance.crash(),
            ),
          ],
        ),
      ),
    );
  }
}
