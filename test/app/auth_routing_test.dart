import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';

void main() {
  const household = ActiveHouseholdContext(
    id: 'solo-user-1',
    name: 'My kitchen',
    role: HouseholdRole.admin,
    isJoint: false,
    hasPremium: false,
  );

  String? redirect(
    AppSessionState session,
    String path, {
    bool operationInProgress = false,
    bool allowHouseholdPicker = false,
    bool allowDeletionConfirmationDuringSignOut = false,
  }) {
    return appSessionRedirect(
      session: session,
      authenticationOperationInProgress: operationInProgress,
      path: path,
      allowHouseholdPicker: allowHouseholdPicker,
      allowDeletionConfirmationDuringSignOut:
          allowDeletionConfirmationDuringSignOut,
    );
  }

  test('holds an explicit loading route while auth or household resolves', () {
    expect(
      redirect(const AppSessionState.loadingAuth(), '/today'),
      '/auth/loading',
    );
    expect(
      redirect(
        const AppSessionState(phase: AppSessionPhase.loadingHousehold),
        '/onboarding',
      ),
      '/auth/loading',
    );
    expect(
      redirect(const AppSessionState.loadingAuth(), '/auth/loading'),
      isNull,
    );
  });

  test('routes signed-out identities only to the real sign-in entry point', () {
    expect(
      redirect(const AppSessionState.signedOut(), '/today'),
      '/onboarding',
    );
    expect(redirect(const AppSessionState.signedOut(), '/onboarding'), isNull);
  });

  test(
    'routes a signed-in user without a membership to household recovery',
    () {
      const session = AppSessionState(
        phase: AppSessionPhase.needsHouseholdSetup,
      );
      expect(redirect(session, '/today'), '/onboarding');
      expect(redirect(session, '/onboarding'), isNull);
    },
  );

  test(
    'routes an unverified household-less identity to email verification',
    () {
      const session = AppSessionState(
        phase: AppSessionPhase.needsEmailVerification,
      );
      expect(redirect(session, '/today'), '/auth/email-verification');
      expect(redirect(session, '/onboarding'), '/auth/email-verification');
      expect(redirect(session, '/auth/email-verification'), isNull);
    },
  );

  test(
    'only signed-out or accepted sign-out loading users may remain on deletion '
    'confirmation',
    () {
      expect(
        redirect(const AppSessionState.signedOut(), '/auth/deletion-requested'),
        isNull,
      );
      expect(
        redirect(
          const AppSessionState.signedOut(),
          '/settings/account-deletion',
        ),
        '/onboarding',
      );
      expect(
        redirect(
          const AppSessionState(phase: AppSessionPhase.ready),
          '/auth/deletion-requested',
        ),
        '/today',
      );
      expect(
        redirect(
          const AppSessionState(phase: AppSessionPhase.needsHouseholdSetup),
          '/auth/deletion-requested',
        ),
        '/onboarding',
      );
      expect(
        redirect(
          const AppSessionState.loadingAuth(),
          '/auth/deletion-requested',
        ),
        '/auth/loading',
      );
      expect(
        redirect(
          const AppSessionState.loadingAuth(),
          '/auth/deletion-requested',
          allowDeletionConfirmationDuringSignOut: true,
        ),
        isNull,
      );
      expect(
        redirect(
          const AppSessionState(phase: AppSessionPhase.loadingHousehold),
          '/auth/deletion-requested',
          allowDeletionConfirmationDuringSignOut: true,
        ),
        '/auth/loading',
      );
      expect(
        redirect(
          const AppSessionState(phase: AppSessionPhase.needsEmailVerification),
          '/auth/deletion-requested',
          allowDeletionConfirmationDuringSignOut: true,
        ),
        '/auth/email-verification',
      );
      expect(
        redirect(
          const AppSessionState(phase: AppSessionPhase.ready),
          '/auth/deletion-requested',
          allowDeletionConfirmationDuringSignOut: true,
        ),
        '/today',
      );
    },
  );

  test('only a confirmed membership can leave onboarding', () {
    const session = AppSessionState(
      phase: AppSessionPhase.ready,
      household: household,
    );
    expect(redirect(session, '/onboarding'), '/today');
    expect(redirect(session, '/auth/loading'), '/today');
    expect(redirect(session, '/today'), isNull);
    expect(
      redirect(session, '/onboarding', allowHouseholdPicker: true),
      isNull,
    );
  });

  test('an in-flight post-authentication operation cannot race into data', () {
    const session = AppSessionState(
      phase: AppSessionPhase.ready,
      household: household,
    );
    expect(
      redirect(session, '/today', operationInProgress: true),
      '/auth/loading',
    );
    expect(
      redirect(session, '/auth/loading', operationInProgress: true),
      isNull,
    );

    const recoverySession = AppSessionState(
      phase: AppSessionPhase.needsHouseholdSetup,
    );
    expect(
      redirect(recoverySession, '/onboarding', operationInProgress: true),
      '/auth/loading',
    );
    expect(
      redirect(recoverySession, '/auth/loading', operationInProgress: true),
      isNull,
    );
  });

  // The `unavailable` phase had no coverage at all, yet it is what an isolated
  // harness gets whenever it builds the real router without booting Firebase:
  // `firebaseAuthProvider` is null, so every route redirects to `/onboarding`.
  // Pinning it here documents why a no-Firebase test cannot reach an in-app
  // surface, which is exactly how the p2/p4 galleries and `recipe_nav` came to
  // walk the sign-in screen while claiming to walk Premium, Pantry and recipes.
  test('sends an unavailable session to sign in from every route', () {
    const session = AppSessionState.unavailable();

    for (final path in [
      '/today',
      '/pantry/add',
      '/settings/premium',
      '/household',
      '/menu-sets',
      '/ingredient/create',
      '/dev/a11y-states',
    ]) {
      expect(
        redirect(session, path),
        '/onboarding',
        reason: '$path must not render without a Firebase-backed session',
      );
    }

    // The sign-in entry point itself is the one place it may settle.
    expect(redirect(session, '/onboarding'), isNull);
  });
}
