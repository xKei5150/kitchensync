import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_household_id_provider.g.dart';

class ActiveHouseholdContext {
  const ActiveHouseholdContext({
    required this.id,
    required this.name,
    required this.role,
    required this.isJoint,
    required this.hasPremium,
  });

  final String id;
  final String name;
  final HouseholdRole role;
  final bool isJoint;
  final bool hasPremium;

  bool get isSolo => !isJoint;
}

const previewHouseholdContext = ActiveHouseholdContext(
  id: debugPreviewHouseholdId,
  name: debugHouseholdName,
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

const skipHouseholdSetupPrefKey = 'debug.skip_household_setup';

/// Firebase Auth is only available after [Firebase.initializeApp].
///
/// Widget tests that render screens without booting Firebase receive `null`
/// here, and [activeHouseholdContextProvider] uses the preview context. The
/// initialized app path never falls back to a hard-coded household.
final firebaseAuthProvider = Provider<FirebaseAuth?>(
  (ref) => Firebase.apps.isEmpty ? null : FirebaseAuth.instance,
);

final activeFirebaseUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return Stream.value(null);
  return auth.authStateChanges();
});

final activeUserIdProvider = Provider<String>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return debugUserId;
  final user = ref.watch(activeFirebaseUserProvider).valueOrNull;
  if (user == null) {
    if (kDebugMode) return debugUserId;
    throw StateError('No signed-in user.');
  }
  return user.uid;
});

final activeHouseholdContextProvider = Provider<ActiveHouseholdContext?>((ref) {
  final skipHouseholdSetup =
      kDebugMode &&
      (ref
              .watch(sharedPreferencesProvider)
              .getBool(skipHouseholdSetupPrefKey) ??
          false);
  if (skipHouseholdSetup) return previewHouseholdContext;

  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return previewHouseholdContext;
  final household = ref.watch(activeHouseholdContextStreamProvider).valueOrNull;
  if (kDebugMode) return household ?? previewHouseholdContext;
  return household;
});

final activeHouseholdContextStreamProvider =
    StreamProvider<ActiveHouseholdContext?>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      if (auth == null) return Stream.value(previewHouseholdContext);
      final refs = ref.watch(firestoreRefsProvider);
      return auth.authStateChanges().asyncExpand((user) {
        if (user == null) {
          return Stream.value(kDebugMode ? previewHouseholdContext : null);
        }
        return refs.user(user.uid).snapshots().asyncExpand((userDoc) {
          final activeHouseholdId =
              userDoc.data()?['activeHouseholdId'] as String?;
          if (activeHouseholdId == null || activeHouseholdId.isEmpty) {
            return Stream.value(kDebugMode ? previewHouseholdContext : null);
          }
          return _watchHouseholdContext(
            refs: refs,
            uid: user.uid,
            householdId: activeHouseholdId,
          );
        });
      });
    });

Stream<ActiveHouseholdContext?> _watchHouseholdContext({
  required FirestoreRefs refs,
  required String uid,
  required String householdId,
}) {
  return refs.household(householdId).snapshots().asyncExpand((householdDoc) {
    if (!householdDoc.exists) {
      return Stream.value(kDebugMode ? previewHouseholdContext : null);
    }
    return refs.householdMember(householdId, uid).snapshots().map((memberDoc) {
      if (!memberDoc.exists) {
        return kDebugMode ? previewHouseholdContext : null;
      }
      return _contextFromDocs(
        householdId: householdId,
        household: householdDoc,
        membership: memberDoc,
      );
    });
  });
}

ActiveHouseholdContext _contextFromDocs({
  required String householdId,
  required DocumentSnapshot<Map<String, dynamic>> household,
  required DocumentSnapshot<Map<String, dynamic>> membership,
}) {
  final householdData = household.data() ?? const <String, dynamic>{};
  final membershipData = membership.data() ?? const <String, dynamic>{};
  final roleName = membershipData['role'] as String? ?? 'member';
  return ActiveHouseholdContext(
    id: householdId,
    name: householdData['name'] as String? ?? 'My kitchen',
    role: HouseholdRole.values.firstWhere(
      (role) => role.name == roleName,
      orElse: () => HouseholdRole.member,
    ),
    isJoint: householdData['isJoint'] as bool? ?? false,
    hasPremium: householdData['hasPremium'] as bool? ?? false,
  );
}

/// Returns the active household id for data calls scoped by household.
///
/// Router guards prevent module routes without an active context. If a feature
/// still tries to perform a scoped data operation while no household is active,
/// this throws instead of silently writing into a fake household.
@Riverpod(keepAlive: true)
String activeHouseholdId(Ref ref) {
  final household = ref.watch(activeHouseholdContextProvider);
  if (household == null) {
    throw StateError('No active household selected.');
  }
  return household.id;
}
