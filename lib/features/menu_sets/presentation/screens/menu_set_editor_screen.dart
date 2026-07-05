import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/presentation/providers/planning_providers.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';

/// Screen 12 · Menu Set editor + Apply — build a week, then cast it across the
/// calendar.
///
/// Drag recipes into day slots (presented via [KsMenuSlotEditor]); "Apply to
/// calendar" opens a sheet that casts the set with modulo cycling over a date
/// range, in Replace or Fill-empty mode.
class MenuSetEditorScreen extends ConsumerWidget {
  const MenuSetEditorScreen({super.key});

  static const _slots = [
    KsMenuSlot(
      weekday: 'Mon',
      entries: [KsMenuSlotEntry(label: 'Lentil dal', color: KsTokens.catGrain)],
    ),
    KsMenuSlot(
      weekday: 'Tue',
      entries: [
        KsMenuSlotEntry(label: 'Roast chicken', color: KsTokens.catMeat),
      ],
    ),
    KsMenuSlot(weekday: 'Wed', isDropTarget: true),
    KsMenuSlot(
      weekday: 'Thu',
      entries: [
        KsMenuSlotEntry(label: 'Salmon traybake', color: KsTokens.catSeafood),
      ],
    ),
    KsMenuSlot(
      weekday: 'Fri',
      entries: [
        KsMenuSlotEntry(label: 'Chilli pasta', color: KsTokens.catSpice),
      ],
    ),
  ];

  void _openApplySheet(BuildContext context) {
    final ks = context.ksColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ks.scrim,
      builder: (_) => const _ApplySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              eyebrow: 'Menu Set · editing',
              title: 'Cosy autumn week',
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space16),
            const KsMenuSlotEditor(slots: _slots),
            const SizedBox(height: KsTokens.space20),
            _RecipeTray(
              onAddOrzo: () async {
                await _runEditorAction(
                  context,
                  () => ref
                      .read(menuSetEditorControllerProvider)
                      .addRecipeToDraft(recipeId: 'orzo', mealSlot: 'Dinner'),
                  successMessage: 'Added Orzo to Wednesday.',
                  failureMessage: 'Could not update menu set',
                );
              },
            ),
            const SizedBox(height: KsTokens.space12),
            OutlinedButton.icon(
              onPressed: () async {
                await _runEditorAction(
                  context,
                  () => ref
                      .read(menuSetEditorControllerProvider)
                      .removeEntryFromDraft(entryId: 'menu-entry-0'),
                  successMessage: 'Removed Lentil dal.',
                  failureMessage: 'Could not remove recipe',
                );
              },
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
              label: const Text('Remove Lentil dal'),
            ),
            const SizedBox(height: KsTokens.space20),
            OutlinedButton.icon(
              onPressed: () async {
                await _runEditorAction(
                  context,
                  () => ref.read(menuSetEditorControllerProvider).saveDraft(),
                  successMessage: 'Menu set saved.',
                  failureMessage: 'Could not save menu set',
                );
              },
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save draft'),
            ),
            const SizedBox(height: KsTokens.space8),
            FilledButton(
              onPressed: () => _openApplySheet(context),
              child: const Text('Apply to calendar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runEditorAction(
    BuildContext context,
    Future<Object?> Function() action, {
    required String successMessage,
    required String failureMessage,
  }) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failureMessage: $error')));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }
}

/// The "drag from your recipes" tray — colour-coded recipe chips to drop into
/// the week above.
class _RecipeTray extends StatelessWidget {
  const _RecipeTray({required this.onAddOrzo});

  final VoidCallback onAddOrzo;

