// Mocktail requires closures for invocation matching.
// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/settings/presentation/controllers/account_deletion_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

void main() {
  test(
    'production router rebuild keeps accepted deletion confirmation rendered',
    () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => user.uid).thenReturn('user-1');
      when(() => user.emailVerified).thenReturn(true);
      when(() => auth.currentUser).thenReturn(user);

      final authStates = StreamController<User?>.broadcast();
      addTearDown(authStates.close);
      var signedIn = true;
      when(auth.authStateChanges).thenAnswer((_) => authStates.stream);
      when(() => auth.signOut()).thenAnswer((_) async {
        signedIn = false;
      });

      const household = ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Solo kitchen',
        role: HouseholdRole.admin,
        isJoint: false,
        hasPremium: true,
      );
      final source = AccountLifecycleRemoteDataSource.forTesting((name, data) {
        if (name != 'requestAccountDeletion') {
          throw StateError('Unexpected callable: $name');
        }
        return Future<Object?>.value({
          'commandId': data['commandId'],
          'requestId': data['commandId'],
          'policyVersion': accountLifecyclePolicyVersion,
          'status': 'queued',
          'alreadyQueued': false,
        });
      });
      final deletion = AccountDeletionController(
        auth: auth,
        googleSignIn: null,
        providerAvailability: const AuthenticationProviderAvailability(
          google: false,
          apple: false,
        ),
        activeHousehold: household,
        dataSource: source,
        idGenerator: FakeIdGenerator(['123e4567-e89b-42d3-a456-426614174001']),
      );
      final authentication = AuthenticationController(
        auth: auth,
        googleSignIn: null,
      );
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          activeFirebaseUserProvider.overrideWith(
            (ref) => Stream<User?>.value(signedIn ? user : null),
          ),
          activeHouseholdContextStreamProvider.overrideWith(
            (ref) => Stream<ActiveHouseholdContext?>.value(
              signedIn ? household : null,
            ),
          ),
          accountDeletionControllerProvider.overrideWithValue(deletion),
          authenticationControllerProvider.overrideWithValue(authentication),
        ],
      );
      addTearDown(container.dispose);

      for (
        var attempt = 0;
        attempt < 5 &&
            container.read(appSessionStateProvider).phase !=
                AppSessionPhase.ready;
        attempt++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        container.read(appSessionStateProvider).phase,
        AppSessionPhase.ready,
      );

      var routerBuilds = 0;
      final routerSubscription = container.listen<GoRouter>(
        routerProvider,
        (previous, next) => routerBuilds++,
      );
      addTearDown(routerSubscription.close);
      final signedInRouter = container.read(routerProvider)
        ..go('/auth/deletion-requested');
      await Future<void>.delayed(Duration.zero);
      expect(
        appSessionRedirect(
          session: container.read(appSessionStateProvider),
          authenticationOperationInProgress: false,
          path: '/auth/deletion-requested',
        ),
        '/today',
      );

      final accepted = await deletion.requestAccountDeletion();
      expect(accepted.status, AccountLifecycleRequestStatus.queued);

      container.read(accountDeletionSignOutInProgressProvider.notifier).state =
          true;
      container.read(authenticationOperationInProgressProvider.notifier).state =
          true;
      final signOutRouter = container.read(routerProvider);

      await authentication.signOut();
      final signedOut = authentication.waitForSignedOut();
      authStates.add(null);
      await signedOut;
      container
        ..invalidate(activeFirebaseUserProvider)
        ..invalidate(activeHouseholdContextStreamProvider)
        ..invalidate(activeHouseholdContextProvider);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(appSessionStateProvider).phase,
        AppSessionPhase.signedOut,
      );

      final transitionRouter = container.read(routerProvider)
        ..go('/auth/deletion-requested');
      expect(transitionRouter, isNot(same(signOutRouter)));
      await Future<void>.delayed(Duration.zero);
      expect(
        transitionRouter.routeInformationProvider.value.uri.path,
        '/auth/deletion-requested',
      );

      container.read(accountDeletionSignOutInProgressProvider.notifier).state =
          false;
      container.read(authenticationOperationInProgressProvider.notifier).state =
          false;

      final confirmationRouter = container.read(routerProvider)
        ..go('/auth/deletion-requested');
      await Future<void>.delayed(Duration.zero);
      expect(routerBuilds, greaterThan(0));
      expect(confirmationRouter, isNot(same(signedInRouter)));
      expect(
        confirmationRouter.routeInformationProvider.value.uri.path,
        '/auth/deletion-requested',
      );
    },
  );
}
