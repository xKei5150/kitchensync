import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';

const _unusedFunctionsPort = int.fromEnvironment(
  'UNUSED_FUNCTIONS_PORT',
  defaultValue: 56551,
);
const _functionsHost = String.fromEnvironment(
  'FUNCTIONS_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

Future<void> _expectBoundedFunctionsException({
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
      'message="${e.message}" elapsedMs=${stopwatch.elapsedMilliseconds} '
      'host=$_functionsHost port=$_unusedFunctionsPort',
    );
    expect(e.code, 'unavailable');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 6)));
  } on TimeoutException catch (e) {
    stopwatch.stop();
    fail(
      'Callable timed out for $scenario after '
      '${stopwatch.elapsedMilliseconds}ms: $e',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cloud_functions raises bounded FirebaseFunctionsException '
      'on unused emulator port', (_) async {
    // Given: the app initializer has wired Firebase plugins to emulators, with
    // Functions deliberately pointed at an unused port.
    await const FirebaseInitializer().initialize(AppEnv.dev);
    debugPrint(
      'QA_CONFIG platform=$defaultTargetPlatform '
      'functionsHost=$_functionsHost functionsPort=$_unusedFunctionsPort',
    );

    // When: the app calls the real plugin API with a bounded wait.
    // Then: the SDK surfaces bounded Functions exceptions instead of hanging
    // or contacting production.
    await _expectBoundedFunctionsException(
      scenario: 'emptyPayload',
      payload: <String, Object?>{},
    );
    await _expectBoundedFunctionsException(
      scenario: 'malformedPayload',
      payload: <String, Object?>{'unexpected': 'malformed'},
    );
  }, timeout: const Timeout(Duration(seconds: 20)));
}
