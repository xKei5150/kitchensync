import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/errors/firebase_reachability.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';

const _unusedFunctionsPort = int.fromEnvironment(
  'UNUSED_FUNCTIONS_PORT',
  defaultValue: 56551,
);
const _functionsHost = String.fromEnvironment(
  'FUNCTIONS_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

/// Drives a callable against a port with no listener and asserts how the
/// **app** classifies the result.
///
/// This deliberately does not assert the raw SDK code. On iOS an unreachable
/// backend is reported as `code == 'unknown'` with message
/// "Could not connect to the server." — not `'unavailable'`. That is a platform
/// fact this repository cannot change, and an earlier revision of this test
/// asserted `'unavailable'` and therefore failed against correct SDK behaviour.
///
/// What actually matters is that the app routes an unreachable backend to its
/// offline/network path on every platform, so that is what is asserted here.
/// The raw code is still printed to `QA_RESULT` so the platform fact stays
/// visible in the run log.
Future<void> _expectBoundedUnreachableClassification({
  required String scenario,
  required Map<String, Object?> payload,
}) async {
  final smoke = FirebaseFunctions.instance.httpsCallable('shoppingSmoke');
  final stopwatch = Stopwatch()..start();
  try {
    await smoke
        .call<Map<String, Object?>>(payload)
        .timeout(const Duration(seconds: 6));
    fail('Expected FirebaseFunctionsException for $scenario');
  } on FirebaseFunctionsException catch (e) {
    stopwatch.stop();
    debugPrint(
      'QA_RESULT scenario=$scenario '
      'exceptionType=${e.runtimeType} code=${e.code} '
      'message="${e.message}" details=${e.details} '
      'elapsedMs=${stopwatch.elapsedMilliseconds} '
      'host=$_functionsHost port=$_unusedFunctionsPort',
    );

    // The SDK must fail fast rather than hang or reach production.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 6)));

    // The app must recognise this as an unreachable backend...
    expect(
      isFirebaseBackendUnreachable(code: e.code, message: e.message),
      isTrue,
      reason:
          'Unreachable backend was not classified as such. '
          'code=${e.code} message="${e.message}"',
    );

    // ...and both classifiers that act on it must agree it is a network
    // failure, not a generic unknown one.
    expect(ExceptionMapper.toFailure(e), isA<NetworkFailure>());
    expect(
      _shoppingCommandKindFor(e),
      ShoppingCommandFailureKind.unavailable,
      reason: 'Shopping commands must take the retryable offline path.',
    );
  } on TimeoutException catch (e) {
    stopwatch.stop();
    fail(
      'Callable timed out for $scenario after '
      '${stopwatch.elapsedMilliseconds}ms: $e',
    );
  }
}

/// Mirrors `ShoppingCommandRepositoryImpl._run`'s classification for a real
/// on-device exception, without needing a live command data source.
ShoppingCommandFailureKind _shoppingCommandKindFor(
  FirebaseFunctionsException error,
) => isFirebaseBackendUnreachable(code: error.code, message: error.message)
    ? ShoppingCommandFailureKind.unavailable
    : ShoppingCommandFailureKind.unknown;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an unreachable Functions backend is classified as a network '
      'failure, not an unknown one', (_) async {
    // Given: the app initializer has wired Firebase plugins to emulators, with
    // Functions deliberately pointed at an unused port.
    await const FirebaseInitializer().initialize(AppEnv.dev);
    debugPrint(
      'QA_CONFIG platform=$defaultTargetPlatform '
      'functionsHost=$_functionsHost functionsPort=$_unusedFunctionsPort',
    );

    // When: the app calls the real plugin API with a bounded wait.
    // Then: the SDK surfaces a bounded exception and the app treats it as an
    // offline condition instead of an opaque failure.
    await _expectBoundedUnreachableClassification(
      scenario: 'emptyPayload',
      payload: <String, Object?>{},
    );
    await _expectBoundedUnreachableClassification(
      scenario: 'malformedPayload',
      payload: <String, Object?>{'unexpected': 'malformed'},
    );
  }, timeout: const Timeout(Duration(seconds: 20)));
}
