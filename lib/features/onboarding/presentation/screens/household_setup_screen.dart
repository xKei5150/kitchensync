import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

/// Screen 13 (step 2) · Onboarding — set up your kitchen.
///
/// Solo, joint (premium), or join with a code. Creating a kitchen persists the
/// active household session so app-wide role and premium gates use real data.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

enum KitchenKind { solo, joint }

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  KitchenKind _kind = KitchenKind.solo;
  bool _saving = false;
  String? _selectingHouseholdId;
  String? _selectionError;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(householdOnboardingControllerProvider)
          .createHousehold(kind: _kind);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create household: $error')),
      );
      return;
    }
    if (!mounted) return;
    context.go('/today');
  }

  Future<void> _selectHousehold(HouseholdPickerOption household) async {
    setState(() {
      _selectingHouseholdId = household.id;
      _selectionError = null;
    });
    try {
      await ref
          .read(householdOnboardingControllerProvider)
          .selectHousehold(householdId: household.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectingHouseholdId = null;
        _selectionError = 'Could not select household: $error';
      });
      return;
    }
    ref.invalidate(householdPickerProvider);
    if (!mounted) return;
    context.go('/today');
  }

  Future<void> _skipForNow() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(skipHouseholdSetupPrefKey, true);
    ref.invalidate(activeHouseholdContextProvider);
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/today');
    } else {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    final picker = ref.watch(householdPickerProvider);
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, KsTokens.space16, 22, 22),
          children: [
            Row(
              children: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                Text(
                  'Step 2 of 2'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            picker.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: KsTokens.space24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose your kitchen',
                    style: KsTokens.displayMedium.copyWith(
                      color: ks.textPrimary,
                      fontSize: 27,
                      height: 1.05,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space12),
                  KsErrorAlert(message: 'Could not load households: $error'),
                  const SizedBox(height: KsTokens.space12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(householdPickerProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
              data: (state) => _HouseholdPickerBody(
                state: state,
                selectedKind: _kind,
                saving: _saving,
                selectingHouseholdId: _selectingHouseholdId,
                selectionError: _selectionError,
                onKindSelected: (kind) => setState(() => _kind = kind),
                onCreate: _finish,
                onSelect: _selectHousehold,
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: KsTokens.space8),
              TextButton(
                onPressed: _saving ? null : _skipForNow,
                child: const Text('Skip for now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final householdOnboardingControllerProvider =
    Provider<HouseholdOnboardingController>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      return HouseholdOnboardingController(
        db: auth == null ? null : ref.watch(firestoreProvider),
        auth: auth,
      );
    });

final householdPickerProvider =
    FutureProvider.autoDispose<HouseholdPickerState>(
      (ref) =>
          ref.watch(householdOnboardingControllerProvider).loadPickerState(),
    );

class HouseholdPickerOption {
  const HouseholdPickerOption({
    required this.id,
    required this.name,
    required this.role,
    required this.isJoint,
    required this.hasPremium,
    required this.isActive,
  });

  final String id;
  final String name;
  final HouseholdRole role;
  final bool isJoint;
  final bool hasPremium;
  final bool isActive;
}

class HouseholdPickerState {
  const HouseholdPickerState({
    required this.households,
    required this.userIsPremium,
    required this.canCreateSolo,
    required this.canCreateJoint,
  });

  static const empty = HouseholdPickerState(
    households: [],
    userIsPremium: true,
    canCreateSolo: true,
    canCreateJoint: true,
  );

  final List<HouseholdPickerOption> households;
  final bool userIsPremium;
  final bool canCreateSolo;
  final bool canCreateJoint;
}

class HouseholdOnboardingController {
  const HouseholdOnboardingController({required this.db, required this.auth});

  final FirebaseFirestore? db;
  final FirebaseAuth? auth;
  static const _policy = HouseholdPolicy();

  Future<HouseholdPickerState> loadPickerState() async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null || auth.currentUser == null) {
      return HouseholdPickerState.empty;
    }
    final user = auth.currentUser!;
    final userSnapshot = await db.collection('users').doc(user.uid).get();
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final activeHouseholdId = userData['activeHouseholdId'] as String?;
    final householdIds =
        ((userData['householdIds'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
    final households = <HouseholdPickerOption>[];
    for (final householdId in householdIds) {
      final memberSnapshot = await db
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(user.uid)
          .get();
      if (!memberSnapshot.exists) continue;
      final householdSnapshot = await db
          .collection('households')
          .doc(householdId)
          .get();
      final household = householdSnapshot.data();
      if (household == null) continue;
      final roleName = memberSnapshot.data()?['role'] as String? ?? 'member';
      households.add(
        HouseholdPickerOption(
          id: householdId,
          name: household['name'] as String? ?? 'My kitchen',
          role: HouseholdRole.values.firstWhere(
            (role) => role.name == roleName,
            orElse: () => HouseholdRole.member,
          ),
          isJoint: household['isJoint'] as bool? ?? false,
          hasPremium: household['hasPremium'] as bool? ?? false,
          isActive: householdId == activeHouseholdId,
        ),
      );
    }
    households.sort((left, right) {
      if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    final userIsPremium = userData['isPremium'] as bool? ?? false;
    final hasSolo = households.any((household) => !household.isJoint);
    final hasCreatedJoint =
        (userData['createdJointHouseholdId'] as String?)?.isNotEmpty ?? false;
    return HouseholdPickerState(
      households: households,
      userIsPremium: userIsPremium,
      canCreateSolo:
          !hasSolo &&
          !((userData['createdSoloHouseholdId'] as String?)?.isNotEmpty ??
              false),
      canCreateJoint: userIsPremium && !hasCreatedJoint,
    );
  }

  Future<void> selectHousehold({required String householdId}) async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null) {
      throw StateError('Firebase is unavailable for household selection.');
    }
    final user = _requireSignedInUser(auth);
    final userDoc = db.collection('users').doc(user.uid);
    final householdDoc = db.collection('households').doc(householdId);
    final memberDoc = householdDoc.collection('members').doc(user.uid);
    await db.runTransaction((transaction) async {
      final memberSnapshot = await transaction.get(memberDoc);
      if (!memberSnapshot.exists) {
        throw StateError('You are no longer a member of this household.');
      }
      final householdSnapshot = await transaction.get(householdDoc);
      if (!householdSnapshot.exists) {
        throw StateError('Household not found.');
      }
      transaction.set(userDoc, {
        'activeHouseholdId': householdId,
        'householdIds': FieldValue.arrayUnion([householdId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<String> createHousehold({required KitchenKind kind}) async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null) {
      throw StateError('Firebase is unavailable for household setup.');
    }
    final user = _requireSignedInUser(auth);
    final userDoc = db.collection('users').doc(user.uid);
    final userSnap = await userDoc.get();
    final storedPremium = userSnap.data()?['isPremium'] as bool? ?? false;
    final userData = userSnap.data() ?? const <String, dynamic>{};
    final requestJoint = kind == KitchenKind.joint;
    final userIsPremium = storedPremium;
    final hasCreatedJoint =
        (userData['createdJointHouseholdId'] as String?)?.isNotEmpty ?? false;
    final hasCreatedSolo =
        (userData['createdSoloHouseholdId'] as String?)?.isNotEmpty ?? false;
    final specResult = _policy.creationSpec(
      HouseholdCreationRequest(
        userIsPremium: userIsPremium,
        requestJointHousehold: requestJoint,
        existingSoloHouseholds: hasCreatedSolo ? 1 : 0,
        existingCreatedJointHouseholds: hasCreatedJoint ? 1 : 0,
      ),
    );
    final spec = switch (specResult) {
      Success(value: final value) => value,
      ResultFailure(failure: final failure) => throw StateError(
        failure.toString(),
      ),
    };

    final now = FieldValue.serverTimestamp();
    final households = db.collection('households');
    final householdDoc = households.doc();
    final householdId = householdDoc.id;
    final memberDoc = householdDoc.collection('members').doc(user.uid);
    final isJoint = spec.isJoint;
    final inviteCode = _inviteCodeFor(householdId);
    final inviteDoc = db.collection('householdInvites').doc(inviteCode);
    final batch = db.batch()
      ..set(userDoc, {
        'activeHouseholdId': householdId,
        'householdIds': FieldValue.arrayUnion([householdId]),
        if (!userSnap.exists) 'isPremium': false,
        if (isJoint) 'createdJointHouseholdId': householdId,
        if (!isJoint) 'createdSoloHouseholdId': householdId,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true))
      ..set(householdDoc, {
        'name': isJoint ? 'Shared kitchen' : 'My kitchen',
        'creatorUserId': user.uid,
        'isJoint': isJoint,
        'hasPremium': isJoint && userIsPremium,
        'maxMembers': spec.maxMembers,
        'memberCount': 1,
        'inviteCode': inviteCode,
        'createdAt': now,
        'updatedAt': now,
      })
      ..set(memberDoc, {
        'role': spec.initialRole.name,
        'joinedAt': now,
        'updatedAt': now,
      })
      ..set(inviteDoc, {
        'householdId': householdId,
        'createdBy': user.uid,
        'role': HouseholdRole.member.name,
        'active': isJoint,
        'createdAt': now,
        'updatedAt': now,
      });
    await batch.commit();
    return householdId;
  }

  Future<void> joinHousehold({required String code}) async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null) {
      throw StateError('Firebase is unavailable for household setup.');
    }
    final user = _requireSignedInUser(auth);
    final normalizedCode = _normalizeInviteCode(code);
    if (normalizedCode.isEmpty) {
      throw StateError('Enter an invite code.');
    }

    final inviteDoc = db.collection('householdInvites').doc(normalizedCode);
    final initialInvite = (await inviteDoc.get()).data();
    final initialHouseholdId = initialInvite?['householdId'] as String?;
    if (initialInvite == null ||
        initialInvite['active'] != true ||
        initialHouseholdId == null ||
        initialHouseholdId.isEmpty) {
      throw StateError('Invite code not found.');
    }
    final householdDoc = db.collection('households').doc(initialHouseholdId);
    final userDoc = db.collection('users').doc(user.uid);
    final memberDoc = householdDoc.collection('members').doc(user.uid);

    await db.runTransaction((transaction) async {
      final inviteSnap = await transaction.get(inviteDoc);
      final invite = inviteSnap.data();
      if (invite == null || invite['active'] != true) {
        throw StateError('Invite code not found.');
      }
      final householdId = invite['householdId'] as String?;
      if (householdId != initialHouseholdId) {
        throw StateError('Invite code changed. Retry joining.');
      }
      final userSnap = await transaction.get(userDoc);
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final existingMember = await transaction.get(memberDoc);
      final now = FieldValue.serverTimestamp();

      if (existingMember.exists) {
        transaction.set(userDoc, {
          'activeHouseholdId': householdId,
          'householdIds': FieldValue.arrayUnion([householdId]),
          'updatedAt': now,
        }, SetOptions(merge: true));
        return;
      }

      final invitedRole = switch (invite['role']) {
        'member' => HouseholdRole.member,
        'shopper' => HouseholdRole.shopper,
        'cook' => HouseholdRole.cook,
        _ => throw StateError('Invite code has an invalid household role.'),
      };
      final joinedPremiumHouseholds =
          (userData['joinedPremiumHouseholdIds'] as List<dynamic>?) ?? const [];
      final existingJoinedPremiumHouseholds = joinedPremiumHouseholds
          .whereType<String>()
          .where((id) => id != householdId)
          .length;
      if (userData['isPremium'] != true &&
          existingJoinedPremiumHouseholds > 0) {
        throw StateError('Free users can only join one premium household.');
      }

      transaction
        ..set(memberDoc, {
          'role': invitedRole.name,
          'inviteCode': normalizedCode,
          'joinedAt': now,
          'updatedAt': now,
        })
        ..set(userDoc, {
          'activeHouseholdId': householdId,
          'householdIds': FieldValue.arrayUnion([householdId]),
          if (!userSnap.exists) 'isPremium': false,
          if (!userSnap.exists) 'createdAt': now,
          'joinedPremiumHouseholdIds': FieldValue.arrayUnion([householdId]),
          'updatedAt': now,
        }, SetOptions(merge: true))
        ..update(householdDoc, {
          'memberCount': FieldValue.increment(1),
          'updatedAt': now,
        });
    });
  }

  User _requireSignedInUser(FirebaseAuth auth) {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before setting up a household.');
    }
    return user;
  }

  static String _inviteCodeFor(String householdId) {
    final normalized = householdId
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toUpperCase();
    final suffix = normalized.padRight(6, '0').substring(0, 6);
    return 'KS-$suffix';
  }

  static String _normalizeInviteCode(String code) =>
      code.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
}

class _HouseholdPickerBody extends StatelessWidget {
  const _HouseholdPickerBody({
    required this.state,
    required this.selectedKind,
    required this.saving,
    required this.selectingHouseholdId,
    required this.selectionError,
    required this.onKindSelected,
    required this.onCreate,
    required this.onSelect,
  });

  final HouseholdPickerState state;
  final KitchenKind selectedKind;
  final bool saving;
  final String? selectingHouseholdId;
  final String? selectionError;
  final ValueChanged<KitchenKind> onKindSelected;
  final VoidCallback onCreate;
  final ValueChanged<HouseholdPickerOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final hasHouseholds = state.households.isNotEmpty;
    final canCreate = state.canCreateSolo || state.canCreateJoint;
    final selectedCreationAllowed =
        (selectedKind == KitchenKind.solo && state.canCreateSolo) ||
        (selectedKind == KitchenKind.joint && state.canCreateJoint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasHouseholds ? 'Choose your kitchen' : 'Set up your kitchen',
          style: KsTokens.displayMedium.copyWith(
            color: ks.textPrimary,
            fontSize: 27,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: KsTokens.space2),
        Text(
          hasHouseholds
              ? 'Pick where you want to cook today.'
              : 'Cook alone, or with your people.',
          style: KsTokens.displaySmall.copyWith(
            color: ks.textSecondary,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        if (hasHouseholds) ...[
          const SizedBox(height: KsTokens.space20),
          Text(
            'Your kitchens',
            style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
          ),
          const SizedBox(height: KsTokens.space10),
          for (var index = 0; index < state.households.length; index++) ...[
            if (index > 0) const SizedBox(height: KsTokens.space10),
            _HouseholdPickerCard(
              household: state.households[index],
              selecting: selectingHouseholdId == state.households[index].id,
              selectionLocked: selectingHouseholdId != null,
              onSelect: () => onSelect(state.households[index]),
            ),
          ],
          if (selectionError != null) ...[
            const SizedBox(height: KsTokens.space10),
            KsErrorAlert(message: selectionError!),
          ],
        ],
        if (canCreate) ...[
          const SizedBox(height: KsTokens.space24),
          Text(
            hasHouseholds ? 'Add a kitchen' : 'Create a kitchen',
            style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
          ),
          const SizedBox(height: KsTokens.space10),
          if (state.canCreateSolo) ...[
            _KitchenOption(
              icon: Icons.person_outline_rounded,
              title: 'Just me',
              subtitle: 'A private, one-person kitchen',
              selected: selectedKind == KitchenKind.solo,
              onTap: () => onKindSelected(KitchenKind.solo),
            ),
            if (state.canCreateJoint) const SizedBox(height: KsTokens.space12),
          ],
          if (state.canCreateJoint)
            _KitchenOption(
              icon: Icons.groups_outlined,
              title: 'Create a household',
              subtitle: 'Up to 6 people, shared lists',
              selected: selectedKind == KitchenKind.joint,
              premium: true,
              onTap: () => onKindSelected(KitchenKind.joint),
            ),
        ],
        const SizedBox(height: KsTokens.space12),
        const _JoinWithCode(),
        if (canCreate) ...[
          const SizedBox(height: KsTokens.space24),
          FilledButton(
            onPressed: saving || !selectedCreationAllowed ? null : onCreate,
            child: Text(saving ? 'Setting up...' : 'Create and enter'),
          ),
        ],
      ],
    );
  }
}

class _HouseholdPickerCard extends StatelessWidget {
  const _HouseholdPickerCard({
    required this.household,
    required this.selecting,
    required this.selectionLocked,
    required this.onSelect,
  });

  final HouseholdPickerOption household;
  final bool selecting;
  final bool selectionLocked;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: household.isActive
            ? Color.lerp(ks.surfaceRaised, ks.brandPrimary, 0.12)
            : ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(
          color: household.isActive ? ks.brandPrimary : ks.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ks.neutralSubtle,
              borderRadius: BorderRadius.circular(KsTokens.radius10),
            ),
            child: Icon(
              household.isJoint
                  ? Icons.groups_outlined
                  : Icons.person_outline_rounded,
              size: 20,
              color: ks.textSecondary,
            ),
          ),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  household.name,
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  '${household.role.label} · '
                  '${household.isJoint ? 'Shared' : 'Solo'}'
                  '${household.hasPremium ? ' · Premium' : ''}',
                  style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: KsTokens.space8),
          FilledButton.tonal(
            key: ValueKey('pick-household-${household.id}'),
            onPressed: household.isActive || selectionLocked ? null : onSelect,
            child: Text(
              household.isActive
                  ? 'Active'
                  : selecting
                  ? 'Selecting...'
                  : 'Pick',
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenOption extends StatelessWidget {
  const _KitchenOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.premium = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool premium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected
                ? Color.lerp(ks.surfaceRaised, ks.brandPrimary, 0.14)
                : ks.surfaceRaised,
            borderRadius: BorderRadius.circular(KsTokens.radius16),
            border: Border.all(
              color: selected ? ks.brandPrimary : ks.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? ks.brandPrimary.withValues(alpha: 0.22)
                      : ks.neutralSubtle,
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? ks.brandPrimary : ks.textSecondary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: KsTokens.titleSmall.copyWith(
                              color: ks.textPrimary,
                            ),
                          ),
                        ),
                        if (premium) ...[
                          const SizedBox(width: KsTokens.space6),
                          const KsBadge.premium(),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: KsTokens.space8),
                Icon(Icons.check_rounded, size: 18, color: ks.brandPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Join with a code" card — an icon row over a code well + Join action.
class _JoinWithCode extends ConsumerStatefulWidget {
  const _JoinWithCode();

  @override
  ConsumerState<_JoinWithCode> createState() => _JoinWithCodeState();
}

class _JoinWithCodeState extends ConsumerState<_JoinWithCode> {
  final _controller = TextEditingController();
  bool _joining = false;
  String? _joinError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _joinError = null;
    });
    try {
      await ref
          .read(householdOnboardingControllerProvider)
          .joinHousehold(code: _controller.text);
    } catch (error) {
      if (!mounted) return;
      final message = 'Could not join household: $error';
      setState(() {
        _joining = false;
        _joinError = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ks.neutralSubtle,
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: ks.textSecondary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Join with a code',
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                      ),
                    ),
                    Text(
                      'Got an invite?',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'SAGE-417',
                    filled: true,
                    fillColor: ks.surfaceBase,
                    contentPadding: const EdgeInsets.all(11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KsTokens.radius8),
                      borderSide: BorderSide(color: ks.borderStrong),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KsTokens.radius8),
                      borderSide: BorderSide(color: ks.borderStrong),
                    ),
                  ),
                  style: KsTokens.headlineLarge.copyWith(
                    color: ks.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              FilledButton(
                onPressed: _joining ? null : _join,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KsTokens.space16,
                    vertical: 14,
                  ),
                ),
                child: Text(_joining ? 'Joining...' : 'Join'),
              ),
            ],
          ),
          if (_joinError != null) ...[
            const SizedBox(height: KsTokens.space10),
            KsErrorAlert(message: _joinError!),
          ],
        ],
      ),
    );
  }
}
