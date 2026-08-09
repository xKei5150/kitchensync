// Mocktail requires closures for invocation matching.
// ignore_for_file: unnecessary_lambdas

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/email_verification_route_screen.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

Widget _wrap({required FirebaseAuth auth, required User user}) {
  return ProviderScope(
    overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      authenticationControllerProvider.overrideWithValue(
        AuthenticationController(auth: auth, googleSignIn: null),
      ),
      activeFirebaseUserProvider.overrideWith(
        (ref) => Stream<User?>.value(user),
      ),
      activeHouseholdContextStreamProvider.overrideWith(
        (ref) => Stream<ActiveHouseholdContext?>.value(null),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const EmailVerificationRouteScreen(),
    ),
  );
}

void _stubUnverifiedUser(_MockFirebaseAuth auth, _MockUser user) {
  when(() => auth.currentUser).thenReturn(user);
  when(() => user.email).thenReturn('ana@example.com');
  when(() => user.emailVerified).thenReturn(false);
  when(() => user.uid).thenReturn('user-1');
}

void main() {
  testWidgets('reload forces a token refresh and resend shows confirmation', (
    tester,
  ) async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    _stubUnverifiedUser(auth, user);
    when(() => user.reload()).thenAnswer((_) async {});
    when(() => user.getIdToken(true)).thenAnswer((_) async => 'fresh-token');
    when(() => user.sendEmailVerification()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(auth: auth, user: user));

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    verify(() => user.reload()).called(1);
    verify(() => user.getIdToken(true)).called(1);

    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();
    verify(() => user.sendEmailVerification()).called(1);
    expect(find.text('Verification email sent.'), findsOneWidget);
  });

  testWidgets(
    'sign out delegates to Firebase and verification errors are clear',
    (tester) async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      _stubUnverifiedUser(auth, user);
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(
        () => user.sendEmailVerification(),
      ).thenThrow(FirebaseAuthException(code: 'too-many-requests'));

      await tester.pumpWidget(_wrap(auth: auth, user: user));

      await tester.tap(find.text('Resend verification email'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Too many verification requests. Wait a moment and try again.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      verify(() => auth.signOut()).called(1);
    },
  );

  test(
    'unverified users are rejected before household provisioning or joining',
    () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      _stubUnverifiedUser(auth, user);
      final db = FakeFirebaseFirestore();
      final controller = HouseholdOnboardingController(db: db, auth: auth);

      Future<void> expectBlocked(Future<Object?> operation) async {
        await expectLater(
          operation,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('Verify your email'),
            ),
          ),
        );
      }

      await expectBlocked(controller.needsInitialProvisioning());
      await expectBlocked(controller.ensureInitialSoloHousehold());
      await expectBlocked(controller.createHousehold(kind: KitchenKind.joint));
      await expectBlocked(controller.joinHousehold(code: 'invite-token'));

      expect((await db.collection('users').get()).docs, isEmpty);
      expect((await db.collection('households').get()).docs, isEmpty);
    },
  );

  test('email verification error mapping keeps configuration and auth failures '
      'clear', () {
    expect(
      emailVerificationErrorMessage(
        const AuthenticationConfigurationException('Auth is unavailable.'),
      ),
      'Auth is unavailable.',
    );
    expect(
      emailVerificationErrorMessage(
        FirebaseAuthException(code: 'network-request-failed'),
      ),
      'Could not reach authentication. Check your connection and retry.',
    );
  });
}
