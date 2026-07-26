import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'emulator fixtures use a disposable non-anonymous free solo household',
    (tester) async {
      const useEmulator = bool.fromEnvironment('USE_EMULATOR');
      if (!useEmulator) {
        throw StateError('Run this test with --dart-define=USE_EMULATOR=true.');
      }
      await bootEmulatedApp(clearExistingSession: true);
      final user = FirebaseAuth.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.isAnonymous, isFalse);

      final householdId = debugHouseholdIdForUser(user.uid);
      final db = FirebaseFirestore.instance;
      final snapshots = await withTimeout(
        'read emulator bootstrap documents',
        () => Future.wait([
          db.collection('users').doc(user.uid).get(),
          db.collection('households').doc(householdId).get(),
          db
              .collection('households')
              .doc(householdId)
              .collection('members')
              .doc(user.uid)
              .get(),
        ]),
      );

      expect(snapshots[0].data()?['activeHouseholdId'], householdId);
      expect(snapshots[0].data()?['isPremium'], isFalse);
      expect(snapshots[1].data()?['creatorUserId'], user.uid);
      expect(snapshots[1].data()?['isJoint'], isFalse);
      expect(snapshots[1].data()?['hasPremium'], isFalse);
      expect(snapshots[2].data()?['role'], 'admin');
    },
  );
}
