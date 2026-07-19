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
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'premium creation and invite join persist an isolated household context',
    (tester) async {
      const initializer = FirebaseInitializer();
      await withTimeout(
        'configure household Firebase emulators',
        () => initializer.bootstrap(AppEnv.dev),
      );
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      await withTimeout('clear household auth session', auth.signOut);

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      await tester.pumpAndSettle();

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
      final inviteCode = joint.data()?['inviteCode'] as String?;
      expect(inviteCode, isNotNull);
      await withTimeout(
        'assign Cook invite role',
        () => db.collection('householdInvites').doc(inviteCode).update({
          'role': HouseholdRole.cook.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );

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
      await tester.pumpAndSettle();
      final codeField = find.widgetWithText(TextField, 'SAGE-417');
      await tester.ensureVisible(codeField);
      await tester.enterText(codeField, inviteCode!);
      await tester.pump();
      await binding.takeScreenshot('household-join-code');
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
      expect(joinedState[1].data()?['role'], HouseholdRole.cook.name);
      expect(joinedState[2].data()?['memberCount'], 2);

      router.go('/manage-household');
      await _waitForText(tester, "Who's in the kitchen");
      expect(find.byType(KsMemberRow), findsNWidgets(2));
      expect(find.byType(KsInviteCode), findsNothing);
      await tester.tap(find.text(adminUid));
      await tester.pumpAndSettle();
      expect(find.text('Save role'), findsNothing);
      await binding.takeScreenshot('household-cook-read-only');

      router.go('/household');
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
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

      await withTimeout('sign out Cook before Admin role update', auth.signOut);
      await withTimeout(
        'login premium Admin for visible role update',
        () => auth.signInWithEmailAndPassword(
          email: 'household-admin-$suffix@example.com',
          password: password,
        ),
      );
      router.go('/manage-household');
      await _waitForText(tester, "Who's in the kitchen");
      await _waitForFinder(
        tester,
        find.byType(KsInviteCode),
        label: 'Admin invite code',
      );
      final inviteeHandle = find.text(inviteeUid);
      await tester.ensureVisible(inviteeHandle);
      await tester.tap(inviteeHandle);
      await _waitForText(tester, 'Save role');
      await tester.tap(find.text(HouseholdRole.shopper.label).last);
      await tester.pump();
      await tester.tap(find.text('Save role'));
      await tester.pumpAndSettle();
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
  );
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required String label,
}) async {
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
  await tester.pumpAndSettle();
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
