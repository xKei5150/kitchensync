import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/settings/presentation/screens/reauthentication_route_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

class _FakeAuthenticationController extends AuthenticationController {
  _FakeAuthenticationController() : super(auth: null, googleSignIn: null);

  Exception? passwordFailure;
  Exception? googleFailure;
  Exception? appleFailure;
  int passwordCalls = 0;
  int googleCalls = 0;
  int appleCalls = 0;

  @override
  Future<void> reauthenticateWithEmailPassword({
    required String password,
  }) async {
    passwordCalls++;
    final failure = passwordFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    googleCalls++;
    final failure = googleFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> reauthenticateWithApple() async {
    appleCalls++;
    final failure = appleFailure;
    if (failure != null) throw failure;
  }
}

Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  required FirebaseAuth auth,
  required AuthenticationController authentication,
  required AuthenticationProviderAvailability availability,
}) async {
  final router = GoRouter(
    initialLocation: '/base',
    routes: [
      GoRoute(
        path: '/base',
        builder: (_, _) => const Scaffold(body: Text('Base')),
      ),
      GoRoute(
        path: '/auth/reauthentication',
        builder: (_, _) => const ReauthenticationRouteScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        authenticationControllerProvider.overrideWithValue(authentication),
        authenticationProviderAvailabilityProvider.overrideWithValue(
          availability,
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void _stubUser(_MockFirebaseAuth auth, _MockUser user, List<String> providers) {
  final userInfo = <UserInfo>[];
  for (final providerId in providers) {
    final info = _MockUserInfo();
    when(() => info.providerId).thenReturn(providerId);
    userInfo.add(info);
  }
  when(() => auth.currentUser).thenReturn(user);
  when(() => user.email).thenReturn('sam@example.com');
  when(() => user.providerData).thenReturn(userInfo);
}

void main() {
  testWidgets('password reauthentication maps failure and succeeds', (
    tester,
  ) async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    _stubUser(auth, user, ['password']);
    final authentication = _FakeAuthenticationController()
      ..passwordFailure = FirebaseAuthException(code: 'wrong-password');
    final router = await _pumpRoute(
      tester,
      auth: auth,
      authentication: authentication,
      availability: const AuthenticationProviderAvailability(
        google: false,
        apple: false,
      ),
    );

    unawaited(router.push('/auth/reauthentication'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reauth-password-field')),
      'bad',
    );
    await tester.tap(find.byKey(const Key('reauth-email-password-action')));
    await tester.pumpAndSettle();
    expect(find.text('That password was not accepted.'), findsOneWidget);

    authentication.passwordFailure = null;
    await tester.tap(find.byKey(const Key('reauth-email-password-action')));
    await tester.pumpAndSettle();
    expect(authentication.passwordCalls, 2);
    expect(find.text('Base'), findsOneWidget);
  });

  testWidgets('provider cancellation is silent and Apple success returns', (
    tester,
  ) async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    _stubUser(auth, user, ['google.com', 'apple.com']);
    final authentication = _FakeAuthenticationController()
      ..googleFailure = const AuthenticationCancelled();
    final router = await _pumpRoute(
      tester,
      auth: auth,
      authentication: authentication,
      availability: const AuthenticationProviderAvailability(
        google: true,
        apple: true,
      ),
    );

    unawaited(router.push('/auth/reauthentication'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reauthenticate with Google'));
    await tester.pumpAndSettle();
    expect(find.text('We could not confirm your identity.'), findsNothing);
    expect(find.text('Confirm your identity'), findsOneWidget);

    await tester.tap(find.text('Reauthenticate with Apple'));
    await tester.pumpAndSettle();
    expect(authentication.googleCalls, 1);
    expect(authentication.appleCalls, 1);
    expect(find.text('Base'), findsOneWidget);
  });

  testWidgets('provider actions only show identities linked to the user', (
    tester,
  ) async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    _stubUser(auth, user, ['google.com']);
    final authentication = _FakeAuthenticationController();
    final router = await _pumpRoute(
      tester,
      auth: auth,
      authentication: authentication,
      availability: const AuthenticationProviderAvailability(
        google: true,
        apple: true,
      ),
    );
    unawaited(router.push('/auth/reauthentication'));
    await tester.pumpAndSettle();

    expect(find.text('Reauthenticate with Google'), findsOneWidget);
    expect(find.text('Reauthenticate with Apple'), findsNothing);
  });
}
