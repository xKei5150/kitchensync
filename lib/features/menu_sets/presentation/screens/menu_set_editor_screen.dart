import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
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
class MenuSetEditorScreen extends ConsumerStatefulWidget {
  const MenuSetEditorScreen({this.menuSetId, super.key});

  final String? menuSetId;

  @override
  ConsumerState<MenuSetEditorScreen> createState() =>
      _MenuSetEditorScreenState();
}

class _MenuSetEditorScreenState extends ConsumerState<MenuSetEditorScreen> {
  final _nameController = TextEditingController(text: 'New menu set');
  final _lengthController = TextEditingController(text: '7');
  late String? _draftId = widget.menuSetId;

  @override
  void dispose() {
    _nameController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  void _openApplySheet(BuildContext context, MenuSet menuSet) {
    final ks = context.ksColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ks.scrim,
      builder: (_) => MenuSetApplySheet(menuSet: menuSet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final menuSets = ref.watch(activeHouseholdMenuSetsProvider).valueOrNull;
    final recipes = ref.watch(activeHouseholdRecipesProvider).valueOrNull;
    final draft = _selectedDraft(menuSets, _draftId);
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
            if (draft == null) ...[
              TextField(
                key: const Key('menu-set-name-field'),
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Menu set name'),
              ),
              const SizedBox(height: KsTokens.space12),
              TextField(
                key: const Key('menu-set-length-field'),
                controller: _lengthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Length in days',
                  helperText: 'Choose 1 to 365 days.',
                ),
              ),
              const SizedBox(height: KsTokens.space16),
            ],
            KsMenuSlotEditor(slots: _slotsFromDraft(draft, recipeNames)),
            if (draft != null) ...[
              const SizedBox(height: KsTokens.space20),
              _DayControls(
                draft: draft,
                recipeNames: recipeNames,
                onDuplicate: (dayIndex) =>
                    _duplicateDay(context, draft, dayIndex),
                onClear: (dayIndex) => _clearDay(context, draft, dayIndex),
                onRename: (dayIndex, label) =>
                    _renameDay(context, draft, dayIndex, label),
                onMoveEntry: (dayId, entryId, target) =>
                    _moveEntry(context, draft, dayId, entryId, target),
              ),
            ],
            const SizedBox(height: KsTokens.space20),
            _RecipeTray(
              recipes: recipes ?? const [],
              onAddRecipe: (recipe) async {
                if (draft == null) {
                  _showMessage(context, 'Save a menu set draft first.');
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
                        dayIndex: 0,
                      ),
                  successMessage: 'Added ${recipe.name} to Day 1 dinner.',
                  failureMessage: 'Could not update menu set',
                );
                ref.invalidate(activeHouseholdMenuSetsProvider);
              },
            ),
            const SizedBox(height: KsTokens.space20),
            OutlinedButton.icon(
              onPressed: () => _saveDraft(context, draft),
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

  Future<void> _saveDraft(BuildContext context, MenuSet? draft) async {
    if (draft != null) {
      await _runEditorAction(
        context,
        () => ref.read(menuSetRepositoryProvider).upsert(draft),
        successMessage: 'Menu set saved.',
        failureMessage: 'Could not save menu set',
      );
      return;
    }
    final lengthInDays = int.tryParse(_lengthController.text.trim());
    if (lengthInDays == null) {
      _showMessage(context, 'Enter a whole number of days.');
      return;
    }
    MenuSet? saved;
    await _runEditorAction(
      context,
      () async => saved = await ref
          .read(menuSetEditorControllerProvider)
          .saveDraft(name: _nameController.text, lengthInDays: lengthInDays),
      successMessage: 'Menu set saved.',
      failureMessage: 'Could not save menu set',
    );
    if (!mounted || saved == null) return;
    setState(() => _draftId = saved!.id);
    ref.invalidate(activeHouseholdMenuSetsProvider);
  }

  Future<void> _duplicateDay(
    BuildContext context,
    MenuSet draft,
    int dayIndex,
  ) async {
    await _runEditorAction(
      context,
      () =>
          ref
              .read(menuSetEditorControllerProvider)
              .duplicateDay(draft: draft, dayIndex: dayIndex),
      successMessage: 'Duplicated Day ${dayIndex + 1}.',
      failureMessage: 'Could not duplicate day',
    );
    ref.invalidate(activeHouseholdMenuSetsProvider);
  }

  Future<void> _clearDay(
    BuildContext context,
    MenuSet draft,
    int dayIndex,
  ) async {
    await _runEditorAction(
      context,
      () =>
          ref
              .read(menuSetEditorControllerProvider)
              .clearDay(draft: draft, dayIndex: dayIndex),
      successMessage: 'Cleared Day ${dayIndex + 1}.',
      failureMessage: 'Could not clear day',
    );
    ref.invalidate(activeHouseholdMenuSetsProvider);
  }

  Future<void> _renameDay(
    BuildContext context,
    MenuSet draft,
    int dayIndex,
    String label,
  ) async {
    await _runEditorAction(
      context,
      () => ref
          .read(menuSetEditorControllerProvider)
          .renameDay(draft: draft, dayIndex: dayIndex, label: label),
      successMessage: 'Renamed Day ${dayIndex + 1}.',
      failureMessage: 'Could not rename day',
    );
    ref.invalidate(activeHouseholdMenuSetsProvider);
  }

  Future<void> _moveEntry(
    BuildContext context,
    MenuSet draft,
    String sourceDayId,
    String entryId,
    ({int dayIndex, String mealSlot}) target,
  ) async {
    await _runEditorAction(
      context,
      () => ref.read(menuSetEditorControllerProvider).moveEntry(
        draft: draft,
        sourceDayId: sourceDayId,
        entryId: entryId,
        targetDayIndex: target.dayIndex,
        targetMealSlot: target.mealSlot,
        targetOrder: 0,
      ),
      successMessage: 'Moved recipe to Day ${target.dayIndex + 1}.',
      failureMessage: 'Could not move recipe',
    );
    ref.invalidate(activeHouseholdMenuSetsProvider);
  }

  MenuSet? _selectedDraft(List<MenuSet>? menuSets, String? menuSetId) {
    if (menuSetId == null || menuSets == null) return null;
    for (final menuSet in menuSets) {
      if (menuSet.id == menuSetId) return menuSet;
    }
    return null;
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

/// The recipe tray — colour-coded recipe chips. Tapping a chip adds that recipe
/// to Day 1's dinner slot; per-day controls above move, clear, or rename days.
class _RecipeTray extends StatelessWidget {
  const _RecipeTray({required this.recipes, required this.onAddRecipe});

  final List<Recipe> recipes;
  final ValueChanged<Recipe> onAddRecipe;

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
            'Tap a recipe to add to Day 1'.toUpperCase(),
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
                    onTap: () => onAddRecipe(recipe),
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

/// Per-day structural controls for a saved Menu Set draft: rename, duplicate,
/// clear, and move the first recipe of a day to the next day. These expose the
/// spec 6.5 editing capabilities (add/remove already live in the recipe tray).
class _DayControls extends StatelessWidget {
  const _DayControls({
    required this.draft,
    required this.recipeNames,
    required this.onDuplicate,
    required this.onClear,
    required this.onRename,
    required this.onMoveEntry,
  });

  final MenuSet draft;
  final Map<String, String> recipeNames;
  final void Function(int dayIndex) onDuplicate;
  final void Function(int dayIndex) onClear;
  final void Function(int dayIndex, String label) onRename;
  final void Function(
    String sourceDayId,
    String entryId,
    ({int dayIndex, String mealSlot}) target,
  )
  onMoveEntry;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      key: const Key('menu-set-day-controls'),
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
            'Edit days'.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: KsTokens.space10),
          for (final day in draft.days)
            Padding(
              padding: const EdgeInsets.only(bottom: KsTokens.space8),
              child: _DayControlRow(
                day: day,
                dayCount: draft.days.length,
                recipeNames: recipeNames,
                onDuplicate: () => onDuplicate(day.dayIndex),
                onClear: () => onClear(day.dayIndex),
                onRename: (label) => onRename(day.dayIndex, label),
                onMoveFirstEntry: () {
                  if (day.entries.isEmpty) return;
                  final nextIndex = _nextDayIndex(day.dayIndex);
                  if (nextIndex == null) return;
                  onMoveEntry(day.id, day.entries.first.id, (
                    dayIndex: nextIndex,
                    mealSlot: day.entries.first.mealSlot,
                  ));
                },
              ),
            ),
        ],
      ),
    );
  }

