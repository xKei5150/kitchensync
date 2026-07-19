import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kitchensync/core/firebase/firebase_emulator_settings.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/search_tokenizer.dart';

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
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    final credential = await withTimeout(
      'signInAnonymously',
      auth.signInAnonymously,
    );
    if (credential.user == null) {
      throw StateError('[itest] anonymous sign-in returned no user');
    }
  }
  await withTimeout(
    'wait for authenticated user',
    () => auth.authStateChanges().firstWhere((user) => user != null),
  );
}

/// Seeds the bundled global dictionary through the Firestore emulator's
/// admin-only REST surface.
///
/// Client writes to `/ingredients` are intentionally denied by both rule
/// profiles. Integration tests therefore use the emulator's `owner` token
/// instead of weakening application authorization merely to arrange fixtures.
Future<void> seedGlobalDictionaryThroughEmulatorAdmin() async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator) {
    throw StateError('Admin fixture seeding is emulator-only.');
  }

  final decoded =
      jsonDecode(await rootBundle.loadString('assets/seed/ingredients.json'))
          as Map<String, dynamic>;
  final ingredients = (decoded['ingredients'] as List)
      .cast<Map<String, dynamic>>();
  final now = DateTime.now().toUtc();
  final writes = <Map<String, dynamic>>[];
  for (final ingredient in ingredients) {
    final id = ingredient['id'] as String;
    final displayNames = Map<String, String>.from(
      ingredient['displayNames'] as Map,
    );
    final aliases = ((ingredient['aliases'] as List?) ?? const [])
        .cast<String>();
    final parentTokens = ((ingredient['parentTokens'] as List?) ?? const [])
        .cast<String>();
    final taxonomyTags = ((ingredient['taxonomyTags'] as List?) ?? const [])
        .cast<String>();
    final formTags = ((ingredient['formTags'] as List?) ?? const [])
        .cast<String>();
    final document = <String, Object?>{
      for (final entry in ingredient.entries)
        if (entry.key != 'id' && entry.key != 'parentTokens')
          entry.key: entry.value,
      'name': displayNames['en']!.toLowerCase(),
      'searchTokens': SearchTokenizer.buildIndex(
        displayNames: displayNames,
        aliases: aliases,
        parentTokens: parentTokens,
        taxonomyTags: taxonomyTags,
        formTags: formTags,
      ),
      'scope': 'global',
      'schemaVersion': 1,
      'createdAt': now,
      'updatedAt': now,
    };
    writes.add({
      'update': {
        'name':
            'projects/kitchensync-dev-da503/databases/(default)/documents/'
            'ingredients/$id',
        'fields': _firestoreFields(document),
      },
    });
  }

  final settings = firebaseEmulatorSettingsForTarget(defaultTargetPlatform);
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri(
        scheme: 'http',
        host: settings.firestoreHost,
        port: settings.firestorePort,
        path:
            '/v1/projects/kitchensync-dev-da503/databases/(default)/'
            'documents:batchWrite',
      ),
    );
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer owner');
    request.write(jsonEncode({'writes': writes}));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Emulator admin seed failed (${response.statusCode}): $body',
      );
    }
  } finally {
    client.close(force: true);
  }
}

/// Writes explicit Firestore fixture documents through the emulator's
/// admin-only REST surface. This is reserved for trusted test arrangement such
/// as granting a test identity Premium before exercising client-side rules.
Future<void> seedFirestoreDocumentsThroughEmulatorAdmin(
  Map<String, Map<String, Object?>> documents,
) async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator) {
    throw StateError('Admin fixture seeding is emulator-only.');
  }
  final writes = [
    for (final entry in documents.entries)
      {
        'update': {
          'name':
              'projects/kitchensync-dev-da503/databases/(default)/documents/'
              '${entry.key}',
          'fields': _firestoreFields(entry.value),
        },
      },
  ];
  final settings = firebaseEmulatorSettingsForTarget(defaultTargetPlatform);
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri(
        scheme: 'http',
        host: settings.firestoreHost,
        port: settings.firestorePort,
        path:
            '/v1/projects/kitchensync-dev-da503/databases/(default)/'
            'documents:batchWrite',
      ),
    );
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer owner');
    request.write(jsonEncode({'writes': writes}));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Emulator admin fixture failed (${response.statusCode}): $body',
      );
    }
  } finally {
    client.close(force: true);
  }
}

/// Checks a fixture document through the emulator-only owner surface without
/// weakening application read rules for another user's private data.
Future<bool> firestoreDocumentExistsThroughEmulatorAdmin(
  String documentPath,
) async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator) {
    throw StateError('Admin fixture inspection is emulator-only.');
  }
  final settings = firebaseEmulatorSettingsForTarget(defaultTargetPlatform);
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri(
        scheme: 'http',
        host: settings.firestoreHost,
        port: settings.firestorePort,
        path:
            '/v1/projects/kitchensync-dev-da503/databases/(default)/documents/'
            '$documentPath',
      ),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode == HttpStatus.ok) return true;
    if (response.statusCode == HttpStatus.notFound) return false;
    throw StateError(
      'Emulator admin fixture read failed (${response.statusCode}).',
    );
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic> _firestoreFields(Map<String, Object?> value) => {
  for (final entry in value.entries) entry.key: _firestoreValue(entry.value),
};

Map<String, dynamic> _firestoreValue(Object? value) {
  if (value == null) return const {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is List) {
    return {
      'arrayValue': {
        'values': [for (final item in value) _firestoreValue(item)],
      },
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': _firestoreFields(
          value.map((key, item) => MapEntry(key.toString(), item as Object?)),
        ),
      },
    };
  }
  throw ArgumentError.value(value, 'value', 'Unsupported Firestore fixture.');
}
