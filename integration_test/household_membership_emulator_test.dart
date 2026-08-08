import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const trustedCallableTestName = trustedInviteCallableDeviceTestsEnabled
      ? 'trusted issue and redemption persist an isolated household context'
      : 'trusted issue and redemption persist an isolated household context '
            '(SKIPPED: $trustedInviteCallableDeviceTestPrerequisite)';

  testWidgets(
    trustedCallableTestName,
    // A live Functions deployment is deliberately required for this flow.
    (tester) async {
      const initializer = FirebaseInitializer();
      await withTimeout(
        'configure household Firebase emulators',
        () => initializer.bootstrap(AppEnv.dev),
      );
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      await withTimeout('clear household auth session', auth.signOut);

      if (defaultTargetPlatform != TargetPlatform.android) {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        // Pin the keyboard inset. `enterText` focuses the invite-code field,
        // which makes the iOS Simulator raise its software keyboard; it reports
        // a viewInsets bottom of 837-1000pt against an 852pt viewport, the join
        // Row collapses, and its sibling Join button leaves the widget tree.
        tester.view.viewInsets = FakeViewPadding.zero;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
      }

      final router = GoRouter(
        initialLocation: '/household',
        routes: [
          GoRoute(
            path: '/household',
            builder: (_, __) => const HouseholdSetupScreen(),
          ),
          GoRoute(
            path: '/today',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Household context active')),
            ),
          ),
          GoRoute(
            path: '/manage-household',
            builder: (_, __) => const HouseholdScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await binding.convertFlutterSurfaceToImage();
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
      await settleOrAdvance(tester);

      final suffix = DateTime.now().microsecondsSinceEpoch;
      const password = 'KitchenSync-123!';
      final adminCredential = await withTimeout(
        'create premium household admin',
        () => auth.createUserWithEmailAndPassword(
          email: 'household-admin-$suffix@example.com',
          password: password,
        ),
      );
      final adminUid = adminCredential.user!.uid;
      await withTimeout(
        'grant trusted Premium fixture',
        () => seedFirestoreDocumentsThroughEmulatorAdmin({
          'users/$adminUid': {
            'email': adminCredential.user!.email,
            'isPremium': true,
            'householdIds': <String>[],
            'joinedPremiumHouseholdIds': <String>[],
            'createdAt': DateTime.now().toUtc(),
            'updatedAt': DateTime.now().toUtc(),
          },
        }),
      );

      await tester.tap(find.text('Create a household'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Create and enter'));
      await _waitForText(tester, 'Household context active');

      final adminUser = await withTimeout(
        'read premium admin household state',
        () => db.collection('users').doc(adminUid).get(),
      );
      final jointHouseholdId =
          adminUser.data()?['createdJointHouseholdId'] as String?;
      expect(jointHouseholdId, isNotNull);
      expect(jointHouseholdId, isNotEmpty);
      final jointRef = db.collection('households').doc(jointHouseholdId);
      final joint = await withTimeout(
        'read created joint household',
        jointRef.get,
      );
      expect(joint.data()?['hasPremium'], isTrue);
      expect(joint.data()?['maxMembers'], 6);
      expect(joint.data()?['memberCount'], 1);
      expect(joint.data()!.containsKey('inviteCode'), isFalse);
      await _expectLegacyInvitePathDenied(db, 'KS-$jointHouseholdId');

      // The only source for the bearer token is the fresh issue response.
      // No fixture or household field provides it, and leaving this screen
      // disposes the widget state that displays it.
      router.go('/manage-household');
      await _waitForText(tester, "Who's in the kitchen");
      await _waitForText(tester, 'Create invite');
      expect(find.byType(KsInviteCode), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Create invite'));
      await _waitForFinder(
        tester,
        find.byType(KsInviteCode),
        label: 'fresh trusted invite token',
      );
      final inviteToken = tester
          .widget<KsInviteCode>(find.byType(KsInviteCode))
          .code;
      expect(inviteToken, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      final postIssueState = await withTimeout(
        'verify fresh invite token is not persisted in client-readable state',
        () => Future.wait([
          jointRef.get(),
          db.collection('users').doc(adminUid).get(),
          jointRef.collection('members').doc(adminUid).get(),
        ]),
      );
      for (final snapshot in postIssueState) {
        expect(snapshot.data()!.containsValue(inviteToken), isFalse);
      }

      router.go('/household');
      await _waitForText(tester, 'Choose your kitchen');
      expect(find.byType(KsInviteCode), findsNothing);

      await withTimeout('sign out premium admin', auth.signOut);
      final inviteeCredential = await withTimeout(
        'create free household invitee',
        () => auth.createUserWithEmailAndPassword(
          email: 'household-invitee-$suffix@example.com',
          password: password,
        ),
      );
      final inviteeUid = inviteeCredential.user!.uid;
      final controller = HouseholdOnboardingController(db: db, auth: auth);
      final soloHouseholdId = await withTimeout(
        'create invitee solo household',
        () => controller.createHousehold(kind: KitchenKind.solo),
      );

      router.go('/household');
      await settleOrAdvance(tester);
      final codeField = find.widgetWithText(TextField, 'Paste invite token');
      await tester.ensureVisible(codeField);
      // This is the local test's only remaining copy of the freshly issued
      // bearer token. It is not persisted by the app before redemption.
      await tester.enterText(codeField, inviteToken);
      await tester.pump();
      if (defaultTargetPlatform == TargetPlatform.android) {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));
      }
      final joinButton = find.widgetWithText(FilledButton, 'Join');
      await tester.ensureVisible(joinButton);
      await tester.tap(joinButton);
      await _waitForText(tester, 'Household context active');

      final joinedState = await withTimeout(
        'read joined household state',
        () => Future.wait([
          db.collection('users').doc(inviteeUid).get(),
          jointRef.collection('members').doc(inviteeUid).get(),
          jointRef.get(),
        ]),
      );
      expect(joinedState[0].data()?['activeHouseholdId'], jointHouseholdId);
      expect(
        (joinedState[0].data()?['householdIds'] as List<dynamic>?)?.toSet(),
        {soloHouseholdId, jointHouseholdId},
      );
      expect(joinedState[1].data()?['role'], HouseholdRole.member.name);
      expect(joinedState[2].data()?['memberCount'], 2);

      router.go('/manage-household');
      await _waitForText(tester, "Who's in the kitchen");
      expect(find.byType(KsMemberRow), findsNWidgets(2));
      expect(find.byType(KsInviteCode), findsNothing);
      await tester.tap(find.text(adminUid));
      await settleOrAdvance(tester);
      expect(find.text('Save role'), findsNothing);
      await binding.takeScreenshot('household-member-read-only');

      router.go('/household');
      await settleOrAdvance(tester);
      await _waitForText(tester, 'Choose your kitchen');
      expect(find.text('Shared kitchen'), findsOneWidget);
      expect(find.text('My kitchen'), findsOneWidget);
      await binding.takeScreenshot('household-picker');
      final pickSolo = find.byKey(ValueKey('pick-household-$soloHouseholdId'));
      await tester.ensureVisible(pickSolo);
      await tester.tap(pickSolo);
      await _waitForText(tester, 'Household context active');
      final soloSelected = await withTimeout(
        'read selected solo household state',
        () => db.collection('users').doc(inviteeUid).get(),
      );
      expect(soloSelected.data()?['activeHouseholdId'], soloHouseholdId);

      router.go('/household');
      await settleOrAdvance(tester);
      final pickJoint = find.byKey(
        ValueKey('pick-household-$jointHouseholdId'),
      );
      await tester.ensureVisible(pickJoint);
      await tester.tap(pickJoint);
      await _waitForText(tester, 'Household context active');
      final jointSelected = await withTimeout(
        'read reselected joint household state',
        () => db.collection('users').doc(inviteeUid).get(),
      );
      expect(jointSelected.data()?['activeHouseholdId'], jointHouseholdId);

      await withTimeout(
        'sign out Member before Admin role update',
        auth.signOut,
      );
      await withTimeout(
        'login premium Admin for visible role update',
        () => auth.signInWithEmailAndPassword(
          email: 'household-admin-$suffix@example.com',
          password: password,
        ),
      );
      router.go('/manage-household');
      await _waitForText(tester, "Who's in the kitchen");
      await _waitForText(tester, 'Create invite');
      expect(find.byType(KsInviteCode), findsNothing);
      final inviteeHandle = find.text(inviteeUid);
      await tester.ensureVisible(inviteeHandle);
      await tester.tap(inviteeHandle);
      await _waitForText(tester, 'Save role');
      await tester.tap(find.text(HouseholdRole.shopper.label).last);
      await tester.pump();
      await tester.tap(find.text('Save role'));
      await settleOrAdvance(tester);
      final reassignedMembership = await withTimeout(
        'read reassigned Shopper membership',
        () => jointRef.collection('members').doc(inviteeUid).get(),
      );
      expect(reassignedMembership.data()?['role'], HouseholdRole.shopper.name);
      await binding.takeScreenshot('household-admin-role-assigned');

      await withTimeout('sign out Admin after role update', auth.signOut);
      await withTimeout(
        'login joined user again',
        () => auth.signInWithEmailAndPassword(
          email: 'household-invitee-$suffix@example.com',
          password: password,
        ),
      );
      final joinedContainer = ProviderContainer();
      addTearDown(joinedContainer.dispose);
      final restoredContext = await withTimeout(
        'restore active household provider context',
        () => joinedContainer.read(activeHouseholdContextStreamProvider.future),
      );
      expect(restoredContext?.id, jointHouseholdId);
      expect(restoredContext?.role, HouseholdRole.shopper);

      await withTimeout(
        'sign out joined user for isolation check',
        auth.signOut,
      );
      await withTimeout(
        'create outsider identity',
        () => auth.createUserWithEmailAndPassword(
          email: 'household-outsider-$suffix@example.com',
          password: password,
        ),
      );
      await expectLater(
        jointRef.get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      final outsiderContainer = ProviderContainer();
      addTearDown(outsiderContainer.dispose);
      final outsiderContext = await withTimeout(
        'resolve outsider household context',
        () =>
            outsiderContainer.read(activeHouseholdContextStreamProvider.future),
      );
      expect(outsiderContext, isNull);
      await withTimeout('final household sign out', auth.signOut);
    },
    skip: !trustedInviteCallableDeviceTestsEnabled,
  );

  testWidgets('legacy invite tokens are rejected without legacy state or '
      'context mutation', (_) async {
    const initializer = FirebaseInitializer();
    await withTimeout(
      'configure legacy invite rejection Firebase emulators',
      () => initializer.bootstrap(AppEnv.dev),
    );
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await withTimeout(
      'clear legacy invite rejection auth session',
      auth.signOut,
    );

    final suffix = DateTime.now().microsecondsSinceEpoch;
    const password = 'KitchenSync-123!';
    final invitee = await withTimeout(
      'create legacy invite rejection identity',
      () => auth.createUserWithEmailAndPassword(
        email: 'legacy-invitee-$suffix@example.com',
        password: password,
      ),
    );
    final inviteeUid = invitee.user!.uid;
    final controller = HouseholdOnboardingController(db: db, auth: auth);
    final soloHouseholdId = await withTimeout(
      'create legacy invite rejection solo household',
      () => controller.createHousehold(kind: KitchenKind.solo),
    );
    final jointHouseholdId = 'legacy-invite-target-$suffix';
    final legacyToken = 'KS-$suffix';
    final now = DateTime.now().toUtc();
    await withTimeout(
      'seed legacy invite rejection household without legacy invite state',
      () => seedFirestoreDocumentsThroughEmulatorAdmin({
        'households/$jointHouseholdId': {
          'name': 'Invite target',
          'creatorUserId': 'legacy-admin-$suffix',
          'isJoint': true,
          'hasPremium': true,
          'maxMembers': 6,
          'memberCount': 1,
          'createdAt': now,
          'updatedAt': now,
        },
        'households/$jointHouseholdId/members/legacy-admin-$suffix': {
          'role': HouseholdRole.admin.name,
          'joinedAt': now,
          'updatedAt': now,
        },
      }),
    );
    await _expectLegacyInvitePathDenied(db, legacyToken);

    await expectLater(
      controller.joinHousehold(code: legacyToken),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('cannot be used'),
        ),
      ),
    );
    expect(
      await firestoreDocumentExistsThroughEmulatorAdmin(
        'households/$jointHouseholdId/members/$inviteeUid',
      ),
      isFalse,
    );
    final inviteeState = await withTimeout(
      'read legacy invite rejection profile',
      () => db.collection('users').doc(inviteeUid).get(),
    );
    expect(inviteeState.data()?['activeHouseholdId'], soloHouseholdId);
    expect(inviteeState.data()?['householdIds'], [soloHouseholdId]);
    await withTimeout('final legacy invite rejection sign out', auth.signOut);
  });
}

Future<void> _expectLegacyInvitePathDenied(
  FirebaseFirestore db,
  String legacyToken,
) => expectLater(
  db
      .collection('householdInvites')
      .doc(legacyToken)
      .get(const GetOptions(source: Source.server)),
  throwsA(
    isA<FirebaseException>().having(
      (error) => error.code,
      'code',
      'permission-denied',
    ),
  ),
);

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required String label,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settleOrAdvance(tester);
  if (finder.evaluate().isEmpty) {
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    debugPrint(
      'HOUSEHOLD_INTEGRATION_FAILURE expected=$label visible=$visibleText',
    );
  }
  expect(finder, findsOneWidget, reason: 'Expected $label to become visible.');
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (find.text(text).evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final joinError = find.textContaining('Could not join household:');
    if (joinError.evaluate().isNotEmpty) {
      final message = tester.widget<Text>(joinError.first).data;
      throw TestFailure(message ?? 'Household join failed.');
    }
  }
  await settleOrAdvance(tester);
  if (find.text(text).evaluate().isEmpty) {
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    debugPrint(
      'HOUSEHOLD_INTEGRATION_FAILURE expected=$text visible=$visibleText',
    );
  }
  expect(find.text(text), findsOneWidget);
}