  int? _nextDayIndex(int currentIndex) {
    final indices = draft.days.map((day) => day.dayIndex).toList()..sort();
    for (final index in indices) {
      if (index > currentIndex) return index;
    }
    return null;
  }
}

class _DayControlRow extends StatelessWidget {
  const _DayControlRow({
    required this.day,
    required this.dayCount,
    required this.recipeNames,
    required this.onDuplicate,
    required this.onClear,
    required this.onRename,
    required this.onMoveFirstEntry,
  });

  final MenuSetDay day;
  final int dayCount;
  final Map<String, String> recipeNames;
  final VoidCallback onDuplicate;
  final VoidCallback onClear;
  final void Function(String label) onRename;
  final VoidCallback onMoveFirstEntry;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final title = day.label ?? 'Day ${day.dayIndex + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space10,
        vertical: KsTokens.space8,
      ),
      decoration: BoxDecoration(
        color: ks.surfaceBase,
        borderRadius: BorderRadius.circular(KsTokens.radius8),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
                if (day.entries.isNotEmpty)
                  Text(
                    day.entries
                        .map(
                          (entry) =>
                              recipeNames[entry.recipeId] ?? entry.recipeId,
                        )
                        .join(', '),
                    style: KsTokens.bodySmall.copyWith(
                      color: ks.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: Key('menu-set-rename-day-${day.dayIndex}'),
            tooltip: 'Rename day',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _promptRename(context, title),
          ),
          if (day.entries.isNotEmpty)
            IconButton(
              key: Key('menu-set-move-day-${day.dayIndex}'),
              tooltip: 'Move first recipe to next day',
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              onPressed: onMoveFirstEntry,
            ),
          IconButton(
            key: Key('menu-set-duplicate-day-${day.dayIndex}'),
            tooltip: 'Duplicate day',
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            onPressed: onDuplicate,
          ),
          IconButton(
            key: Key('menu-set-clear-day-${day.dayIndex}'),
            tooltip: 'Clear day',
            icon: const Icon(Icons.clear_all_rounded, size: 18),
            onPressed: day.entries.isEmpty ? null : onClear,
          ),
        ],
      ),
    );
  }

  Future<void> _promptRename(BuildContext context, String current) async {
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameDayDialog(initialLabel: current),
    );
    if (label != null && label.isNotEmpty) onRename(label);
  }
}

