import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/firebase_reachability.dart';

void main() {
  group('isFirebaseBackendUnreachable', () {
    test('classifies the canonical unavailable code', () {
      expect(
        isFirebaseBackendUnreachable(code: 'unavailable', message: 'offline'),
        isTrue,
      );
    });

    // Measured on iOS against a Functions port with no listener: the plugin
    // raises in ~26ms with code `unknown`, not `unavailable`. Asserting only on
    // `unavailable` is what sent every iOS offline failure to the unknown path.
    test('classifies the iOS connection-refused shape', () {
      expect(
        isFirebaseBackendUnreachable(
          code: 'unknown',
          message: 'Could not connect to the server.',
        ),
        isTrue,
      );
    });

    test('matches the iOS transport messages regardless of case', () {
      const messages = [
        'The Internet connection appears to be offline.',
        'A server with the specified hostname could not be found.',
        'The network connection was lost.',
        'The request timed out.',
        'connection refused',
      ];
      for (final message in messages) {
        expect(
          isFirebaseBackendUnreachable(code: 'unknown', message: message),
          isTrue,
          reason: message,
        );
        expect(
          isFirebaseBackendUnreachable(
            code: 'unknown',
            message: message.toUpperCase(),
          ),
          isTrue,
          reason: 'upper-cased: $message',
        );
      }
    });

    test('does not classify an unknown code with an unrelated message', () {
      expect(
        isFirebaseBackendUnreachable(
          code: 'unknown',
          message: 'Recipe payload was rejected',
        ),
        isFalse,
      );
    });

    test('does not classify a null message on an unknown code', () {
      expect(isFirebaseBackendUnreachable(code: 'unknown'), isFalse);
    });

    // A transport phrase must not launder a real authorization or server
    // failure into a retryable "you are offline" outcome.
    test('only reclassifies the unknown code, never a real callable code', () {
      for (final code in ['permission-denied', 'internal', 'not-found']) {
        expect(
          isFirebaseBackendUnreachable(
            code: code,
            message: 'Could not connect to the server.',
          ),
          isFalse,
          reason: code,
        );
      }
    });
  });
}
