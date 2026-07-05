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

enum _KitchenKind { solo, joint }

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  _KitchenKind _kind = _KitchenKind.solo;
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(_householdOnboardingControllerProvider)
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
            Text(
              'Set up your kitchen',
              style: KsTokens.displayMedium.copyWith(
                color: ks.textPrimary,
                fontSize: 27,
                height: 1.05,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: KsTokens.space2),
            Text(
              'Cook alone, or with your people.',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textSecondary,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: KsTokens.space20),
            _KitchenOption(
              icon: Icons.person_outline_rounded,
              title: 'Just me',
              subtitle: 'A private, one-person kitchen',
              selected: _kind == _KitchenKind.solo,
              onTap: () => setState(() => _kind = _KitchenKind.solo),
            ),
            const SizedBox(height: KsTokens.space12),
            _KitchenOption(
              icon: Icons.groups_outlined,
              title: 'Create a household',
              subtitle: 'Up to 6 people, shared lists',
              selected: _kind == _KitchenKind.joint,
              premium: true,
              onTap: () => setState(() => _kind = _KitchenKind.joint),
            ),
            const SizedBox(height: KsTokens.space12),
            const _JoinWithCode(),
            const SizedBox(height: KsTokens.space24),
            FilledButton(
              onPressed: _saving ? null : _finish,
              child: Text(_saving ? 'Setting up...' : 'Enter the kitchen'),
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

final _householdOnboardingControllerProvider =
    Provider<_HouseholdOnboardingController>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      return _HouseholdOnboardingController(
        db: auth == null ? null : ref.watch(firestoreProvider),
        auth: auth,
      );
    });

class _HouseholdOnboardingController {
  const _HouseholdOnboardingController({required this.db, required this.auth});

  final FirebaseFirestore? db;
  final FirebaseAuth? auth;
  static const _policy = HouseholdPolicy();

  Future<void> createHousehold({required _KitchenKind kind}) async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null) return;
    final user = _requireSignedInUser(auth);
    final userDoc = db.collection('users').doc(user.uid);
    final userSnap = await userDoc.get();
    final storedPremium = userSnap.data()?['isPremium'] as bool? ?? false;
    final userData = userSnap.data() ?? const <String, dynamic>{};
    final requestJoint = kind == _KitchenKind.joint;
    final userIsPremium = storedPremium || requestJoint;
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
        'isPremium': userIsPremium,
        if (isJoint) 'createdJointHouseholdId': householdId,
        if (!isJoint) 'createdSoloHouseholdId': householdId,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true))
      ..set(householdDoc, {
        'name': isJoint ? 'Shared kitchen' : 'My kitchen',
        'creatorUserId': user.uid,
        'isJoint': isJoint,
        'hasPremium': isJoint,
        'maxMembers': spec.maxMembers,
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
  }

  Future<void> joinHousehold({required String code}) async {
    final auth = this.auth;
    final db = this.db;
    if (auth == null || db == null) return;
    final user = _requireSignedInUser(auth);
    final normalizedCode = _normalizeInviteCode(code);
    if (normalizedCode.isEmpty) {
      throw StateError('Enter an invite code.');
    }

    final inviteDoc = db.collection('householdInvites').doc(normalizedCode);
    final inviteSnap = await inviteDoc.get();
    final invite = inviteSnap.data();
    if (invite == null || invite['active'] != true) {
      throw StateError('Invite code not found.');
    }

    final householdId = invite['householdId'] as String?;
    if (householdId == null || householdId.isEmpty) {
      throw StateError('Invite code is incomplete.');
    }
    final householdDoc = db.collection('households').doc(householdId);
    final householdSnap = await householdDoc.get();
    final household = householdSnap.data();
    if (household == null) {
      throw StateError('Household not found.');
    }

    final userDoc = db.collection('users').doc(user.uid);
    final userSnap = await userDoc.get();
    final userData = userSnap.data() ?? const <String, dynamic>{};
    final memberSnap = await householdDoc.collection('members').get();
    final joinedPremiumHouseholds =
        (userData['joinedPremiumHouseholdIds'] as List<dynamic>?) ?? const [];
    final approvalResult = _policy.joinApproval(
      HouseholdJoinRequest(
        userIsPremium: userData['isPremium'] as bool? ?? false,
        householdIsJoint: household['isJoint'] as bool? ?? false,
        householdHasPremium: household['hasPremium'] as bool? ?? false,
        currentMemberCount: memberSnap.size,
        maxMembers: household['maxMembers'] as int? ?? 1,
        existingJoinedPremiumHouseholds: joinedPremiumHouseholds
            .whereType<String>()
            .where((id) => id != householdId)
            .length,
      ),
    );
    final approval = switch (approvalResult) {
      Success(value: final value) => value,
      ResultFailure(failure: final failure) => throw StateError(
        failure.toString(),
      ),
    };

    final now = FieldValue.serverTimestamp();
    final memberDoc = householdDoc.collection('members').doc(user.uid);
    final batch = db.batch()
      ..set(memberDoc, {
        'role': approval.defaultRole.name,
        'inviteCode': normalizedCode,
        'joinedAt': now,
        'updatedAt': now,
      })
      ..set(userDoc, {
        'activeHouseholdId': householdId,
        if (household['hasPremium'] == true)
          'joinedPremiumHouseholdIds': FieldValue.arrayUnion([householdId]),
        'updatedAt': now,
      }, SetOptions(merge: true));
    await batch.commit();
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await ref
          .read(_householdOnboardingControllerProvider)
          .joinHousehold(code: _controller.text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join household: $error')),
      );
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
        ],
      ),
    );
  }
}
