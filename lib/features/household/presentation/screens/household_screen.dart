import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

/// Screen 14 · Household & roles — who's in the kitchen.
///
/// Members with their roles + a shareable invite code. Tapping a member opens
/// the role-assignment sheet. Presentational P2 with representative members.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  static const _previewMembers = [
    _Member(name: 'Ana', handle: 'you', role: HouseholdRole.admin, seat: 0),
    _Member(name: 'Ben', handle: 'ben@home', role: HouseholdRole.cook, seat: 1),
    _Member(
      name: 'Eli',
      handle: 'eli@home',
      role: HouseholdRole.shopper,
      seat: 4,
    ),
  ];

  void _assignRole(BuildContext context, WidgetRef ref, _Member member) {
    final ks = context.ksColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ks.scrim,
      builder: (_) => _RoleSheet(
        member: member,
        onSave: (role) => _saveRole(ref, member, role),
      ),
    );
  }

  Future<void> _saveRole(
    WidgetRef ref,
    _Member member,
    HouseholdRole role,
  ) async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null || member.userId == null) return;
    final household = ref.read(activeHouseholdContextProvider);
    if (household == null) return;
    await ref
        .read(firestoreProvider)
        .collection('households')
        .doc(household.id)
        .collection('members')
        .doc(member.userId)
        .set({
          'role': role.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final snapshot = ref.watch(householdDetailsProvider);
    final details = snapshot.valueOrNull ?? _HouseholdDetails.preview();
    final members = details.members;
    final headerEyebrow =
        '${details.name} · ${members.length} of ${details.maxMembers}';
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
            for (var i = 0; i < members.length; i++) ...[
              if (i > 0) const SizedBox(height: KsTokens.space10),
              _MemberTile(
                member: members[i],
                onTap: members[i].isCurrentUser
                    ? null
                    : () => _assignRole(context, ref, members[i]),
              ),
            ],
            const SizedBox(height: KsTokens.space20),
            KsInviteCode(code: details.inviteCode, label: 'Invite code'),
          ],
        ),
      ),
    );
  }
}

final householdDetailsProvider = StreamProvider<_HouseholdDetails>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return Stream.value(_HouseholdDetails.preview());
  final household = ref.watch(activeHouseholdContextProvider);
  if (household == null) return Stream.value(_HouseholdDetails.preview());
  final uid = auth.currentUser?.uid ?? '';
  final db = ref.watch(firestoreProvider);
  final householdDoc = db.collection('households').doc(household.id);
  return householdDoc.snapshots().asyncExpand((householdSnapshot) {
    final data = householdSnapshot.data() ?? const <String, dynamic>{};
    final inviteCode = data['inviteCode'] as String? ?? 'SOLO';
    final maxMembers =
        data['maxMembers'] as int? ?? (household.isJoint ? 6 : 1);
    final name = data['name'] as String? ?? household.name;
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
      return _HouseholdDetails(
        name: name,
        maxMembers: maxMembers,
        inviteCode: inviteCode,
        members: members.isEmpty ? HouseholdScreen._previewMembers : members,
      );
    });
  });
});

_Member _memberFromDoc(
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
  return _Member(
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

class _HouseholdDetails {
  const _HouseholdDetails({
    required this.name,
    required this.maxMembers,
    required this.inviteCode,
    required this.members,
  });

  factory _HouseholdDetails.preview() => const _HouseholdDetails(
    name: 'The Holloway kitchen',
    maxMembers: 6,
    inviteCode: 'SAGE-417',
    members: HouseholdScreen._previewMembers,
  );

  final String name;
  final int maxMembers;
  final String inviteCode;
  final List<_Member> members;
}

class _Member {
  const _Member({
    required this.name,
    required this.handle,
    required this.role,
    required this.seat,
    this.userId,
    this.isCurrentUser = false,
  });

  final String? userId;
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

  final _Member member;
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
  const _RoleSheet({required this.member, required this.onSave});

  final _Member member;
  final Future<void> Function(HouseholdRole role) onSave;

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
                : () async {
                    setState(() => _saving = true);
                    try {
                      await widget.onSave(_role);
                    } catch (error) {
                      if (!context.mounted) return;
                      setState(() => _saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not save role: $error')),
                      );
                      return;
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: Text(_saving ? 'Saving...' : 'Save role'),
          ),
        ],
      ),
    );
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
