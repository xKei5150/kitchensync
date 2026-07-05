import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

/// Screen 09 · Shopping home + Shop Now.
///
/// The Shop tab landing: scheduled shop dates, a slim history, and a prominent
/// Shop Now that opens the "how far ahead?" setup before building a generated
/// list. The in-store checklist lives at `/shop/list`.
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  Future<void> _openShopNow(BuildContext context, WidgetRef ref) async {
    final weeksAhead = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ShopNowSheet(),
    );
    if (weeksAhead != null && context.mounted) {
      final record = await ref
          .read(shoppingPlanningControllerProvider)
          .generateShopNowList(weeksAhead: weeksAhead);
      if (context.mounted) {
        unawaited(context.push('/shop/list/${record.id}'));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(activeShoppingListsProvider);
    final household = ref.watch(activeHouseholdContextProvider);
    final canShopNow = _can(household, HouseholdCapability.initiateShopNow);
    return SafeArea(
      bottom: false,
      child: lists.when(
        data: (records) {
          final pending = records
              .where((list) => list.status == ShoppingListStatus.pending)
              .toList(growable: false);
          final suggestions = pending
              .where(
                (list) =>
                    list.type == ShoppingListType.suggested ||
                    list.type == ShoppingListType.emergency,
              )
              .toList(growable: false);
          final upcoming = pending
              .where(
                (list) =>
                    list.type == ShoppingListType.scheduled ||
                    list.type == ShoppingListType.shopNow,
              )
              .toList(growable: false);
          final history =
              records
                  .where((list) => list.status == ShoppingListStatus.completed)
                  .toList(growable: false)
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return _ShoppingHomeBody(
            upcoming: upcoming,
            suggestions: suggestions,
            history: history,
            canShopNow: canShopNow,
            onShopNow: () => _openShopNow(context, ref),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(KsTokens.space16),
          child: Center(
            child: KsErrorAlert(message: 'Could not load shopping: $error'),
          ),
        ),
      ),
    );
  }

  bool _can(ActiveHouseholdContext? household, HouseholdCapability capability) {
    if (household == null) return false;
    return const HouseholdPolicy().roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    );
  }
}

class _ShoppingHomeBody extends ConsumerWidget {
  const _ShoppingHomeBody({
    required this.upcoming,
    required this.suggestions,
    required this.history,
    required this.canShopNow,
    required this.onShopNow,
  });

  final List<ShoppingListRecord> upcoming;
  final List<ShoppingListRecord> suggestions;
  final List<ShoppingListRecord> history;
  final bool canShopNow;
  final VoidCallback onShopNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space8,
        KsTokens.space16,
        KsTokens.space24,
      ),
      children: [
        const KsFolioHeader(eyebrow: 'The Shop', title: 'Shopping'),
        const SizedBox(height: KsTokens.space16),
        _ShopNowCard(
          onStart: canShopNow ? onShopNow : null,
          locked: !canShopNow,
        ),
        const SizedBox(height: KsTokens.space20),
        if (suggestions.isNotEmpty) ...[
          const _SectionLabel('Suggestions'),
          const SizedBox(height: KsTokens.space10),
          for (final list in suggestions) ...[
            _SuggestionTile(
              list: list,
              onAccept: () => context.push('/shop/list/${list.id}'),
              onIgnore: () => _ignoreSuggestion(context, ref, list),
            ),
            const SizedBox(height: KsTokens.space8),
          ],
          const SizedBox(height: KsTokens.space12),
        ],
        const _SectionLabel('Upcoming'),
        const SizedBox(height: KsTokens.space10),
        if (upcoming.isEmpty)
          const KsEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No shopping lists yet',
            subtitle: 'Schedule meals or start a Shop Now list to build one.',
          )
        else
          for (final list in upcoming) ...[
            _UpcomingTile(
              shop: _UpcomingShop.fromRecord(list),
              onTap: () => context.push('/shop/list/${list.id}'),
            ),
            const SizedBox(height: KsTokens.space8),
          ],
        const SizedBox(height: KsTokens.space12),
        const _SectionLabel('History'),
        const SizedBox(height: KsTokens.space10),
        if (history.isEmpty)
          const _HistoryRow(label: 'No completed shops yet.')
        else
          for (final list in history.take(3))
            _HistoryRow(label: _historyLabel(list)),
      ],
    );
  }

  Future<void> _ignoreSuggestion(
    BuildContext context,
    WidgetRef ref,
    ShoppingListRecord list,
  ) async {
    try {
      await ref.read(shoppingPlanningControllerProvider).deleteList(list.id);
      ref.invalidate(activeShoppingListsProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_typeLabel(list.type)} ignored')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not ignore list: $error')));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: KsTokens.labelSmall.copyWith(
        color: context.ksColors.textTertiary,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1,
      ),
    );
  }
}

/// The prominent Shop Now banner — a brand-green gradient card inviting the
/// household to buy ahead and shrink future lists.
class _ShopNowCard extends StatelessWidget {
  const _ShopNowCard({required this.onStart, this.locked = false});

