import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';

/// Public mobile OAuth client IDs are build configuration, not secrets.
///
/// Google Sign-In can only be offered when the corresponding native Firebase
/// OAuth client has been configured. Keeping these values empty by default
/// makes an incomplete local Firebase configuration honest: the action stays
/// unavailable instead of creating an anonymous account or pretending a
/// provider flow succeeded.
const configuredGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
);
const configuredGoogleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
);
const configuredGoogleIosReversedClientId = String.fromEnvironment(
  'GOOGLE_IOS_REVERSED_CLIENT_ID',
);
const configuredAppleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');

bool isConfiguredGoogleClientId(String value) {
  final clientId = value.trim();
  return clientId.endsWith('.apps.googleusercontent.com') &&
      !_looksLikeConfigurationPlaceholder(clientId);
}

bool isConfiguredGoogleReversedClientId(String value) {
  final reversedId = value.trim();
  return reversedId.startsWith('com.googleusercontent.apps.') &&
      !_looksLikeConfigurationPlaceholder(reversedId);
}

bool isConfiguredAppleServiceId(String value) {
  final serviceId = value.trim();
  return serviceId.contains('.') &&
      serviceId.length > 3 &&
      !_looksLikeConfigurationPlaceholder(serviceId);
}

bool _looksLikeConfigurationPlaceholder(String value) {
  final normalized = value.toLowerCase();
  return normalized.isEmpty ||
      normalized.contains('replace-with') ||
      normalized.contains('your-');
}

enum AuthenticationProviderKind { google, apple }

/// Whether a real provider flow can be started by this build.
class AuthenticationProviderAvailability {
  const AuthenticationProviderAvailability({
    required this.google,
    required this.apple,
  });

  final bool google;
  final bool apple;

  bool supports(AuthenticationProviderKind provider) => switch (provider) {
    AuthenticationProviderKind.google => google,
    AuthenticationProviderKind.apple => apple,
  };
}

final authenticationProviderAvailabilityProvider =
    Provider<AuthenticationProviderAvailability>((ref) {
      final firebaseIsReady = ref.watch(firebaseAuthProvider) != null;
      if (!firebaseIsReady || kIsWeb) {
        // This project intentionally has no web Firebase target. Do not expose
        // a web button that cannot finish a genuine Firebase sign-in.
        return const AuthenticationProviderAvailability(
          google: false,
          apple: false,
        );
      }

      final platform = defaultTargetPlatform;
      final google = switch (platform) {
        // Android needs the web OAuth client ID as the Firebase ID-token
        // audience. The Android OAuth client itself comes from the installed
        // google-services configuration.
        TargetPlatform.android => isConfiguredGoogleClientId(
          configuredGoogleWebClientId,
        ),
        // iOS also needs its installed client/URL-scheme configuration. The
        // client ID lets the Dart layer refuse the flow until that setup is
        // explicitly supplied with the build.
        TargetPlatform.iOS =>
          isConfiguredGoogleClientId(configuredGoogleWebClientId) &&
              isConfiguredGoogleClientId(configuredGoogleIosClientId) &&
              isConfiguredGoogleReversedClientId(
                configuredGoogleIosReversedClientId,
              ),
        _ => false,
      };
      return AuthenticationProviderAvailability(
        google: google,
        // Native Firebase supports AppleAuthProvider on iOS once the Xcode
        // entitlement *and* Firebase Apple provider/service ID are configured.
        // The service ID is public configuration, but requiring it prevents an
        // unconfigured target from advertising a provider it cannot complete.
        apple:
            platform == TargetPlatform.iOS &&
            isConfiguredAppleServiceId(configuredAppleServiceId),
      );
    });

/// True only while an intentional sign-in, password-reset, or sign-out action
/// is in flight. The router uses this to hold an explicit loading screen while
/// Firebase Auth emits its intermediate identity event.
final authenticationOperationInProgressProvider = StateProvider<bool>(
  (ref) => false,
);

final googleSignInProvider = Provider<GoogleSignIn?>((ref) {
  final available = ref.watch(authenticationProviderAvailabilityProvider);
  if (!available.google) return null;
  return GoogleSignIn(
    scopes: const ['email'],
    clientId: defaultTargetPlatform == TargetPlatform.iOS
        ? configuredGoogleIosClientId
        : null,
    serverClientId: configuredGoogleWebClientId,
  );
});

