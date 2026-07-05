import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

/// Screen 12 · Menu Set editor + Apply — build a week, then cast it across the
/// calendar.
///
/// Drag recipes into day slots (presented via [KsMenuSlotEditor]); "Apply to
/// calendar" opens a sheet that casts the set with modulo cycling over a date
/// range, in Replace or Fill-empty mode.
class MenuSetEditorScreen extends ConsumerWidget {
  const MenuSetEditorScreen({super.key});

  void _openApplySheet(BuildContext context, MenuSet menuSet) {
    final ks = context.ksColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ks.scrim,
      builder: (_) => _ApplySheet(menuSet: menuSet),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final menuSets = ref.watch(activeHouseholdMenuSetsProvider).valueOrNull;
    final recipes = ref.watch(activeHouseholdRecipesProvider).valueOrNull;
    final draft = menuSets == null || menuSets.isEmpty ? null : menuSets.first;
    final recipeNames = {
      for (final recipe in recipes ?? const <Recipe>[]) recipe.id: recipe.name,
    };
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
              title: draft?.name ?? 'New menu set',
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space16),
            KsMenuSlotEditor(slots: _slotsFromDraft(draft, recipeNames)),
            const SizedBox(height: KsTokens.space20),
            _RecipeTray(
              recipes: recipes ?? const [],
              onAddFirstRecipe: () async {
                final recipe = recipes == null || recipes.isEmpty
                    ? null
                    : recipes.first;
                if (draft == null || recipe == null) {
                  _showMessage(
                    context,
                    draft == null
                        ? 'Save a menu set draft first.'
                        : 'Add a recipe before editing this menu set.',
                  );
                  return;
                }
                await _runEditorAction(
                  context,
                  () => ref
                      .read(menuSetEditorControllerProvider)
                      .addRecipeToDraft(
                        draft: draft,
                        recipeId: recipe.id,
                        mealSlot: 'Dinner',
                      ),
                  successMessage: 'Added ${recipe.name} to Wednesday.',
                  failureMessage: 'Could not update menu set',
                );
                ref.invalidate(activeHouseholdMenuSetsProvider);
              },
            ),
            const SizedBox(height: KsTokens.space12),
            OutlinedButton.icon(
              onPressed: () async {
                final firstEntry = _firstEntry(draft);
                if (draft == null || firstEntry == null) {
                  _showMessage(context, 'There is no recipe to remove.');
                  return;
                }
                await _runEditorAction(
                  context,
                  () => ref
                      .read(menuSetEditorControllerProvider)
                      .removeEntryFromDraft(
                        draft: draft,
                        entryId: firstEntry.id,
                      ),
                  successMessage: 'Removed recipe from menu set.',
                  failureMessage: 'Could not remove recipe',
                );
                ref.invalidate(activeHouseholdMenuSetsProvider);
              },
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
              label: const Text('Remove first recipe'),
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
                ref.invalidate(activeHouseholdMenuSetsProvider);
              },
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save draft'),
            ),
            const SizedBox(height: KsTokens.space8),
            FilledButton(
              onPressed: draft == null || _firstEntry(draft) == null
                  ? null
                  : () => _openApplySheet(context, draft),
              child: const Text('Apply to calendar'),
            ),
          ],
        ),
      ),
    );
  }

  List<KsMenuSlot> _slotsFromDraft(
    MenuSet? draft,
    Map<String, String> recipeNames,
  ) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (draft == null || draft.days.isEmpty) {
      return [for (final weekday in weekdays) KsMenuSlot(weekday: weekday)];
    }
    return [
      for (final day in draft.days)
        KsMenuSlot(
          weekday: weekdays[day.dayIndex % weekdays.length],
          isDropTarget: day.entries.isEmpty,
          entries: [
            for (final entry in day.entries)
              KsMenuSlotEntry(
                label: recipeNames[entry.recipeId] ?? entry.recipeId,
                color: _entryColor(entry.orderInSlot),
              ),
          ],
        ),
    ];
  }

  Color _entryColor(int index) {
    const colors = [
      KsTokens.catGrain,
      KsTokens.catProduce,
      KsTokens.catMeat,
      KsTokens.catSeafood,
      KsTokens.catSpice,
    ];
    return colors[index % colors.length];
  }

  MenuSetEntry? _firstEntry(MenuSet? draft) {
    if (draft == null) return null;
    for (final day in draft.days) {
      if (day.entries.isNotEmpty) return day.entries.first;
    }
    return null;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
  const _RecipeTray({required this.recipes, required this.onAddFirstRecipe});

  final List<Recipe> recipes;
  final VoidCallback onAddFirstRecipe;

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
              if (recipes.isEmpty)
                Text(
                  'No recipes yet',
                  style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                )
              else
                for (final recipe in recipes.take(6))
                  InkWell(
                    onTap: recipe == recipes.first ? onAddFirstRecipe : null,
                    borderRadius: BorderRadius.circular(KsTokens.radius8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: KsTokens.space8,
                      ),
                      decoration: BoxDecoration(
                        color: KsTokens.catProduce.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(KsTokens.radius8),
                      ),
                      child: Text(
                        recipe.name,
                        style: KsTokens.labelMedium.copyWith(
                          color: KsTokens.catProduce,
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
  const _ApplySheet({required this.menuSet});

  final MenuSet menuSet;

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
  late final DateTime _startDate = _nextMonday(DateTime.now());
  late final DateTime _endDate = _startDate.add(const Duration(days: 27));

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
              Expanded(child: _DateField(_shortDate(_startDate))),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KsTokens.space10,
                ),
                child: Text(
                  'to',
                  style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
                ),
              ),
              Expanded(child: _DateField(_shortDate(_endDate))),
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
              try {
                await ref
                    .read(menuSetApplyPersistenceControllerProvider)
                    .applyPersistedMenuSet(
                      menuSet: widget.menuSet,
                      startDate: _startDate,
                      endDate: _endDate,
                      mode: _mode.domainMode,
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

  DateTime _nextMonday(DateTime date) {
    final today = DateTime(date.year, date.month, date.day);
    final daysUntilMonday = (DateTime.monday - today.weekday) % 7;
    return today.add(Duration(days: daysUntilMonday));
  }

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
