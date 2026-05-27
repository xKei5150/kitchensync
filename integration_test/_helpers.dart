import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';

/// Runs `body`, throwing a labelled error if it does not complete within
/// `seconds`. Integration tests that talk to the emulator must never hang
/// indefinitely — a stalled Firebase call should fail fast with a message that
/// says which phase stalled.
Future<T> withTimeout<T>(
  String label,
  Future<T> Function() body, {
  int seconds = 30,
}) async {
  debugPrint('[itest] >>> $label');
  final result = await body().timeout(
    Duration(seconds: seconds),
    onTimeout: () => throw StateError('[itest] TIMEOUT in: $label'),
  );
  debugPrint('[itest] <<< $label');
  return result;
}

Future<void> bootEmulatedApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await withTimeout(
    'FirebaseInitializer.initialize',
    () => const FirebaseInitializer().initialize(AppEnv.dev),
  );
  if (FirebaseAuth.instance.currentUser == null) {
    await withTimeout(
      'signInAnonymously',
      () => FirebaseAuth.instance.signInAnonymously(),
    );
  }
}
