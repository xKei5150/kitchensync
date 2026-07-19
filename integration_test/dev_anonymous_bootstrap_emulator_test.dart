import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('debug emulator bootstraps an anonymous free solo household', (
    tester,
  ) async {
    const initializer = FirebaseInitializer();
    await withTimeout(
      'configure Firebase emulators',
      () => initializer.bootstrap(AppEnv.dev),
    );
    await withTimeout(
      'clear existing auth session',
      FirebaseAuth.instance.signOut,
    );

    await withTimeout(
      'finish anonymous development initialization',
      () => initializer.finishInitialization(AppEnv.dev),
    );

    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    expect(user!.isAnonymous, isTrue);

    final householdId = debugHouseholdIdForUser(user.uid);
    final db = FirebaseFirestore.instance;
    final snapshots = await withTimeout(
      'read anonymous bootstrap documents',
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
  });
}