  static const _chips = [
    KsMenuSlotEntry(label: 'Orzo', color: KsTokens.catProduce),
    KsMenuSlotEntry(label: 'Risotto', color: KsTokens.catGrain),
    KsMenuSlotEntry(label: 'Tacos', color: KsTokens.catMeat),
  ];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceSunken,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drag from your recipes'.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: KsTokens.space10),
          Wrap(
            spacing: KsTokens.space8,
            runSpacing: KsTokens.space8,
            children: [
              for (final chip in _chips)
                InkWell(
                  onTap: chip.label == 'Orzo' ? onAddOrzo : null,
                  borderRadius: BorderRadius.circular(KsTokens.radius8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: KsTokens.space8,
                    ),
                    decoration: BoxDecoration(
                      color: chip.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(KsTokens.radius8),
                    ),
                    child: Text(
                      chip.label,
                      style: KsTokens.labelMedium.copyWith(
                        color: chip.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "Apply to the calendar" bottom sheet — a date range, a modulo-cycling
/// note, and a Fill-empty / Replace mode toggle.
class _ApplySheet extends ConsumerStatefulWidget {
  const _ApplySheet();

  @override
  ConsumerState<_ApplySheet> createState() => _ApplySheetState();
}

enum _ApplyMode { fillEmpty, replace }

extension on _ApplyMode {
  MenuSetApplyMode get domainMode {
    return switch (this) {
      _ApplyMode.fillEmpty => MenuSetApplyMode.fillEmpty,
      _ApplyMode.replace => MenuSetApplyMode.replace,
    };
  }
}

class _ApplySheetState extends ConsumerState<_ApplySheet> {
  _ApplyMode _mode = _ApplyMode.fillEmpty;

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
      padding: EdgeInsets.fromLTRB(
        KsTokens.space20,
        KsTokens.space12,
        KsTokens.space20,
        KsTokens.space24 + MediaQuery.viewInsetsOf(context).bottom,
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
          Text(
            'Apply to the calendar',
            style: KsTokens.headlineLarge.copyWith(
              color: ks.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              height: 1.15,
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          const _SheetLabel('Date range'),
          const SizedBox(height: KsTokens.space8),
          Row(
            children: [
              const Expanded(child: _DateField('30 Jun')),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KsTokens.space10,
                ),
                child: Text(
                  'to',
                  style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
                ),
              ),
              const Expanded(child: _DateField('27 Jul')),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            '4 weeks — the 7-day set cycles 4 times (modulo).',
            style: KsTokens.displaySmall.copyWith(
              color: ks.textSecondary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          const _SheetLabel('Mode'),
          const SizedBox(height: KsTokens.space8),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  title: 'Fill empty',
                  subtitle: "Keep what's planned",
                  selected: _mode == _ApplyMode.fillEmpty,
                  onTap: () => setState(() => _mode = _ApplyMode.fillEmpty),
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              Expanded(
                child: _ModeCard(
                  title: 'Replace',
                  subtitle: 'Overwrite the range',
                  selected: _mode == _ApplyMode.replace,
                  onTap: () => setState(() => _mode = _ApplyMode.replace),
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space16),
          FilledButton(
            onPressed: () async {
              final result = ref
                  .read(planningControllerProvider.notifier)
                  .applyFeaturedMenuSet(_mode.domainMode);
              final shoppingList = ref
                  .read(planningControllerProvider)
                  .activeShoppingList;
              try {
                await ref
                    .read(menuSetApplyPersistenceControllerProvider)
                    .persistApplication(
                      result: result,
                      shoppingList: shoppingList,
                    );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not persist menu set: $error')),
                );
                return;
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Apply · 28 meals'),
          ),
        ],
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: KsTokens.labelSmall.copyWith(
        color: context.ksColors.textTertiary,
        fontWeight: FontWeight.w600,
        fontSize: 10,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: ks.surfaceBase,
        borderRadius: BorderRadius.circular(KsTokens.radius10),
        border: Border.all(color: ks.border),
      ),
      child: Text(
        value,
        style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Color.lerp(ks.surfaceRaised, ks.brandPrimary, 0.14)
                : ks.surfaceRaised,
            borderRadius: BorderRadius.circular(KsTokens.radius10),
            border: Border.all(
              color: selected ? ks.brandPrimary : ks.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: KsTokens.labelMedium.copyWith(
                  color: ks.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: KsTokens.bodySmall.copyWith(
                  color: ks.textSecondary,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