class _RenameDayDialog extends StatefulWidget {
  const _RenameDayDialog({required this.initialLabel});

  final String initialLabel;

  @override
  State<_RenameDayDialog> createState() => _RenameDayDialogState();
}

class _RenameDayDialogState extends State<_RenameDayDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialLabel,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename day'),
      content: TextField(
        key: const Key('menu-set-rename-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Day label'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// The "Apply to the calendar" bottom sheet — a date range, a modulo-cycling
/// note, and a Fill-empty / Replace mode toggle.
class MenuSetApplySheet extends ConsumerStatefulWidget {
  const MenuSetApplySheet({required this.menuSet, super.key});

  final MenuSet menuSet;

  @override
  ConsumerState<MenuSetApplySheet> createState() => _ApplySheetState();
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

class _ApplySheetState extends ConsumerState<MenuSetApplySheet> {
  _ApplyMode _mode = _ApplyMode.fillEmpty;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _startDate = _nextMonday(ref.read(clockProvider).now());
    _endDate = _startDate.add(const Duration(days: 27));
  }

  int get _dayCount => _endDate.difference(_startDate).inDays + 1;

  int get _mealCount {
    var count = 0;
    for (var offset = 0; offset < _dayCount; offset++) {
      count +=
          widget.menuSet
              .dayAt(offset % widget.menuSet.lengthInDays)
              ?.entries
              .length ??
          0;
    }
    return count;
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (range == null || !mounted) return;
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  Future<void> _apply() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);
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
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not persist menu set: $error')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

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
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                  Expanded(
                    child: _DateField(
                      key: const Key('menu-set-date-range-start'),
                      value: _shortDate(_startDate),
                      onTap: _pickDateRange,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KsTokens.space10,
                    ),
                    child: Text(
                      'to',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _DateField(
                      key: const Key('menu-set-date-range-end'),
                      value: _shortDate(_endDate),
                      onTap: _pickDateRange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space8),
              Text(
                '$_dayCount days - the ${widget.menuSet.lengthInDays}-day set '
                'cycles across the selected range.',
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
                onPressed: _isApplying ? null : _apply,
                child: Text(
                  _isApplying ? 'Applying...' : 'Apply · $_mealCount meals',
                ),
              ),
            ],
          ),
        ),
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
  const _DateField({required this.value, required this.onTap, super.key});

  final String value;
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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: ks.surfaceBase,
            borderRadius: BorderRadius.circular(KsTokens.radius10),
            border: Border.all(color: ks.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
              ),
              Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: ks.textSecondary,
              ),
            ],
          ),
        ),
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
