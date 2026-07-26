import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';

void main() {
  group('email validation', () {
    test('accepts a normal email address', () {
      expect(validateEmailAddress('sam@example.com'), isNull);
    });

    test('rejects empty and malformed email addresses', () {
      expect(validateEmailAddress(''), 'Enter your email address.');
      expect(
        validateEmailAddress('sam.example.com'),
        'Enter a valid email address.',
      );
      expect(validateEmailAddress('sam@'), 'Enter a valid email address.');
    });
  });

  group('password validation', () {
    test("login preserves Firebase's minimum password requirement locally", () {
      expect(
        validatePassword(value: 'short', isRegistration: false),
        'Password must be at least 6 characters.',
      );
    });

    test('registration requires a long enough mixed password', () {
      expect(
        validatePassword(value: 'short1', isRegistration: true),
        'Use at least 8 characters.',
      );
      expect(
        validatePassword(value: 'onlyletters', isRegistration: true),
        'Include at least one letter and one number.',
      );
      expect(
        validatePassword(value: 'KitchenSync1', isRegistration: true),
        isNull,
      );
    });
  });

  test('cancellation is silent while configuration failures remain honest', () {
    expect(
      authenticationErrorMessage(const AuthenticationCancelled()),
      isEmpty,
    );
    expect(
      authenticationErrorMessage(
        const AuthenticationConfigurationException('Google is unavailable.'),
      ),
      'Google is unavailable.',
    );
  });

  group('Firebase email and provider errors', () {
    FirebaseAuthException firebaseError(String code) => FirebaseAuthException(
      code: code,
    );

    test('maps invalid credentials, duplicate emails, and weak passwords', () {
      expect(
        authenticationErrorMessage(firebaseError('invalid-credential')),
        'Email or password is incorrect.',
      );
      expect(
        authenticationErrorMessage(firebaseError('wrong-password')),
        'Email or password is incorrect.',
      );
      expect(
        authenticationErrorMessage(firebaseError('user-not-found')),
        'Email or password is incorrect.',
      );
      expect(
        authenticationErrorMessage(firebaseError('email-already-in-use')),
        'An account already uses this email. Choose Login instead.',
      );
      expect(
        authenticationErrorMessage(firebaseError('weak-password')),
        'Choose a stronger password.',
      );
    });

    test('maps disabled, throttled, and offline failures', () {
      expect(
        authenticationErrorMessage(firebaseError('user-disabled')),
        'This account has been disabled. Contact support for help.',
      );
      expect(
        authenticationErrorMessage(firebaseError('too-many-requests')),
        contains('Too many attempts.'),
      );
      expect(
        authenticationErrorMessage(firebaseError('network-request-failed')),
        'Could not reach authentication. Check your connection and retry.',
      );
    });

    test('maps collision, provider configuration, and unknown failures', () {
      expect(
        authenticationErrorMessage(
          firebaseError('account-exists-with-different-credential'),
        ),
        contains('another sign-in method'),
      );
      expect(
        authenticationErrorMessage(firebaseError('credential-already-in-use')),
        'That sign-in method is already linked to another account.',
      );
      expect(
        authenticationErrorMessage(firebaseError('operation-not-allowed')),
        'This sign-in method is not enabled for this Firebase project.',
      );
      expect(
        authenticationErrorMessage(firebaseError('some-new-error')),
        'Could not authenticate. Please try again.',
      );
    });
  });

  test(
    'provider availability rejects example and malformed build settings',
    () {
      expect(
        isConfiguredGoogleClientId(
          'replace-with-the-web-oauth-client-id.apps.googleusercontent.com',
        ),
        isFalse,
      );
      expect(isConfiguredGoogleClientId('not-an-oauth-client'), isFalse);
      expect(
        isConfiguredGoogleClientId('123.apps.googleusercontent.com'),
        isTrue,
      );
      expect(
        isConfiguredGoogleReversedClientId('replace-with-reversed-client-id'),
        isFalse,
      );
      expect(
        isConfiguredGoogleReversedClientId('com.googleusercontent.apps.123'),
        isTrue,
      );
      expect(
        isConfiguredAppleServiceId('replace-with-the-apple-service-id'),
        isFalse,
      );
      expect(
        isConfiguredAppleServiceId('com.example.kitchensync.auth'),
        isTrue,
      );
      expect(isConfiguredAppleServiceId('com.acme.kitchensync.auth'), isTrue);
    },
  );
}
