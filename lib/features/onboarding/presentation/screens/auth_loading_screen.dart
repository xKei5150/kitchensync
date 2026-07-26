import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';

/// A neutral gate while Firebase restores an identity or confirms household
/// membership. It is intentionally a real route rather than a fake household
/// so protected listeners cannot attach during a redirect race.
class AuthLoadingScreen extends ConsumerWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final session = ref.watch(appSessionStateProvider);
    final hasError = session.phase == AppSessionPhase.error;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KsTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasError)
                  Icon(Icons.cloud_off_rounded, color: ks.danger, size: 36)
                else
                  const CircularProgressIndicator(),
                const SizedBox(height: KsTokens.space16),
                Text(
                  hasError
                      ? 'We could not restore your kitchen'
                      : 'Restoring your account',
                  textAlign: TextAlign.center,
                  style: KsTokens.headlineMedium.copyWith(
                    color: ks.textPrimary,
                  ),
                ),
                const SizedBox(height: KsTokens.space8),
                Text(
                  hasError
                      ? 'Check your connection and retry. Your account has '
                            'not been changed.'
                      : 'Checking your sign-in and household access…',
                  textAlign: TextAlign.center,
                  style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
                ),
                if (hasError) ...[
                  const SizedBox(height: KsTokens.space16),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(firebaseAuthProvider)
                            ?.currentUser
                            ?.reload();
                      } catch (_) {
                        // Invalidating the streams below still gives a
                        // temporary network error a clean retry path.
                      }
                      ref
                        ..invalidate(activeFirebaseUserProvider)
                        ..invalidate(activeHouseholdContextStreamProvider);
                    },
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => _signOut(ref),
                    child: const Text('Sign out'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(WidgetRef ref) async {
    ref.read(authenticationOperationInProgressProvider.notifier).state = true;
    try {
      // Keep this recovery-path action aligned with Settings: Firebase is the
      // authority for the sign-out, and the native Google session is cleared
      // on a best-effort basis by the shared controller.
      await ref.read(authenticationControllerProvider).signOut();
    } finally {
      // Tear down user-scoped streams even when native provider cleanup had a
      // recoverable error, so an error/recovery page cannot retain a previous
      // household after the Firebase session changes.
      ref
        ..invalidate(activeFirebaseUserProvider)
        ..invalidate(activeHouseholdContextStreamProvider)
        ..invalidate(activeHouseholdContextProvider);
      ref.read(authenticationOperationInProgressProvider.notifier).state =
          false;
    }
  }
}
