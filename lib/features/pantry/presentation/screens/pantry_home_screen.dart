import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/widgets/pantry_item_tile.dart';

/// Screen 05 · Pantry · sectioned home — shelves you can read.
///
/// Category-tinted chrome over the freshness language, with the near-spoilage
/// banner as the load-bearing state: it nudges before food is lost. Wired to
/// the live pantry stream — the new design language over real data.
class PantryHomeScreen extends ConsumerWidget {
  const PantryHomeScreen({super.key});

  String _labelFor(PantrySection section) => switch (section) {
    PantrySection.food => 'Food',
    PantrySection.bulk => 'Bulk',
    PantrySection.nonFood => 'Non-food',
    PantrySection.leftover => 'Leftovers',
  };

  IconData _iconFor(PantrySection section) => switch (section) {
    PantrySection.food => Icons.restaurant_outlined,
    PantrySection.bulk => Icons.inventory_2_outlined,
    PantrySection.nonFood => Icons.cleaning_services_outlined,
    PantrySection.leftover => Icons.lunch_dining_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSection = ref.watch(pantryTabControllerProvider);
    final sectionAsync = ref.watch(pantrySectionStreamProvider);

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
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Waste log',
                  onTap: () => context.push('/pantry/waste'),
                ),
              ],
            ),
          ),
          _SectionSelector(
            sections: PantrySection.values,
            selected: selectedSection,
            onSelect: (s) =>
                ref.read(pantryTabControllerProvider.notifier).select(s),
            labelFor: _labelFor,
            iconFor: _iconFor,
          ),
          Expanded(
            child: sectionAsync.when(
              data: (items) => _ShelfList(
                items: items,
                section: selectedSection,
                emptyTitle:
                    'Your ${_labelFor(selectedSection).toLowerCase()} '
                    'pantry\nis waiting',
                emptyIcon: _iconFor(selectedSection),
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
class _ShelfList extends StatelessWidget {
  const _ShelfList({
    required this.items,
    required this.section,
    required this.emptyTitle,
    required this.emptyIcon,
  });

  final List<PantryItem> items;
  final PantrySection section;
  final String emptyTitle;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: KsEmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                subtitle: 'Tap Add to stock your first item.',
                color: section.color,
              ),
            ),
          ),
          const _AddBar(),
        ],
      );
    }

    final atRisk = items.where((i) {
      final f = FreshnessHelper.fromExpiry(i.expiryDate);
      return f == Freshness.expiringSoon || f == Freshness.expired;
    }).toList();

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
        for (final item in items) ...[
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
class _AddBar extends StatelessWidget {
  const _AddBar();

  @override
  Widget build(BuildContext context) {
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
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.labelFor,
    required this.iconFor,
  });

  final List<PantrySection> sections;
  final PantrySection selected;
  final ValueChanged<PantrySection> onSelect;
  final String Function(PantrySection) labelFor;
  final IconData Function(PantrySection) iconFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KsTokens.space12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KsTokens.space16),
        child: Row(
          children: sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(right: KsTokens.space8),
              child: KsSectionTab(
                label: labelFor(section),
                icon: iconFor(section),
                color: section.color,
                isSelected: section == selected,
                onTap: () => onSelect(section),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
