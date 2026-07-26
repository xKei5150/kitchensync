import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firebase_emulator_settings.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
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

/// How to advance frames while waiting for a surface.
typedef SettleStrategy = Future<void> Function(WidgetTester tester);

/// Advances fixed frames. Required for surfaces that animate continuously
/// (skeleton shimmer, sync spinners), where `pumpAndSettle` never returns.
Future<void> settleFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Settles if the surface quiesces, and advances fixed frames if it does not.
///
/// Several real screens never reach a quiescent frame — Today keeps an
/// animation running while its streams populate — so a bare `pumpAndSettle`
/// throws "pumpAndSettle timed out" and the test fails for a reason unrelated
/// to what it is checking.
Future<void> settleOrAdvance(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    // `pumpAndSettle` signals its timeout by throwing a FlutterError; there is
    // no Exception-typed alternative to catch, and treating "did not settle"
    // as fatal is precisely the behaviour being avoided here.
    // ignore: avoid_catching_errors
  } on FlutterError {
    await settleFrames(tester);
  }
}

/// Waits for [finder], adapting to whether the surface settles at all.
///
/// The first attempt tries to settle. If the surface turns out to animate
/// continuously, this stops paying the settle timeout on every subsequent
/// attempt — otherwise a genuine failure takes 40 × the timeout to report. A
/// real recipe_nav failure took **10 minutes** before this degradation existed.
///
/// [describing] and [diagnose] build the failure message, so a timeout says
/// which screen was expected and what state the app was actually in rather
/// than just "timed out".
Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required String describing,
  String Function()? diagnose,
}) async {
  var surfaceQuiesces = true;
  for (var attempt = 0; attempt < 40; attempt++) {
    if (surfaceQuiesces) {
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        // `pumpAndSettle` reports its timeout by throwing a FlutterError, so
        // there is no Exception-typed alternative to catch here.
        // ignore: avoid_catching_errors
      } on FlutterError {
        surfaceQuiesces = false;
      }
    }
    if (!surfaceQuiesces) await settleFrames(tester);
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  final detail = diagnose == null ? '' : ' ${diagnose()}';
  fail('Never reached $describing: no match for $finder.$detail');
}

Future<void> bootEmulatedApp({bool clearExistingSession = false}) async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator || !kDebugMode) {
    throw StateError(
      'bootEmulatedApp is test-only. Run a debug emulator build with '
      '--dart-define=USE_EMULATOR=true.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  await withTimeout(
    'FirebaseInitializer.initialize',
    () => const FirebaseInitializer().initialize(AppEnv.dev),
  );
  final auth = FirebaseAuth.instance;
  if (clearExistingSession && auth.currentUser != null) {
    await withTimeout('clear existing test auth session', auth.signOut);
  }
  final user = await signInWithEmulatorTestIdentity(auth);
  await seedEmulatorTestHouseholdThroughAdmin(user.uid);
}

/// Obtains an email/password identity from the Auth emulator only.
///
/// The project rules reject anonymous Firebase identities in every deployed
/// profile. Tests therefore use a disposable non-anonymous identity rather
/// than depending on an Auth-console provider setting for security.
Future<User> signInWithEmulatorTestIdentity(FirebaseAuth auth) async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator || !kDebugMode) {
    throw StateError(
      'Emulator test identities require a debug emulator build.',
    );
  }
  final existing = auth.currentUser;
  if (existing != null && !existing.isAnonymous) return existing;
  if (existing?.isAnonymous ?? false) {
    await withTimeout(
      'sign out anonymous emulator test identity',
      auth.signOut,
    );
  }
  final suffix = DateTime.now().microsecondsSinceEpoch;
  final credential = await withTimeout(
    'create disposable emulator email identity',
    () => auth.createUserWithEmailAndPassword(
      email: 'itest-$suffix@example.com',
      password: 'KitchenSync-$suffix-Aa1!',
    ),
  );
  final user = credential.user;
  if (user == null || user.isAnonymous) {
    throw StateError('[itest] emulator email identity was not created.');
  }
  return user;
}

/// Creates the debug fixture through the emulator's trusted REST surface.
///
/// This is deliberately test code rather than app startup behavior: ordinary
/// debug runs now land at real authentication, while legacy integration tests
/// still receive one deterministic, authorization-valid solo household.
Future<void> seedEmulatorTestHouseholdThroughAdmin(String uid) async {
  final householdId = debugHouseholdIdForUser(uid);
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator || !kDebugMode) {
    throw StateError('Emulator test fixtures require a debug emulator build.');
  }
  final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
  final existingUser = await withTimeout(
    'read emulator test profile',
    userRef.get,
  );
  if (existingUser.data()?['createdSoloHouseholdId'] == householdId) return;

  final now = DateTime.now().toUtc();
  await withTimeout(
    'seed emulator test household through emulator admin',
    () => seedFirestoreDocumentsThroughEmulatorAdmin({
      'users/$uid': {
        'activeHouseholdId': householdId,
        'createdSoloHouseholdId': householdId,
        'householdIds': [householdId],
        'joinedPremiumHouseholdIds': const <String>[],
        'isPremium': false,
        'createdAt': now,
        'updatedAt': now,
      },
      'households/$householdId': {
        'name': debugHouseholdName,
        'creatorUserId': uid,
        'isJoint': false,
        'hasPremium': false,
        'maxMembers': 1,
        'memberCount': 1,
        'createdAt': now,
        'updatedAt': now,
      },
      'households/$householdId/members/$uid': {
        'role': 'admin',
        'joinedAt': now,
        'updatedAt': now,
      },
    }),
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
  await _postEmulatorAdminBatchWrite(writes, 'Emulator admin fixture');
}

/// Posts a `documents:batchWrite` through the emulator's owner surface.
Future<void> _postEmulatorAdminBatchWrite(
  List<Map<String, Object?>> writes,
  String label,
) async {
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
      throw StateError('$label failed (${response.statusCode}): $body');
    }
  } finally {
    client.close(force: true);
  }
}

/// Updates only the named fields of existing fixture documents.
///
/// [seedFirestoreDocumentsThroughEmulatorAdmin] sends a `update` write with no
/// `updateMask`, which the Firestore REST API defines as a **whole-document
/// replace**. Using it to flip one flag silently deletes every other field —
/// wiping `activeHouseholdId` off a user, for example, drops the session back
/// to `needsHouseholdSetup`. This sends an explicit `updateMask` so a partial
/// update stays partial.
Future<void> mergeFirestoreDocumentsThroughEmulatorAdmin(
  Map<String, Map<String, Object?>> documents,
) async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator) {
    throw StateError('Admin fixture merging is emulator-only.');
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
        'updateMask': {'fieldPaths': entry.value.keys.toList()},
      },
  ];
  await _postEmulatorAdminBatchWrite(writes, 'Emulator admin merge');
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
