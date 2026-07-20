import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/household/presentation/controllers/household_membership_command_controller.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:rxdart/rxdart.dart';

/// Screen 14 · Household & roles — who's in the kitchen.
///
/// Members with their roles plus Admin-only invite and role controls.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  void _manageMember(
    BuildContext context,
    WidgetRef ref,
    HouseholdMemberSummary member, {
    required bool canAssignRoles,
    required bool canRemoveMembers,
    required bool canTransferAdmin,
  }) {
    final ks = context.ksColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ks.scrim,
      builder: (_) => _RoleSheet(
        member: member,
        onSave: canAssignRoles ? (role) => _saveRole(ref, member, role) : null,
        onRemove: canRemoveMembers ? () => _removeMember(ref, member) : null,
        onTransferAdmin: canTransferAdmin
            ? () => _transferAdmin(ref, member)
            : null,
      ),
    );
  }

  Future<void> _saveRole(
    WidgetRef ref,
    HouseholdMemberSummary member,
    HouseholdRole role,
  ) async {
    final details = _requireCapability(ref, HouseholdCapability.assignRoles);
    if (member.isCurrentUser) {
      throw StateError('Use the transfer-admin flow to change your own role.');
    }
    await ref
        .read(firestoreProvider)
        .collection('households')
        .doc(details.id)
        .collection('members')
        .doc(member.userId)
        .update({'role': role.name, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _removeMember(
    WidgetRef ref,
    HouseholdMemberSummary member,
  ) async {
    final details = _requireCapability(ref, HouseholdCapability.removeMembers);
    if (member.isCurrentUser) {
      throw StateError('You cannot remove your own household membership.');
    }
    await ref
        .read(householdMembershipCommandControllerProvider)
        .removeMember(householdId: details.id, targetUserId: member.userId);
  }

  Future<void> _transferAdmin(
    WidgetRef ref,
    HouseholdMemberSummary member,
  ) async {
    final details = _requireCapability(ref, HouseholdCapability.transferAdmin);
    if (member.isCurrentUser) {
      throw StateError('Choose another Premium household member.');
    }
    await ref
        .read(householdMembershipCommandControllerProvider)
        .transferAdmin(householdId: details.id, targetUserId: member.userId);
  }

  HouseholdDetails _requireCapability(
    WidgetRef ref,
    HouseholdCapability capability,
  ) {
    final details = ref.read(householdDetailsProvider).valueOrNull;
    if (details == null) {
      throw StateError('Wait for household membership to finish loading.');
    }
    final currentMember = _currentMember(details.members);
    if (currentMember == null) {
      throw StateError('Your household membership is unavailable.');
    }
    if (!const HouseholdPolicy().roleCan(
      currentMember.role,
      capability,
      isSoloHousehold: !details.isJoint,
    )) {
      throw StateError(
        '${currentMember.role.label} cannot ${capability.name}.',
      );
    }
    return details;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final snapshot = ref.watch(householdDetailsProvider);
    final details = snapshot.asData?.value;
    const policy = HouseholdPolicy();
    final currentMember = details == null
        ? null
        : _currentMember(details.members);
    final canAssignRoles =
        details != null &&
        currentMember != null &&
        policy.roleCan(
          currentMember.role,
          HouseholdCapability.assignRoles,
          isSoloHousehold: !details.isJoint,
        );
    final canInviteMembers =
        details != null &&
        currentMember != null &&
        policy.roleCan(
          currentMember.role,
          HouseholdCapability.inviteMembers,
          isSoloHousehold: !details.isJoint,
        );
    final canRemoveMembers =
        details != null &&
        currentMember != null &&
        policy.roleCan(
          currentMember.role,
          HouseholdCapability.removeMembers,
          isSoloHousehold: !details.isJoint,
        );
    final canTransferAdmin =
        details != null &&
        currentMember != null &&
        policy.roleCan(
          currentMember.role,
          HouseholdCapability.transferAdmin,
          isSoloHousehold: !details.isJoint,
        );
    final headerEyebrow = details == null
        ? 'Household'
        : '${details.name} · ${details.members.length} '
              'of ${details.maxMembers}';
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            KsFolioHeader(
              eyebrow: headerEyebrow,
              title: "Who's in the kitchen",
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space16),
            if (snapshot.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: KsTokens.space8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (snapshot.hasError && details == null)
              KsErrorAlert(
                message: 'Could not load household: ${snapshot.error}',
              ),
            if (details != null && details.members.isEmpty)
              const KsEmptyState(
                icon: Icons.group_off_outlined,
                title: 'No household members',
                subtitle:
                    'No membership records are available for this kitchen.',
              ),
            if (details != null)
              for (var i = 0; i < details.members.length; i++) ...[
                if (i > 0) const SizedBox(height: KsTokens.space10),
                _MemberTile(
                  member: details.members[i],
                  onTap:
                      (canAssignRoles ||
                              canRemoveMembers ||
                              canTransferAdmin) &&
                          !details.members[i].isCurrentUser
                      ? () => _manageMember(
                          context,
                          ref,
                          details.members[i],
                          canAssignRoles: canAssignRoles,
                          canRemoveMembers: canRemoveMembers,
                          canTransferAdmin: canTransferAdmin,
                        )
                      : null,
                ),
              ],
            if (details != null &&
                canInviteMembers &&
                details.inviteCode != null &&
                details.inviteCode!.isNotEmpty) ...[
              const SizedBox(height: KsTokens.space20),
              KsInviteCode(code: details.inviteCode!, label: 'Invite code'),
            ],
          ],
        ),
      ),
    );
  }
}