  final VoidCallback? onStart;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KsTokens.brandPrimary, KsTokens.brandPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(KsTokens.radius16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop Now'.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: KsTokens.space6),
          Text(
            'Knock out next week early?',
            style: KsTokens.displaySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 21,
              height: 1.1,
            ),
          ),
          const SizedBox(height: KsTokens.space4),
          Text(
            'Buy ahead and future lists shrink as you go.',
            style: KsTokens.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 13),
          _OnBrandButton(
            label: locked ? 'Shopper access required' : 'Start a shop',
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

/// A white pill button reading on the brand gradient.
class _OnBrandButton extends StatelessWidget {
  const _OnBrandButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(KsTokens.radius10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Text(
            label,
            style: KsTokens.labelMedium.copyWith(
              color: KsTokens.brandPrimaryDark,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingShop {
  const _UpcomingShop({
    required this.title,
    required this.when,
    required this.type,
  });

  factory _UpcomingShop.fromRecord(ShoppingListRecord list) {
    return _UpcomingShop(
      title: _typeLabel(list.type),
      when:
          '${_shortDate(list.shoppingDate)} · ${list.items.length} '
          '${list.items.length == 1 ? 'item' : 'items'}',
      type: list.type,
    );
  }

  final String title;
  final String when;
  final ShoppingListType type;
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.shop, required this.onTap});

  final _UpcomingShop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: KsTokens.space12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _typeColor(ks, shop.type).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: _typeColor(ks, shop.type),
                ),
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.title,
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: KsTokens.space2),
                    Text(
                      shop.when,
                      style: KsTokens.labelSmall.copyWith(
                        color: ks.textTertiary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ks.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.list,
    required this.onAccept,
    required this.onIgnore,
  });

  final ShoppingListRecord list;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final accent = _typeColor(ks, list.type);
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          ks.surfaceRaised,
        ),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(KsTokens.radius10),
            ),
            child: Icon(
              list.type == ShoppingListType.emergency
                  ? Icons.warning_amber_rounded
                  : Icons.auto_awesome_rounded,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(list.type),
                  style: KsTokens.titleSmall.copyWith(
                    color: ks.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  '${list.items.length} '
                  '${list.items.length == 1 ? 'item' : 'items'} · '
                  '${_shortDate(list.shoppingDate)}',
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.textTertiary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Accept suggestion',
            onPressed: onAccept,
            icon: const Icon(Icons.check_rounded, size: 18),
          ),
          const SizedBox(width: KsTokens.space4),
          IconButton(
            tooltip: 'Ignore suggestion',
            onPressed: onIgnore,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

String _typeLabel(ShoppingListType type) => switch (type) {
  ShoppingListType.scheduled => 'Scheduled list',
  ShoppingListType.shopNow => 'Shop Now',
  ShoppingListType.suggested => 'Suggested list',
  ShoppingListType.emergency => 'Emergency list',
};

Color _typeColor(KsColors ks, ShoppingListType type) => switch (type) {
  ShoppingListType.emergency => ks.danger,
  ShoppingListType.suggested => ks.warning,
  _ => ks.calShopping,
};

String _historyLabel(ShoppingListRecord list) =>
    '${_shortDate(list.updatedAt)} · ${list.items.length} '
    '${list.items.length == 1 ? 'item' : 'items'} · ${_typeLabel(list.type)}';

String _shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        const Icon(Icons.check_rounded, size: 16, color: KsTokens.fresh),
        const SizedBox(width: KsTokens.space10),
        Expanded(
          child: Text(
            label,
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The Shop Now setup — "how far ahead?" — a bottom sheet that pulls future
/// lists forward; only what you actually buy is paid down.
class _ShopNowSheet extends StatefulWidget {
  const _ShopNowSheet();

  @override
  State<_ShopNowSheet> createState() => _ShopNowSheetState();
}

class _ShopNowSheetState extends State<_ShopNowSheet> {
  static const _options = [
    _AheadOption(label: 'This week only', items: 11, ahead: 0),
    _AheadOption(label: '+ 1 week ahead', items: 20, ahead: 1),
    _AheadOption(label: '+ 2 weeks ahead', items: 28, ahead: 2),
  ];

  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space12,
          KsTokens.space20,
          KsTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: KsTokens.space16),
                decoration: BoxDecoration(
                  color: ks.borderStrong,
                  borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                ),
              ),
            ),
            Text(
              'Shop how far ahead?',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 21,
                height: 1.15,
              ),
            ),
            const SizedBox(height: KsTokens.space6),
            Text(
              'Pull future lists forward — only what you actually buy is paid '
              'down.',
              style: KsTokens.bodySmall.copyWith(
                color: ks.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            for (var i = 0; i < _options.length; i++) ...[
              _AheadTile(
                option: _options[i],
                selected: i == _selected,
                onTap: () => setState(() => _selected = i),
              ),
              if (i != _options.length - 1) const SizedBox(height: 9),
            ],
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_options[_selected].ahead),
              child: Text(
                'Build the list · ${_options[_selected].items} items',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AheadOption {
  const _AheadOption({
    required this.label,
    required this.items,
    required this.ahead,
  });

  final String label;
  final int items;
  final int ahead;
}

class _AheadTile extends StatelessWidget {
  const _AheadTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _AheadOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final fill = selected
        ? Color.alphaBlend(
            ks.brandPrimary.withValues(alpha: 0.14),
            ks.surfaceRaised,
          )
        : ks.surfaceRaised;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(
              color: selected ? ks.brandPrimary : ks.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 16, color: ks.brandPrimary),
                const SizedBox(width: KsTokens.space8),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
              ),
              Text(
                '${option.items} items',
                style: KsTokens.labelMedium.copyWith(
                  color: selected ? ks.brandPrimary : ks.textTertiary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
