import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

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

/// The finite session states which are safe for routing.
///
/// In particular, [loadingAuth] and [loadingHousehold] are deliberately not
/// represented by a fabricated household. A data screen must wait for one of
/// [signedOut], [needsHouseholdSetup], or [ready] instead.
enum AppSessionPhase {
  loadingAuth,
  signedOut,
  loadingHousehold,
  needsHouseholdSetup,
  ready,
  error,
  unavailable,
}

class AppSessionState {
  const AppSessionState({
    required this.phase,
    this.user,
    this.household,
    this.error,
  });

  const AppSessionState.loadingAuth()
    : this(phase: AppSessionPhase.loadingAuth);
  const AppSessionState.signedOut() : this(phase: AppSessionPhase.signedOut);
  const AppSessionState.loadingHousehold(User user)
    : this(phase: AppSessionPhase.loadingHousehold, user: user);
  const AppSessionState.needsHouseholdSetup(User user)
    : this(phase: AppSessionPhase.needsHouseholdSetup, user: user);
  const AppSessionState.ready({
    required User user,
    required ActiveHouseholdContext household,
  }) : this(phase: AppSessionPhase.ready, user: user, household: household);
  const AppSessionState.error({User? user, required Object error})
    : this(phase: AppSessionPhase.error, user: user, error: error);
  const AppSessionState.unavailable()
    : this(phase: AppSessionPhase.unavailable);

  final AppSessionPhase phase;
  final User? user;
  final ActiveHouseholdContext? household;
  final Object? error;

  bool get isLoading =>
      phase == AppSessionPhase.loadingAuth ||
      phase == AppSessionPhase.loadingHousehold;
}

/// Firebase Auth is only available after [Firebase.initializeApp].
///
/// The production entry point initializes Firebase before rendering. A null
/// value therefore means an explicitly isolated widget test or an unavailable
/// Firebase setup, never a reason to fabricate a signed-in household.
final firebaseAuthProvider = Provider<FirebaseAuth?>(
  (ref) => Firebase.apps.isEmpty ? null : FirebaseAuth.instance,
);

final activeFirebaseUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return Stream.value(null);
  return auth.authStateChanges();
});

final activeHouseholdContextStreamProvider =
    StreamProvider<ActiveHouseholdContext?>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      if (auth == null) return Stream.value(null);
      final refs = ref.watch(firestoreRefsProvider);
      return auth.authStateChanges().switchMap((user) {
        if (user == null) {
          return Stream.value(null);
        }
        return refs.user(user.uid).snapshots().switchMap((userDoc) {
          final activeHouseholdId =
              userDoc.data()?['activeHouseholdId'] as String?;
          if (activeHouseholdId == null || activeHouseholdId.isEmpty) {
            return Stream.value(null);
          }
          return _watchHouseholdContext(
            refs: refs,
            uid: user.uid,
            householdId: activeHouseholdId,
          );
        });
      });
    });

/// The authoritative identity + household state for application routing.
///
/// This provider purposely retains the distinction between a Firestore read
/// that has not completed, a user who needs onboarding, and a read that failed.
/// That prevents redirect races and prevents signed-out users from seeing a
/// previous household while listeners are being torn down.
final appSessionStateProvider = Provider<AppSessionState>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return const AppSessionState.unavailable();

  final authState = ref.watch(activeFirebaseUserProvider);
  return authState.when(
    loading: () => const AppSessionState.loadingAuth(),
    error: (error, _) => AppSessionState.error(error: error),
    data: (user) {
      if (user == null) return const AppSessionState.signedOut();
      final householdState = ref.watch(activeHouseholdContextStreamProvider);
      return householdState.when(
        loading: () => AppSessionState.loadingHousehold(user),
        error: (error, _) => AppSessionState.error(user: user, error: error),
        data: (household) => household == null
            ? AppSessionState.needsHouseholdSetup(user)
            : AppSessionState.ready(user: user, household: household),
      );
    },
  );
});

/// The active household is null unless the server has confirmed a real
/// membership. Tests that need a household inject this provider explicitly.
final activeHouseholdContextProvider = Provider<ActiveHouseholdContext?>((ref) {
  return ref.watch(appSessionStateProvider).household;
});

/// An actor used only by isolated widget tests that deliberately do not boot
/// Firebase. It is never a session or household fallback: production starts
/// Firebase before rendering, and a real signed-out Firebase Auth instance
/// still makes [activeUserIdProvider] fail closed below.
// Keep legacy isolated presentation fixtures deterministic. This is not used
// by a booted application or by any Firebase-backed request.
const isolatedWidgetTestUserId = 'demo-user';

final activeUserIdProvider = Provider<String>((ref) {
  // Several focused widget tests exercise presentation-only controls without
  // installing Firebase plugins. Let those explicitly isolated trees supply a
  // deterministic actor while retaining the production invariant that a
  // booted-but-signed-out app cannot act as any user.
  if (ref.watch(firebaseAuthProvider) == null) {
    return isolatedWidgetTestUserId;
  }
  final user = ref.watch(appSessionStateProvider).user;
  if (user == null) throw StateError('No signed-in user.');
  return user.uid;
});

Stream<ActiveHouseholdContext?> _watchHouseholdContext({
  required FirestoreRefs refs,
  required String uid,
  required String householdId,
}) {
  // Read the self membership first. Its rule explicitly permits a user to
  // inspect their own (including absent) membership, while a household read
  // requires membership. This turns a stale/removed active household into the
  // recoverable `null` state instead of a permission-denied route error.
  return refs.householdMember(householdId, uid).snapshots().switchMap((
    memberDoc,
  ) {
    if (!memberDoc.exists) {
      return Stream.value(null);
    }
    return refs.household(householdId).snapshots().map((householdDoc) {
      if (!householdDoc.exists) {
        return null;
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
