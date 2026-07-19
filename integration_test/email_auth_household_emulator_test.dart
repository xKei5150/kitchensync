import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/sign_in_screen.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'email registration creates a solo household and login restores the user',
    (tester) async {
      const initializer = FirebaseInitializer();
      await withTimeout(
        'configure Firebase emulators',
        () => initializer.bootstrap(AppEnv.dev),
      );
      await withTimeout(
        'clear existing auth session',
        FirebaseAuth.instance.signOut,
      );

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const SignInScreen(),
          ),
          GoRoute(
            path: '/today',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Auth complete'))),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 'auth-$suffix@example.com';
      const password = 'KitchenSync-123!';

      await tester.tap(find.text('Register'));
      await tester.enterText(
        find.widgetWithText(TextField, 'you@email.com'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await _waitForAuthAction(tester);

      if (find.text('Auth complete').evaluate().isEmpty) {
        _logAuthState(tester, phase: 'registration');
      }
      expect(find.text('Auth complete'), findsOneWidget);
      final registeredUser = FirebaseAuth.instance.currentUser;
      expect(registeredUser, isNotNull);
      expect(registeredUser!.email, email);
      expect(registeredUser.isAnonymous, isFalse);

      final db = FirebaseFirestore.instance;
      final userSnapshot = await withTimeout(
        'read registered user profile',
        () => db.collection('users').doc(registeredUser.uid).get(),
      );
      final householdId = userSnapshot.data()?['activeHouseholdId'] as String?;
      expect(householdId, isNotNull);
      expect(householdId, isNotEmpty);
      expect(userSnapshot.data()?['isPremium'], isFalse);
      expect(userSnapshot.data()?['createdSoloHouseholdId'], householdId);

      final householdSnapshots = await withTimeout(
        'read automatically created solo household',
        () => Future.wait([
          db.collection('households').doc(householdId).get(),
          db
              .collection('households')
              .doc(householdId)
              .collection('members')
              .doc(registeredUser.uid)
              .get(),
        ]),
      );
      expect(
        householdSnapshots[0].data()?['creatorUserId'],
        registeredUser.uid,
      );
      expect(householdSnapshots[0].data()?['isJoint'], isFalse);
      expect(householdSnapshots[0].data()?['hasPremium'], isFalse);
      expect(householdSnapshots[0].data()?['maxMembers'], 1);
      expect(householdSnapshots[1].data()?['role'], 'admin');

      final registeredUid = registeredUser.uid;
      await withTimeout(
        'sign out registered user',
        FirebaseAuth.instance.signOut,
      );
      expect(FirebaseAuth.instance.currentUser, isNull);

      router.go('/onboarding');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'you@email.com'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await _waitForAuthAction(tester);

      if (find.text('Auth complete').evaluate().isEmpty) {
        _logAuthState(tester, phase: 'login');
      }
      expect(find.text('Auth complete'), findsOneWidget);
      final signedInUser = FirebaseAuth.instance.currentUser;
      expect(signedInUser, isNotNull);
      expect(signedInUser!.uid, registeredUid);
      final reloadedUserSnapshot = await withTimeout(
        'reload active household after login',
        () => db.collection('users').doc(signedInUser.uid).get(),
      );
      expect(reloadedUserSnapshot.data()?['activeHouseholdId'], householdId);

      await withTimeout('final sign out', FirebaseAuth.instance.signOut);
      expect(FirebaseAuth.instance.currentUser, isNull);
    },
  );
}

Future<void> _waitForAuthAction(WidgetTester tester) async {
  await tester.pump();
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (find.text('Continuing...').evaluate().isNotEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void _logAuthState(WidgetTester tester, {required String phase}) {
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList(growable: false);
  final user = FirebaseAuth.instance.currentUser;
  debugPrint(
    'AUTH_INTEGRATION_FAILURE phase=$phase '
    'uid=${user?.uid} email=${user?.email} '
    'visibleText=$visibleText',
  );
}
