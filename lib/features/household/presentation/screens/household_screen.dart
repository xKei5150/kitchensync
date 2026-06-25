import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 14 · Household & roles — who's in the kitchen.
///
/// Members with their roles + a shareable invite code. Tapping a member opens
/// the role-assignment sheet. Presentational P2 with representative members.
class HouseholdScreen extends StatelessWidget {
  const HouseholdScreen({super.key});

  static const _members = [
    _Member(name: 'Ana', handle: 'you', role: HouseholdRole.admin, seat: 0),
    _Member(name: 'Ben', handle: 'ben@home', role: HouseholdRole.cook, seat: 1),
    _Member(
      name: 'Eli',
      handle: 'eli@home',
      role: HouseholdRole.shopper,
      seat: 4,
    ),
  ];

  void _assignRole(BuildContext context, _Member member) {
    final ks = context.ksColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ks.scrim,
      builder: (_) => _RoleSheet(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
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
              eyebrow: 'The Holloway kitchen · 3 of 6',
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
            for (var i = 0; i < _members.length; i++) ...[
              if (i > 0) const SizedBox(height: KsTokens.space10),
              _MemberTile(
                member: _members[i],
                onTap: _members[i].role == HouseholdRole.admin
                    ? null
                    : () => _assignRole(context, _members[i]),
              ),
            ],
            const SizedBox(height: KsTokens.space20),
            const KsInviteCode(code: 'SAGE-417', label: 'Invite code'),
          ],
        ),
      ),
    );
  }
}

class _Member {
  const _Member({
    required this.name,
    required this.handle,
    required this.role,
    required this.seat,
  });

  final String name;
  final String handle;
  final HouseholdRole role;
  final int seat;
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
  const _RoleSheet({required this.member});

  final _Member member;

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late HouseholdRole _role = widget.member.role;

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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Save role'),
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
