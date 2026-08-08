import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/household/presentation/controllers/household_invite_command_controller.dart';
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
        inviteCommands: ref.watch(householdInviteCommandControllerProvider),
        idGenerator: ref.watch(idGeneratorProvider),
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
    userIsPremium: false,
    canCreateSolo: true,
    canCreateJoint: true,
  );

  final List<HouseholdPickerOption> households;
  final bool userIsPremium;
  final bool canCreateSolo;
  final bool canCreateJoint;
}

class HouseholdOnboardingController {
  const HouseholdOnboardingController({
    required this.db,
    required this.auth,
    this.inviteCommands,
    this.idGenerator = const UuidV4IdGenerator(),
  });

  final FirebaseFirestore? db;
  final FirebaseAuth? auth;
  final HouseholdInviteCommandController? inviteCommands;
  final IdGenerator idGenerator;
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

  /// Returns true when the signed-in identity has no user profile yet.
  ///
  /// This is used after an OAuth callback as a safe retry signal: the first
  /// Firestore transaction either created all provisioning records or none of
  /// them, so an absent profile can be retried without creating a second solo
  /// household.
  Future<bool> needsInitialProvisioning() async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null) {
      throw StateError('Firebase is unavailable for household setup.');
    }
    final user = _requireSignedInUser(auth);
    _requireVerifiedEmail(user);
    return !(await db.collection('users').doc(user.uid).get()).exists;
  }

  /// Creates (or restores) the one deterministic solo household owned by a
  /// Firebase identity. The profile, household, and Admin membership are
  /// committed in one transaction.
  ///
  /// A repeated callback, interrupted registration, or concurrent retry uses
  /// the same household document ID and observes the existing membership on a
  /// transaction retry. It never deletes the Firebase identity on failure.
  Future<String> ensureInitialSoloHousehold() async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null) {
      throw StateError('Firebase is unavailable for household setup.');
    }
    final user = _requireSignedInUser(auth);
    _requireVerifiedEmail(user);
    final userDoc = db.collection('users').doc(user.uid);
    final householdId = soloHouseholdIdForUser(user.uid);
    final householdDoc = db.collection('households').doc(householdId);
    final memberDoc = householdDoc.collection('members').doc(user.uid);

    return db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDoc);
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final existingSoloId = userData['createdSoloHouseholdId'] as String?;
      final now = FieldValue.serverTimestamp();

      if (existingSoloId?.isNotEmpty ?? false) {
        final knownSoloId = existingSoloId!;
        final targetHousehold = db.collection('households').doc(knownSoloId);
        final targetMember = targetHousehold
            .collection('members')
            .doc(user.uid);
        final householdSnapshot = await transaction.get(targetHousehold);
        final membershipSnapshot = await transaction.get(targetMember);
        if (!householdSnapshot.exists || !membershipSnapshot.exists) {
          throw StateError(
            'Your existing solo household is incomplete. Contact support '
            'before creating another.',
          );
        }
        // A prior successful transaction may have selected another household.
        // Re-select the known valid solo membership without duplicating it.
        transaction.set(userDoc, {
          'activeHouseholdId': knownSoloId,
          'householdIds': FieldValue.arrayUnion([knownSoloId]),
          'updatedAt': now,
        }, SetOptions(merge: true));
        return knownSoloId;
      }

      // Do not read the proposed household before its membership exists: the
      // rules correctly deny arbitrary household reads. The user document is
      // the transaction reservation. A concurrent callback conflicts on that
      // document, retries, then follows the existing-id branch above.
      final targetId = householdId;
      final targetHousehold = householdDoc;
      final targetMember = memberDoc;
      transaction
        ..set(userDoc, {
          ..._profileFieldsFor(
            user: user,
            now: now,
            isNew: !userSnapshot.exists,
          ),
          'activeHouseholdId': targetId,
          'householdIds': FieldValue.arrayUnion([targetId]),
          'createdSoloHouseholdId': targetId,
          'updatedAt': now,
        }, SetOptions(merge: true))
        ..set(targetHousehold, {
          'name': 'My kitchen',
          'creatorUserId': user.uid,
          'ownerUserId': user.uid,
          'isJoint': false,
          'hasPremium': false,
          'maxMembers': 1,
          'memberCount': 1,
          'createdAt': now,
          'updatedAt': now,
        })
        ..set(targetMember, {
          'role': HouseholdRole.admin.name,
          'userId': user.uid,
          'householdId': targetId,
          'schemaVersion': 1,
          'joinedAt': now,
          'updatedAt': now,
        });
      return targetId;
    });
  }

  /// The regular household picker reuses the idempotent solo path. Joint
  /// creation remains separately policy-gated and transactionally serialized.
  Future<String> createHousehold({required KitchenKind kind}) {
    return switch (kind) {
      KitchenKind.solo => ensureInitialSoloHousehold(),
      KitchenKind.joint => _createJointHousehold(),
    };
  }

  Future<String> _createJointHousehold() async {
    final auth = this.auth;
    final db = this.db;
    final functions = this.functions;
    if (auth == null || db == null) {
      throw StateError('Firebase is unavailable for household setup.');
    }
    final user = _requireSignedInUser(auth);
    final userDoc = db.collection('users').doc(user.uid);
    // Allocate the ID once. If two callers race, Firestore retries the second
    // transaction and the persisted `createdJointHouseholdId` makes policy
    // reject it before this unused ID is ever written.
    final householdDoc = db.collection('households').doc();
    final householdId = householdDoc.id;
    final memberDoc = householdDoc.collection('members').doc(user.uid);

    return db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDoc);
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final userIsPremium = userData['isPremium'] as bool? ?? false;
      final hasCreatedJoint =
          (userData['createdJointHouseholdId'] as String?)?.isNotEmpty ?? false;
      final hasCreatedSolo =
          (userData['createdSoloHouseholdId'] as String?)?.isNotEmpty ?? false;
      final specResult = _policy.creationSpec(
        HouseholdCreationRequest(
          userIsPremium: userIsPremium,
          requestJointHousehold: true,
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
      transaction
        ..set(userDoc, {
          ..._profileFieldsFor(
            user: user,
            now: now,
            isNew: !userSnapshot.exists,
          ),
          'activeHouseholdId': householdId,
          'householdIds': FieldValue.arrayUnion([householdId]),
          'createdJointHouseholdId': householdId,
          'updatedAt': now,
        }, SetOptions(merge: true))
        ..set(householdDoc, {
          'name': 'Shared kitchen',
          'creatorUserId': user.uid,
          'isJoint': true,
          'hasPremium': true,
          'maxMembers': spec.maxMembers,
          'memberCount': 1,
          'createdAt': now,
          'updatedAt': now,
        })
        ..set(memberDoc, {
          'role': spec.initialRole.name,
          'joinedAt': now,
          'updatedAt': now,
        });
    final data = response.data;
    if (data is! Map || data['householdId'] is! String) {
      throw StateError('The joint household transfer response was malformed.');
    }
    return data['householdId'] as String;
  }

  Future<void> joinHousehold({required String code, String? commandId}) async {
    final inviteToken = normalizeInviteToken(code);
    if (inviteToken.isEmpty) {
      throw StateError('Enter an invite code.');
    }
    if (inviteToken.toUpperCase().startsWith('KS-')) {
      throw StateError(
        'This invite cannot be used. Ask the household Admin for a new invite.',
      );
    }
    final auth = this.auth;
    if (auth == null) {
      throw StateError('Secure household invites are unavailable right now.');
    }
    _requireSignedInUser(auth);
    final commands = inviteCommands;
    if (commands == null) {
      throw StateError('Secure household invites are unavailable right now.');
    }
    await commands.redeem(
      inviteToken: inviteToken,
      commandId: commandId ?? idGenerator.newId(),
    );
  }

  User _requireSignedInUser(FirebaseAuth auth) {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before setting up a household.');
    }
    return user;
  }

  void _requireVerifiedEmail(User user) {
    if (!user.emailVerified) {
      throw StateError(
        'Verify your email before creating or joining a household.',
      );
    }
  }

  /// A UID is stable across app restarts and provider callbacks, making this
  /// a safe idempotency key for an account's one free solo household.
  @visibleForTesting
  static String soloHouseholdIdForUser(String uid) => 'solo-$uid';

  static Map<String, Object?> _profileFieldsFor({
    required User user,
    required Object now,
    required bool isNew,
  }) {
    if (!isNew) return const <String, Object?>{};
    return <String, Object?>{
      'isPremium': false,
      'joinedPremiumHouseholdIds': const <String>[],
      if (user.email != null) 'email': user.email,
      if (user.displayName != null) 'displayName': user.displayName,
      if (user.photoURL != null) 'photoUrl': user.photoURL,
      'providerIds': user.providerData
          .map((provider) => provider.providerId)
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      'createdAt': now,
    };
  }

  @visibleForTesting
  static String normalizeInviteToken(String token) =>
      token.trim().replaceAll(RegExp(r'\s+'), '');
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
  String? _joinCommandId;

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
          .joinHousehold(
            code: _controller.text,
            commandId:
                _joinCommandId ??= ref.read(idGeneratorProvider).newId(),
          );
    } catch (error) {
      if (!mounted) return;
      final reason = error is StateError
          ? error.message
          : 'This invite cannot be used. Ask the household Admin for a new '
                'invite.';
      final message = 'Could not join household: $reason';
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
    ref
      ..invalidate(householdPickerProvider)
      ..invalidate(activeHouseholdContextStreamProvider);
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
                  onChanged: (_) => _joinCommandId = null,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Paste invite token',
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