final authenticationControllerProvider = Provider<AuthenticationController>(
  (ref) => AuthenticationController(
    auth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  ),
);

/// A cancellation is intentionally distinct from an authentication failure so
/// the UI can return to a usable form without falsely reporting an error.
class AuthenticationCancelled implements Exception {
  const AuthenticationCancelled();
}

/// Indicates a build or provider configuration omission without exposing
/// implementation details to users.
class AuthenticationConfigurationException implements Exception {
  const AuthenticationConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthenticationController {
  const AuthenticationController({
    required this.auth,
    required this.googleSignIn,
  });

  final FirebaseAuth? auth;
  final GoogleSignIn? googleSignIn;

  FirebaseAuth get _requiredAuth {
    final value = auth;
    if (value == null) {
      throw const AuthenticationConfigurationException(
        'Firebase Authentication is unavailable in this build.',
      );
    }
    return value;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Kept correct if a web Firebase target is added in the future. Current
      // availability deliberately keeps this path hidden until then.
      return _requiredAuth.signInWithPopup(GoogleAuthProvider());
    }
    final google = googleSignIn;
    if (google == null) {
      throw const AuthenticationConfigurationException(
        'Google sign-in is not configured for this build.',
      );
    }
    GoogleSignInAccount? account;
    try {
      account = await google.signIn();
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_canceled' ||
          error.code == 'canceled' ||
          error.code == 'cancelled') {
        throw const AuthenticationCancelled();
      }
      rethrow;
    }
    if (account == null) throw const AuthenticationCancelled();
    final tokens = await account.authentication;
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthenticationConfigurationException(
        'Google did not return an identity token. Check the OAuth client '
        'configuration and retry.',
      );
    }
    return _requiredAuth.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: tokens.accessToken,
      ),
    );
  }

  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      return _requiredAuth.signInWithPopup(AppleAuthProvider());
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw const AuthenticationConfigurationException(
        'Apple sign-in is only available on configured Apple devices.',
      );
    }
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _requiredAuth.signInWithProvider(provider);
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _requiredAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    // Firebase sign-out is authoritative. A best-effort native Google sign-out
    // prevents a stale account picker selection on the next explicit sign-in,
    // but must never leave Firebase signed in when that native cleanup fails.
    await _requiredAuth.signOut();
    final google = googleSignIn;
    if (google != null) {
      try {
        await google.signOut();
      } catch (_) {
        // Native session cleanup is recoverable; Firebase has already revoked
        // this app's authenticated session.
      }
    }
  }
}

String? validateEmailAddress(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Enter your email address.';
  // This intentionally checks the user-facing shape only; Firebase remains
  // the authority for addresses that are syntactically invalid by provider
  // rules.
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validatePassword({
  required String value,
  required bool isRegistration,
}) {
  if (value.isEmpty) return 'Enter your password.';
  if (value.length < 6) return 'Password must be at least 6 characters.';
  if (!isRegistration) return null;
  if (value.length < 8) return 'Use at least 8 characters.';
  if (!RegExp('[A-Za-z]').hasMatch(value) || !RegExp('[0-9]').hasMatch(value)) {
    return 'Include at least one letter and one number.';
  }
  return null;
}

String authenticationErrorMessage(Object error) {
  if (error is AuthenticationCancelled) return '';
  if (error is AuthenticationConfigurationException) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'email-already-in-use' =>
        'An account already uses this email. Choose Login instead.',
      'weak-password' => 'Choose a stronger password.',
      'user-disabled' =>
        'This account has been disabled. Contact support for help.',
      'too-many-requests' =>
        'Too many attempts. Wait a moment, reset your password, or try again '
            'later.',
      'network-request-failed' =>
        'Could not reach authentication. Check your connection and retry.',
      'account-exists-with-different-credential' =>
        'This email already uses another sign-in method. Sign in with that '
            'method to link this provider.',
      'credential-already-in-use' =>
        'That sign-in method is already linked to another account.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled for this Firebase project.',
      'invalid-api-key' || 'app-not-authorized' =>
        'This build is not authorized for the selected sign-in method.',
      'popup-closed-by-user' || 'canceled' || 'cancelled' => '',
      _ => 'Could not authenticate. Please try again.',
    };
  }
  return 'Could not authenticate. Please try again.';
}
