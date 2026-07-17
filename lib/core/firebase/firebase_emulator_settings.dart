import 'package:flutter/foundation.dart';

class FirebaseEmulatorSettings {
  const FirebaseEmulatorSettings({
    required this.firestoreHost,
    required this.firestorePort,
    required this.authHost,
    required this.authPort,
    required this.storageHost,
    required this.storagePort,
    required this.functionsHost,
    required this.functionsPort,
  });

  final String firestoreHost;
  final int firestorePort;
  final String authHost;
  final int authPort;
  final String storageHost;
  final int storagePort;
  final String functionsHost;
  final int functionsPort;
}

FirebaseEmulatorSettings firebaseEmulatorSettingsForTarget(
  TargetPlatform targetPlatform, {
  String firebaseEmulatorHost = const String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
  ),
  String firestoreEmulatorHost = const String.fromEnvironment(
    'FIRESTORE_EMULATOR_HOST',
  ),
  int firestoreEmulatorPort = const int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  ),
  String authEmulatorHost = const String.fromEnvironment('AUTH_EMULATOR_HOST'),
  int authEmulatorPort = const int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  ),
  String storageEmulatorHost = const String.fromEnvironment(
    'STORAGE_EMULATOR_HOST',
  ),
  int storageEmulatorPort = const int.fromEnvironment(
    'STORAGE_EMULATOR_PORT',
    defaultValue: 9199,
  ),
  String functionsEmulatorHost = const String.fromEnvironment(
    'FUNCTIONS_EMULATOR_HOST',
  ),
  int functionsEmulatorPort = const int.fromEnvironment(
    'FUNCTIONS_EMULATOR_PORT',
    defaultValue: 5001,
  ),
}) {
  final defaultEmulatorHost = targetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  final emulatorHost = firebaseEmulatorHost.isNotEmpty
      ? firebaseEmulatorHost
      : defaultEmulatorHost;
  return FirebaseEmulatorSettings(
    firestoreHost: firestoreEmulatorHost.isNotEmpty
        ? firestoreEmulatorHost
        : emulatorHost,
    firestorePort: firestoreEmulatorPort,
    authHost: authEmulatorHost.isNotEmpty ? authEmulatorHost : emulatorHost,
    authPort: authEmulatorPort,
    storageHost: storageEmulatorHost.isNotEmpty
        ? storageEmulatorHost
        : emulatorHost,
    storagePort: storageEmulatorPort,
    functionsHost: functionsEmulatorHost.isNotEmpty
        ? functionsEmulatorHost
        : emulatorHost,
    functionsPort: functionsEmulatorPort,
  );
}
