import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/widgets/pantry_item_tile.dart';

/// Screen 05 · Pantry · sectioned home — shelves you can read.
///
/// Category-tinted chrome over the freshness language, with the near-spoilage
/// banner as the load-bearing state: it nudges before food is lost. Wired to
/// the live pantry stream — the new design language over real data.
class PantryHomeScreen extends ConsumerStatefulWidget {
  const PantryHomeScreen({super.key});

  @override
  ConsumerState<PantryHomeScreen> createState() => _PantryHomeScreenState();
}

enum _PantryFilter { all, food, bulk, nonFood, leftover }

class _PantryHomeScreenState extends ConsumerState<PantryHomeScreen> {
  final _searchController = TextEditingController();
  _PantryFilter _filter = _PantryFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PantrySection? _sectionFor(_PantryFilter filter) => switch (filter) {
    _PantryFilter.all => null,
    _PantryFilter.food => PantrySection.food,
    _PantryFilter.bulk => PantrySection.bulk,
    _PantryFilter.nonFood => PantrySection.nonFood,
    _PantryFilter.leftover => PantrySection.leftover,
  };

  String _labelFor(_PantryFilter filter) => switch (filter) {
    _PantryFilter.all => 'All',
    _PantryFilter.food => 'Food',
    _PantryFilter.bulk => 'Bulk',
    _PantryFilter.nonFood => 'Non-food',
    _PantryFilter.leftover => 'Leftovers',
  };

  IconData _iconFor(_PantryFilter filter) => switch (filter) {
    _PantryFilter.all => Icons.shelves,
    _PantryFilter.food => Icons.restaurant_outlined,
    _PantryFilter.bulk => Icons.inventory_2_outlined,
    _PantryFilter.nonFood => Icons.cleaning_services_outlined,
    _PantryFilter.leftover => Icons.lunch_dining_outlined,
  };

  Color _colorFor(BuildContext context, _PantryFilter filter) {
    final section = _sectionFor(filter);
    return section?.color ?? context.ksColors.brandPrimary;
  }

  void _selectFilter(_PantryFilter filter) {
    setState(() => _filter = filter);
    final section = _sectionFor(filter);
    if (section != null) {
      ref.read(pantryTabControllerProvider.notifier).select(section);
    }
  }

  AsyncValue<List<PantryItem>> _itemsForFilter(WidgetRef ref) {
    final section = _sectionFor(_filter);
    if (section == null) {
      return ref.watch(pantryAllItemsStreamProvider);
    }
    ref.watch(pantryTabControllerProvider);
    return ref.watch(pantrySectionStreamProvider);
  }

  String _emptyTitle() => switch (_filter) {
    _PantryFilter.all => 'Your pantry\nis waiting',
    _PantryFilter.leftover => 'Your leftovers shelf\nis waiting',
    _ => 'Your ${_labelFor(_filter).toLowerCase()} pantry\nis waiting',
  };

