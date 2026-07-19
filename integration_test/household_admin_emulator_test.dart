import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/presentation/screens/household_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Admin transfer and member removal stay atomic and visible', (
    tester,
  ) async {
    const initializer = FirebaseInitializer();
    await withTimeout(
      'configure household Admin Firebase emulators',
      () => initializer.bootstrap(AppEnv.dev),
    );
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await withTimeout('clear household Admin auth session', auth.signOut);

    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final suffix = DateTime.now().microsecondsSinceEpoch;
    const password = 'KitchenSync-123!';
    final admin = await _createIdentity(
      auth,
      email: 'household-owner-$suffix@example.com',
      password: password,
    );
    final successor = await _createIdentity(
      auth,
      email: 'household-successor-$suffix@example.com',
      password: password,
    );
    final removable = await _createIdentity(
      auth,
      email: 'household-removable-$suffix@example.com',
      password: password,
    );
    final jointHouseholdId = 'joint-admin-$suffix';
    final fallbackHouseholdId = 'solo-removable-$suffix';
    final now = DateTime.now().toUtc();
    await withTimeout(
      'seed trusted household Admin fixtures',
      () => seedFirestoreDocumentsThroughEmulatorAdmin({
        'users/${admin.uid}': {
          'email': admin.email,
          'isPremium': true,
          'activeHouseholdId': jointHouseholdId,
          'householdIds': [jointHouseholdId],
          'joinedPremiumHouseholdIds': <String>[],
          'createdJointHouseholdId': jointHouseholdId,
          'createdAt': now,
          'updatedAt': now,
        },
        'users/${successor.uid}': {
          'email': successor.email,
          'isPremium': true,
          'activeHouseholdId': jointHouseholdId,
          'householdIds': [jointHouseholdId],
          'joinedPremiumHouseholdIds': [jointHouseholdId],
          'createdAt': now,
          'updatedAt': now,
        },
        'users/${removable.uid}': {
          'email': removable.email,
          'isPremium': false,
          'activeHouseholdId': jointHouseholdId,
          'householdIds': [jointHouseholdId, fallbackHouseholdId],
          'joinedPremiumHouseholdIds': [jointHouseholdId],
          'createdSoloHouseholdId': fallbackHouseholdId,
          'createdAt': now,
          'updatedAt': now,
        },
        'households/$jointHouseholdId': {
          'name': 'Admin kitchen',
          'creatorUserId': admin.uid,
          'isJoint': true,
          'hasPremium': true,
          'maxMembers': 6,
          'memberCount': 3,
          'inviteCode': 'KS-ADMIN',
          'createdAt': now,
          'updatedAt': now,
        },
        'households/$jointHouseholdId/members/${admin.uid}': {
          'displayName': 'Original Admin',
          'email': admin.email,
          'role': 'admin',
          'joinedAt': now,
          'updatedAt': now,
        },
        'households/$jointHouseholdId/members/${successor.uid}': {
          'displayName': 'Premium Successor',
          'email': successor.email,
          'role': 'cook',
          'joinedAt': now,
          'updatedAt': now,
        },
        'households/$jointHouseholdId/members/${removable.uid}': {
          'displayName': 'Leaving Member',
          'email': removable.email,
          'role': 'shopper',
          'joinedAt': now,
          'updatedAt': now,
        },
        'households/$fallbackHouseholdId': {
          'name': 'Fallback kitchen',
          'creatorUserId': removable.uid,
          'isJoint': false,
          'hasPremium': false,
          'maxMembers': 1,
          'memberCount': 1,
          'inviteCode': 'KS-FALLBACK',
          'createdAt': now,
          'updatedAt': now,
        },
        'households/$fallbackHouseholdId/members/${removable.uid}': {
          'displayName': 'Leaving Member',
          'email': removable.email,
          'role': 'admin',
          'joinedAt': now,
          'updatedAt': now,
        },
        'users/${removable.uid}/notificationPreferences/$jointHouseholdId': {
          'householdId': jointHouseholdId,
          'mealChanges': true,
          'updatedAt': now,
        },
      }),
    );
    await withTimeout(
      'login original Admin',
      () => auth.signInWithEmailAndPassword(
        email: admin.email,
        password: password,
      ),
    );

    final router = GoRouter(
      initialLocation: '/manage-household',
      routes: [
        GoRoute(
          path: '/manage-household',
          builder: (_, __) => const HouseholdScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await _waitForText(tester, 'Premium Successor');
    expect(find.byType(KsMemberRow), findsNWidgets(3));
    expect(find.byType(KsInviteCode), findsOneWidget);

    await tester.tap(find.text('Premium Successor'));
    await _waitForText(tester, 'Transfer Admin');
    await tester.tap(find.text('Transfer Admin'));
    await _waitForText(tester, 'Transfer Admin?');
    await binding.takeScreenshot('household-transfer-admin-confirmation');
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await _waitForAbsent(tester, find.text("Premium Successor's role"));
    final transferred = await withTimeout(
      'read transferred Admin roles',
      () => Future.wait([
        db
            .collection('households')
            .doc(jointHouseholdId)
            .collection('members')
            .doc(admin.uid)
            .get(),
        db
            .collection('households')
            .doc(jointHouseholdId)
            .collection('members')
            .doc(successor.uid)
            .get(),
      ]),
    );
    expect(transferred[0].data()?['role'], 'member');
    expect(transferred[1].data()?['role'], 'admin');
    await _waitForAbsent(tester, find.byType(KsInviteCode));

    await withTimeout('sign out original Admin', auth.signOut);
    await withTimeout(
      'login transferred Admin',
      () => auth.signInWithEmailAndPassword(
        email: successor.email,
        password: password,
      ),
    );
    await _waitForFinder(tester, find.byType(KsInviteCode));
    await tester.tap(find.text('Leaving Member'));
    await _waitForText(tester, 'Remove member');
    await tester.tap(find.text('Remove member'));
    await _waitForText(tester, 'Remove member?');
    await binding.takeScreenshot('household-remove-member-confirmation');
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await _waitForAbsent(tester, find.text('Leaving Member'));

    final removedHouseholdState = await withTimeout(
      'read removed household membership state',
      () => Future.wait([
        db.collection('households').doc(jointHouseholdId).get(),
        db
            .collection('households')
            .doc(jointHouseholdId)
            .collection('members')
            .doc(removable.uid)
            .get(),
      ]),
    );
    expect(removedHouseholdState[0].data()?['memberCount'], 2);
    expect(removedHouseholdState[1].exists, isFalse);
    expect(
      await firestoreDocumentExistsThroughEmulatorAdmin(
        'users/${removable.uid}/notificationPreferences/$jointHouseholdId',
      ),
      isFalse,
    );

    await withTimeout('sign out transferred Admin', auth.signOut);
    await withTimeout(
      'login removed member',
      () => auth.signInWithEmailAndPassword(
        email: removable.email,
        password: password,
      ),
    );
    final removedUser = await withTimeout(
      'read removed member cleaned profile',
      () => db.collection('users').doc(removable.uid).get(),
    );
    expect(removedUser.data()?['activeHouseholdId'], fallbackHouseholdId);
    expect(removedUser.data()?['householdIds'], [fallbackHouseholdId]);
    expect(removedUser.data()?['joinedPremiumHouseholdIds'], isEmpty);
    final removedContainer = ProviderContainer();
    addTearDown(removedContainer.dispose);
    final restoredContext = await withTimeout(
      'restore removed member fallback context',
      () => removedContainer.read(activeHouseholdContextStreamProvider.future),
    );
    expect(restoredContext?.id, fallbackHouseholdId);
    expect(restoredContext?.isSolo, isTrue);
    await _waitForText(tester, 'FALLBACK KITCHEN · 1 OF 1');
    await binding.takeScreenshot('household-removed-member-fallback');
    await withTimeout('final household Admin sign out', auth.signOut);
  });
}

Future<({String uid, String email})> _createIdentity(
  FirebaseAuth auth, {
  required String email,
  required String password,
}) async {
  final credential = await withTimeout(
    'create $email',
    () => auth.createUserWithEmailAndPassword(email: email, password: password),
  );
  final identity = (uid: credential.user!.uid, email: email);
  await withTimeout('sign out $email', auth.signOut);
  return identity;
}

Future<void> _waitForFinder(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    debugPrint('HOUSEHOLD_ADMIN_INTEGRATION_FAILURE visible=$visibleText');
  }
  expect(finder, findsOneWidget);
}

Future<void> _waitForText(WidgetTester tester, String text) =>
    _waitForFinder(tester, find.text(text));

Future<void> _waitForAbsent(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
  expect(finder, findsNothing);
}