final householdDetailsProvider = StreamProvider<HouseholdDetails>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final user = ref.watch(activeFirebaseUserProvider).valueOrNull;
  if (auth == null || user == null) {
    return Stream.error(StateError('Firebase authentication is unavailable.'));
  }
  final uid = user.uid;
  final db = ref.watch(firestoreProvider);
  return db.collection('users').doc(uid).snapshots().switchMap((
    userSnapshot,
  ) {
    final householdId = userSnapshot.data()?['activeHouseholdId'] as String?;
    if (householdId == null || householdId.isEmpty) {
      return Stream.error(StateError('No active household selected.'));
    }
    final householdDoc = db.collection('households').doc(householdId);
    return householdDoc.snapshots().switchMap((householdSnapshot) {
      if (!householdSnapshot.exists) {
        return Stream.error(
          StateError('The selected household no longer exists.'),
        );
      }
      final data = householdSnapshot.data() ?? const <String, dynamic>{};
      final isJoint = data['isJoint'] as bool? ?? false;
      final inviteCode = data['inviteCode'] as String?;
      final maxMembers = data['maxMembers'] as int? ?? (isJoint ? 6 : 1);
      final name = data['name'] as String? ?? 'My kitchen';
      return householdDoc.collection('members').snapshots().map((snapshot) {
        final members =
            [
              for (var i = 0; i < snapshot.docs.length; i++)
                _memberFromDoc(snapshot.docs[i], index: i, currentUserId: uid),
            ]..sort((a, b) {
              if (a.isCurrentUser != b.isCurrentUser) {
                return a.isCurrentUser ? -1 : 1;
              }
              return a.name.compareTo(b.name);
            });
        return HouseholdDetails(
          id: householdId,
          name: name,
          isJoint: isJoint,
          maxMembers: maxMembers,
          inviteCode: inviteCode,
          members: members,
        );
      });
    });
  });
});

HouseholdMemberSummary _memberFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc, {
  required int index,
  required String currentUserId,
}) {
  final data = doc.data();
  final roleName = data['role'] as String? ?? 'member';
  final name =
      data['displayName'] as String? ??
      (doc.id == currentUserId ? 'You' : 'Member ${index + 1}');
  final handle = data['email'] as String? ?? doc.id;
  return HouseholdMemberSummary(
    userId: doc.id,
    name: name,
    handle: doc.id == currentUserId ? 'you' : handle,
    role: HouseholdRole.values.firstWhere(
      (role) => role.name == roleName,
      orElse: () => HouseholdRole.member,
    ),
    seat: index,
    isCurrentUser: doc.id == currentUserId,
  );
}

class HouseholdDetails {
  const HouseholdDetails({
    required this.id,
    required this.name,
    required this.isJoint,
    required this.maxMembers,
    required this.inviteCode,
    required this.members,
  });

  final String id;
  final String name;
  final bool isJoint;
  final int maxMembers;
  final String? inviteCode;
  final List<HouseholdMemberSummary> members;
}

HouseholdMemberSummary? _currentMember(List<HouseholdMemberSummary> members) {
  for (final member in members) {
    if (member.isCurrentUser) return member;
  }
  return null;
}