  @override
  Widget build(BuildContext context) {
    final sectionAsync = _itemsForFilter(ref);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KsTokens.space16,
              KsTokens.space8,
              KsTokens.space16,
              0,
            ),
            child: KsFolioHeader(
              eyebrow: 'The Pantry',
              title: 'On the shelves',
              actions: [
                KsHeaderAction(
                  icon: Icons.insights_outlined,
                  tooltip: 'Pantry insights',
                  onTap: () => context.push('/insights'),
                ),
                KsHeaderAction(
                  icon: Icons.add_shopping_cart_outlined,
                  tooltip: 'Bulk foods to purchase',
                  onTap: () => context.push('/pantry/bulk-purchases'),
                ),
                KsHeaderAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Waste log',
                  onTap: () => context.push('/pantry/waste'),
                ),
              ],
            ),
          ),
          _SectionSelector(
            filters: const [
              _PantryFilter.all,
              _PantryFilter.food,
              _PantryFilter.bulk,
              _PantryFilter.nonFood,
            ],
            selected: _filter,
            onSelect: _selectFilter,
            labelFor: _labelFor,
            iconFor: _iconFor,
            colorFor: (filter) => _colorFor(context, filter),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KsTokens.space16,
              0,
              KsTokens.space16,
              KsTokens.space8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: KsSearchField(
                    controller: _searchController,
                    hintText: 'Search Pantry',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: KsTokens.space8),
                _PantryFilterButton(
                  selected: _filter,
                  onSelected: _selectFilter,
                ),
              ],
            ),
          ),
          Expanded(
            child: sectionAsync.when(
              data: (items) => _ShelfList(
                items: items,
                filter: _filter,
                query: _query,
                emptyTitle: _emptyTitle(),
                emptyIcon: _iconFor(_filter),
                emptyColor: _colorFor(context, _filter),
              ),
              loading: () => const _PantrySkeleton(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(KsTokens.space16),
                child: KsErrorAlert(
                  message: 'Could not load the pantry: $error',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrollable shelf: the near-spoilage banner, the freshness rows, and the
/// add affordance.
class _ShelfList extends ConsumerWidget {
  const _ShelfList({
    required this.items,
    required this.filter,
    required this.query,
    required this.emptyTitle,
    required this.emptyIcon,
    required this.emptyColor,
  });

  final List<PantryItem> items;
  final _PantryFilter filter;
  final String query;
  final String emptyTitle;
  final IconData emptyIcon;
  final Color emptyColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = _searchItems(ref, items, query);
    final hasSearch = query.trim().isNotEmpty;

    if (filtered.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: KsEmptyState(
                icon: emptyIcon,
                title: hasSearch ? 'No pantry matches' : emptyTitle,
                subtitle: hasSearch
                    ? 'Try a different item name or clear the search.'
                    : 'Tap Add to stock your first item.',
                color: emptyColor,
              ),
            ),
          ),
          const _AddBar(),
        ],
      );
    }

    final atRisk = filtered.where((i) {
      final f = FreshnessHelper.fromExpiry(i.expiryDate);
      return f == Freshness.expiringSoon || f == Freshness.expired;
    }).toList();
    final groupedFood = filter == _PantryFilter.food
        ? _groupFoodByCategory(ref, filtered)
        : const <IngredientCategory, List<PantryItem>>{};

    DateTime? soonest;
    for (final i in atRisk) {
      final e = i.expiryDate;
      if (e == null) continue;
      if (soonest == null || e.isBefore(soonest)) soonest = e;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space12,
        KsTokens.space16,
        KsTokens.space24,
      ),
      children: [
        if (atRisk.isNotEmpty) ...[
          _SpoilageBanner(
            count: atRisk.length,
            soonestLabel: FreshnessHelper.relativeLabel(soonest),
          ),
          const SizedBox(height: KsTokens.space16),
        ],
        if (filter == _PantryFilter.leftover) ...[
          const _FilterContextBanner(
            icon: Icons.lunch_dining_outlined,
            label: 'Leftovers',
            text: 'Leftovers are visible through the funnel filter.',
          ),
          const SizedBox(height: KsTokens.space16),
        ],
        if (groupedFood.isNotEmpty)
          for (final entry in groupedFood.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: KsTokens.space8),
              child: Text(
                entry.key.name.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: context.ksColors.textTertiary,
                  letterSpacing: .8,
                ),
              ),
            ),
            for (final item in entry.value) ...[
              PantryItemTile(
                key: ValueKey(item.id),
                item: item,
                onTap: () => context.push('/pantry/${item.id}'),
              ),
              const SizedBox(height: KsTokens.space8),
            ],
            const SizedBox(height: KsTokens.space4),
          ]
        else
          for (final item in filtered) ...[
            PantryItemTile(
              key: ValueKey(item.id),
              item: item,
              onTap: () => context.push('/pantry/${item.id}'),
            ),
            const SizedBox(height: KsTokens.space8),
          ],
        const SizedBox(height: KsTokens.space4),
        const _AddBar(),
      ],
    );
  }

  List<PantryItem> _searchItems(
    WidgetRef ref,
    List<PantryItem> items,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return items;

    return items
        .where((item) {
          final ingredient = _ingredientFor(ref, item.ingredientId);
          final haystack = [
            item.ingredientId,
            if (ingredient != null) ...[
              ingredient.name,
              ...ingredient.displayNames.values,
              ...ingredient.aliases,
              ...ingredient.searchTokens,
            ],
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  Ingredient? _ingredientFor(WidgetRef ref, String ingredientId) {
    final async = ref.watch(pantryIngredientProvider(ingredientId));
    return async.when(
      data: (result) => switch (result) {
        Success(:final value) => value,
        ResultFailure() => null,
      },
      loading: () => null,
      error: (_, __) => null,
    );
  }

  Map<IngredientCategory, List<PantryItem>> _groupFoodByCategory(
    WidgetRef ref,
    List<PantryItem> items,
  ) {
    final grouped = <IngredientCategory, List<PantryItem>>{};
    for (final item in items) {
      final category =
          _ingredientFor(ref, item.ingredientId)?.category ??
          IngredientCategory.other;
      grouped.putIfAbsent(category, () => []).add(item);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.name.compareTo(b.key.name)),
    );
  }
}

class _FilterContextBanner extends StatelessWidget {
  const _FilterContextBanner({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ks.brandPrimary),
          const SizedBox(width: KsTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  text,
                  style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The load-bearing nudge — a warm warning band that surfaces before food is
/// lost.
class _SpoilageBanner extends StatelessWidget {
  const _SpoilageBanner({required this.count, required this.soonestLabel});

  final int count;
  final String soonestLabel;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final noun = count == 1 ? 'thing needs' : 'things need';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Color.lerp(ks.surfaceRaised, ks.warning, 0.10),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: Color.lerp(ks.border, ks.warning, 0.35)!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: ks.warning),
          const SizedBox(width: KsTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count $noun eating this week',
                  style: KsTokens.titleSmall.copyWith(
                    color: ks.textPrimary,
                    fontSize: 13,
                  ),
                ),
                if (soonestLabel.isNotEmpty) ...[
                  const SizedBox(height: KsTokens.space2),
                  Text(
                    'soonest: ${soonestLabel.toLowerCase()}',
                    style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 27 · the pantry shelf, loading. A skeleton that mirrors the real
/// shelf rows — left freshness bar, a title + meta line, a trailing badge — so
/// nothing jumps when the live stream lands. Replaces a bare spinner.
class _PantrySkeleton extends StatelessWidget {
  const _PantrySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space12,
        KsTokens.space16,
        KsTokens.space24,
      ),
      children: const [
        _SkeletonRow(titleWidth: 0.62, metaWidth: 0.42),
        SizedBox(height: KsTokens.space8),
        _SkeletonRow(titleWidth: 0.48, metaWidth: 0.55),
        SizedBox(height: KsTokens.space8),
        _SkeletonRow(titleWidth: 0.70, metaWidth: 0.38),
        SizedBox(height: KsTokens.space8),
        _SkeletonRow(titleWidth: 0.54, metaWidth: 0.46),
        SizedBox(height: KsTokens.space8),
        _SkeletonRow(titleWidth: 0.60, metaWidth: 0.40),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.titleWidth, required this.metaWidth});

  /// Title / meta line widths as a fraction of the available row width — the
  /// gentle raggedness that makes a skeleton read as content, not a grid.
  final double titleWidth;
  final double metaWidth;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        children: [
          const KsSkeleton(width: 4, height: 34, radius: 2),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  KsSkeleton.line(width: constraints.maxWidth * titleWidth),
                  const SizedBox(height: KsTokens.space8),
                  KsSkeleton.line(
                    width: constraints.maxWidth * metaWidth,
                    height: 10,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KsTokens.space12),
          const KsSkeleton(width: 52, height: 24, radius: KsTokens.radiusFull),
        ],
      ),
    );
  }
}

/// The "Add" pill — the section home's primary write action.
class _AddBar extends ConsumerWidget {
  const _AddBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(activeHouseholdContextProvider);
    final canAdd =
        household != null &&
        const HouseholdPolicy().roleCan(
          household.role,
          HouseholdCapability.addPantryItems,
          isSoloHousehold: household.isSolo,
        );
    if (!canAdd) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KsTokens.space16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/pantry/add'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add'),
        ),
      ),
    );
  }
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({
    required this.filters,
    required this.selected,
    required this.onSelect,
    required this.labelFor,
    required this.iconFor,
    required this.colorFor,
  });

  final List<_PantryFilter> filters;
  final _PantryFilter selected;
  final ValueChanged<_PantryFilter> onSelect;
  final String Function(_PantryFilter) labelFor;
  final IconData Function(_PantryFilter) iconFor;
  final Color Function(_PantryFilter) colorFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KsTokens.space12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KsTokens.space16),
        child: Row(
          children: filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: KsTokens.space8),
              child: KsSectionTab(
                label: labelFor(filter),
                icon: iconFor(filter),
                color: colorFor(filter),
                isSelected: filter == selected,
                onTap: () => onSelect(filter),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PantryFilterButton extends StatelessWidget {
  const _PantryFilterButton({required this.selected, required this.onSelected});

  final _PantryFilter selected;
  final ValueChanged<_PantryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isActive = selected == _PantryFilter.leftover;
    return PopupMenuButton<_PantryFilter>(
      tooltip: 'Filter pantry',
      onSelected: onSelected,
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: _PantryFilter.leftover,
          checked: isActive,
          child: const Text('Leftovers'),
        ),
      ],
      child: Semantics(
        button: true,
        label: isActive ? 'Filter pantry, Leftovers active' : 'Filter pantry',
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isActive ? ks.brandPrimary : ks.surfaceRaised,
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(
              color: isActive ? ks.brandPrimary : ks.borderStrong,
            ),
          ),
          child: Icon(
            Icons.filter_list_rounded,
            color: isActive ? KsTokens.textOnBrand : ks.textPrimary,
          ),
        ),
      ),
    );
  }
}