class HouseholdMemberSummary {
  const HouseholdMemberSummary({
    required this.userId,
    required this.name,
    required this.handle,
    required this.role,
    required this.seat,
    this.isCurrentUser = false,
  });

  final String userId;
  final String name;
  final String handle;
  final HouseholdRole role;
  final int seat;
  final bool isCurrentUser;
}

/// A tappable member row. The admin (you) is non-interactive; everyone else
/// opens the role sheet.
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onTap});

  final HouseholdMemberSummary member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KsTokens.space4),
          child: KsMemberRow(
            name: member.handle == 'you' ? '${member.name} · you' : member.name,
            handle: member.handle == 'you' ? 'Admin' : member.handle,
            role: member.role,
            seat: member.seat,
            initial: member.name,
          ),
        ),
      ),
    );
  }
}

/// The role-assignment bottom sheet — a radio list of the four roles.
class _RoleSheet extends StatefulWidget {
  const _RoleSheet({
    required this.member,
    required this.onSave,
    required this.onRemove,
    required this.onTransferAdmin,
  });

  final HouseholdMemberSummary member;
  final Future<void> Function(HouseholdRole role)? onSave;
  final Future<void> Function()? onRemove;
  final Future<void> Function()? onTransferAdmin;

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late HouseholdRole _role = widget.member.role;
  bool _saving = false;

  static const _descriptions = {
    HouseholdRole.admin: 'Manage members & settings',
    HouseholdRole.cook: 'Plan meals & mark cooked',
    HouseholdRole.shopper: 'Handle the shopping lists',
    HouseholdRole.member: 'View & tick items',
  };

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KsTokens.radius20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space20,
        KsTokens.space12,
        KsTokens.space20,
        KsTokens.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ks.borderStrong,
                borderRadius: BorderRadius.circular(KsTokens.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          Row(
            children: [
              KsMemberAvatar(
                initial: widget.member.name,
                seat: widget.member.seat,
                size: 38,
              ),
              const SizedBox(width: KsTokens.space12),
              Text(
                "${widget.member.name}'s role",
                style: KsTokens.headlineLarge.copyWith(
                  color: ks.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space16),
          if (widget.onSave != null) ...[
            for (final role in HouseholdRole.values) ...[
              _RoleChoice(
                role: role,
                description: _descriptions[role]!,
                selected: _role == role,
                onTap: () => setState(() => _role = role),
              ),
              if (role != HouseholdRole.values.last)
                const SizedBox(height: KsTokens.space8),
            ],
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () => _runAction(
                      errorPrefix: 'Could not save role',
                      action: () => widget.onSave!(_role),
                    ),
              child: Text(_saving ? 'Saving...' : 'Save role'),
            ),
          ],
          if (widget.onTransferAdmin != null || widget.onRemove != null) ...[
            const SizedBox(height: KsTokens.space12),
            Divider(color: ks.border),
            const SizedBox(height: KsTokens.space8),
          ],
          if (widget.onTransferAdmin != null)
            OutlinedButton.icon(
              onPressed: _saving ? null : _confirmTransfer,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Transfer Admin'),
            ),
          if (widget.onRemove != null) ...[
            const SizedBox(height: KsTokens.space8),
            TextButton.icon(
              onPressed: _saving ? null : _confirmRemoval,
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Remove member'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmTransfer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transfer Admin?'),
        content: Text(
          '${widget.member.name} must have Premium. '
          'You will become a Member after the transfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(
      errorPrefix: 'Could not transfer Admin',
      action: widget.onTransferAdmin!,
    );
  }

  Future<void> _confirmRemoval() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          '${widget.member.name} will lose access to this household.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(
      errorPrefix: 'Could not remove member',
      action: widget.onRemove!,
    );
  }

  Future<void> _runAction({
    required String errorPrefix,
    required Future<void> Function() action,
  }) async {
    setState(() => _saving = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$errorPrefix: $error')));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.role,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final HouseholdRole role;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? Color.lerp(ks.surfaceRaised, ks.brandPrimary, 0.14)
                : ks.surfaceRaised,
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(
              color: selected ? ks.brandPrimary : ks.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _Radio(selected: selected),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      role.label,
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      description,
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? ks.surfaceRaised : Colors.transparent,
        border: Border.all(
          color: selected ? ks.brandPrimary : ks.borderStrong,
          width: selected ? 5 : 2,
        ),
      ),
    );
  }
}
