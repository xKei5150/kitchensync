import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_set_editor_screen.dart';

/// Screen 11 · Menu Sets home — a deck of weeks you can re-live.
///
/// A horizontal carousel, deliberately unlike every vertical list in the app:
/// each [KsMenuSetCard] previews its seven days. Premium P2 backed by the menu
/// set repository.
class MenuSetsScreen extends ConsumerStatefulWidget {
  const MenuSetsScreen({super.key});

  @override
  ConsumerState<MenuSetsScreen> createState() => _MenuSetsScreenState();
}

class _MenuSetsScreenState extends ConsumerState<MenuSetsScreen> {
  // viewportFraction keeps the next card peeking, so the row reads as a deck.
  final _controller = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createFromPastCalendar(bool allowed) async {
    if (!allowed) return _showAccessRequired();
    final created = await showModalBottomSheet<MenuSet>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.ksColors.scrim,
      builder: (_) => const _PastCalendarSheet(),
    );
    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created “${created.name}” — review and edit any day.',
        ),
      ),
    );
    ref.invalidate(activeHouseholdMenuSetsProvider);
    if (GoRouter.maybeOf(context) != null) {
      await context.pushNamed(
        'menuSetEditor',
        queryParameters: {'menuSetId': created.id},
      );
    }
  }

  Future<void> _apply(MenuSet set, bool allowed) async {
    if (!allowed) return _showAccessRequired();
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.ksColors.scrim,
      builder: (_) => MenuSetApplySheet(menuSet: set),
    );
    if (!mounted || applied != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied ${set.name} to the calendar.')),
    );
  }

  Future<void> _duplicate(MenuSet set, bool allowed) async {
    if (!allowed) return _showAccessRequired();
    final now = DateTime.now();
    final duplicate = const MenuSetDraftFactory().duplicate(
      source: set,
      suffix: now.microsecondsSinceEpoch,
      createdByUserId: ref.read(activeUserIdProvider),
      now: now,
    );
    await ref.read(menuSetRepositoryProvider).upsert(duplicate);
  }

  Future<void> _delete(MenuSet set, bool allowed) async {
    if (!allowed) return _showAccessRequired();
    await ref
        .read(menuSetRepositoryProvider)
        .delete(householdId: set.householdId, menuSetId: set.id);
  }

  void _showAccessRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menu set access requires a cook role.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final currency = ref.watch(localeFormattersProvider).currency;
    final sets = ref.watch(activeHouseholdMenuSetsProvider);
    final household = ref.watch(activeHouseholdContextProvider);
    final canCreate = _can(
      household,
      HouseholdCapability.createMenuSetsFromPastCalendar,
    );
    final canApply = _can(household, HouseholdCapability.applyMenuSets);
    final canEdit = _can(household, HouseholdCapability.editMenuSets);
    final canDelete = _can(household, HouseholdCapability.deleteMenuSets);
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space16,
                KsTokens.space8,
                KsTokens.space16,
                0,
              ),
              child: KsFolioHeader(
                eyebrow: 'Premium · Menu Sets',
                title: 'A deck of weeks',
                actions: [
                  KsHeaderAction(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/calendar');
                      }
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, KsTokens.space12, 20, 0),
              child: _Subhead('Reuse a week you loved.'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space16,
                KsTokens.space12,
                KsTokens.space16,
                0,
              ),
              child: OutlinedButton.icon(
                onPressed: canEdit
                    ? () => context.push('/menu-sets/edit')
                    : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Menu Set'),
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            Expanded(
              child: sets.when(
                data: (menuSets) {
                  if (menuSets.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(KsTokens.space16),
                        child: KsEmptyState(
                          icon: Icons.style_outlined,
                          title: 'No saved menu sets',
                          subtitle: 'Save a calendar week to reuse it later.',
                        ),
                      ),
                    );
                  }
                  final activePage = _page.clamp(0, menuSets.length - 1);
                  if (activePage != _page) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _page = activePage);
                    });
                  }
                  return PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: menuSets.length,
                    itemBuilder: (context, i) {
                      final set = menuSets[i];
                      final mealCount = set.days.fold<int>(
                        0,
                        (sum, day) => sum + day.entries.length,
                      );
                      final meta =
                          '${set.lengthInDays} days · $mealCount meals · '
                          '${currency.format(mealCount * 4, decimals: false)}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: KsMenuSetCard(
                            title: set.name,
                            meta: meta,
                            days: _previewDays(set),
                            onApply: canApply ? () => _apply(set, true) : null,
                            onDuplicate: canEdit
                                ? () => _duplicate(set, true)
                                : null,
                            onEdit: canEdit
                                ? () => context.pushNamed(
                                    'menuSetEditor',
                                    queryParameters: {'menuSetId': set.id},
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(KsTokens.space16),
                  child: Center(
                    child: KsErrorAlert(
                      message: 'Could not load menu sets: $error',
                    ),
                  ),
                ),
              ),
            ),
            sets.maybeWhen(
              data: (menuSets) => menuSets.isEmpty
                  ? const SizedBox.shrink()
                  : _PageDots(count: menuSets.length, active: _page),
              orElse: () => const SizedBox.shrink(),
            ),
            sets.maybeWhen(
              data: (menuSets) => menuSets.isEmpty
                  ? const SizedBox.shrink()
                  : _DeleteButton(
                      enabled: canDelete,
                      onTap: () {
                        final set =
                            menuSets[_page.clamp(0, menuSets.length - 1)];
                        _delete(set, true);
                      },
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space16,
                KsTokens.space8,
                KsTokens.space16,
                KsTokens.space20,
              ),
              child: _SaveAsSetButton(
                enabled: canCreate,
                onTap: () => _createFromPastCalendar(canCreate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _can(ActiveHouseholdContext? household, HouseholdCapability capability) {
    if (household == null) return false;
    const policy = HouseholdPolicy();
    return policy.canUsePremiumCapability(
          householdHasPremium: household.hasPremium,
          capability: capability,
        ) &&
        policy.roleCan(
          household.role,
          capability,
          isSoloHousehold: household.isSolo,
        );
  }
}


class _Subhead extends StatelessWidget {
  const _Subhead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: KsTokens.displaySmall.copyWith(
        color: context.ksColors.textSecondary,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        height: 1.3,
      ),
    );
  }
}

/// The carousel pager — a stretched pill for the active page, dots otherwise.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: KsTokens.durationFast,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == active ? ks.brandPrimary : ks.borderStrong,
              borderRadius: BorderRadius.circular(KsTokens.radiusFull),
            ),
          ),
      ],
    );
  }
}

/// The dashed "Save this week as a set" call to action.
class _SaveAsSetButton extends StatelessWidget {
  const _SaveAsSetButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return KsDashedBorder(
      color: ks.borderStrong,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: ks.textSecondary),
                const SizedBox(width: KsTokens.space8),
                Text(
                  enabled ? 'Save this week as a set' : 'Premium cook required',
                  style: KsTokens.labelLarge.copyWith(
                    color: ks.textSecondary,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space8,
        KsTokens.space16,
        0,
      ),
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: const Icon(Icons.delete_outline_rounded, size: 16),
        label: const Text('Delete selected set'),
      ),
    );
  }
}

enum _PastRangePreset { lastWeek, thisMonth, custom }

/// Spec 6.4.2 — "Create from Past Calendar": pick a preset or manual range,
/// name the set, review the normalized day/meal structure, then save and open
/// the editor to edit any day before committing further changes.
class _PastCalendarSheet extends ConsumerStatefulWidget {
  const _PastCalendarSheet();

  @override
  ConsumerState<_PastCalendarSheet> createState() => _PastCalendarSheetState();
}

class _PastCalendarSheetState extends ConsumerState<_PastCalendarSheet> {
  final _nameController = TextEditingController(text: 'Last week');
  _PastRangePreset _preset = _PastRangePreset.lastWeek;
  late DateTime _start;
  late DateTime _end;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _applyPreset(_PastRangePreset.lastWeek);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  DateTime _yesterday() {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
  }

  void _applyPreset(_PastRangePreset preset) {
    final end = _yesterday();
    setState(() {
      _preset = preset;
      switch (preset) {
        case _PastRangePreset.lastWeek:
          _end = end;
          _start = end.subtract(const Duration(days: 6));
        case _PastRangePreset.thisMonth:
          _end = end;
          _start = DateTime(end.year, end.month);
        case _PastRangePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = ref.read(clockProvider).now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (range == null || !mounted) return;
    setState(() {
      _preset = _PastRangePreset.custom;
      _start = DateTime(range.start.year, range.start.month, range.start.day);
      _end = DateTime(range.end.year, range.end.month, range.end.day);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name for the menu set.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    MenuSet? created;
    try {
      created = await ref
          .read(menuSetEditorControllerProvider)
          .createFromPastCalendar(
            startDate: _start,
            endDate: _end,
            name: name,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create menu set: $error')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final mealsAsync = ref.watch(
      activeCalendarMealsProvider((start: _start, end: _end)),
    );
    final dayCount = _end.difference(_start).inDays + 1;
    return Container(
      key: const Key('past-calendar-sheet'),
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
                'Create from past calendar',
                style: KsTokens.headlineLarge.copyWith(
                  color: ks.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: KsTokens.space16),
              Wrap(
                spacing: KsTokens.space8,
                children: [
                  _PresetChip(
                    label: 'Last week',
                    selected: _preset == _PastRangePreset.lastWeek,
                    onTap: () => _applyPreset(_PastRangePreset.lastWeek),
                  ),
                  _PresetChip(
                    label: 'This month',
                    selected: _preset == _PastRangePreset.thisMonth,
                    onTap: () => _applyPreset(_PastRangePreset.thisMonth),
                  ),
                  _PresetChip(
                    label: 'Custom range',
                    selected: _preset == _PastRangePreset.custom,
                    onTap: _pickCustomRange,
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space8),
              Text(
                '${_shortDate(_start)} – ${_shortDate(_end)} · $dayCount days',
                style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
              ),
              const SizedBox(height: KsTokens.space16),
              TextField(
                key: const Key('past-calendar-name-field'),
                controller: _nameController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Menu set name'),
              ),
              const SizedBox(height: KsTokens.space8),
              _ReviewPanel(mealsAsync: mealsAsync, dayCount: dayCount),
              const SizedBox(height: KsTokens.space16),
              FilledButton(
                key: const Key('past-calendar-save'),
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Saving…' : 'Save & review'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.mealsAsync, required this.dayCount});

  final AsyncValue<List<MealScheduleEntry>> mealsAsync;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      key: const Key('past-calendar-review'),
      width: double.infinity,
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceSunken,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: mealsAsync.when(
        loading: () => const Text('Analyzing your calendar…'),
        error: (error, _) => Text('Could not read calendar: $error'),
        data: (meals) {
          final active = meals
              .where((m) => m.state != ScheduledMealState.cancelled)
              .toList();
          if (active.isEmpty) {
            return Text(
              'No meals in this range yet — pick a range you actually cooked.',
              style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
            );
          }
          final days = <DateTime>{
            for (final m in active)
              DateTime(m.date.year, m.date.month, m.date.day),
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review',
                style: KsTokens.labelSmall.copyWith(
                  color: ks.textTertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: KsTokens.space8),
              Text(
                '$dayCount-day template · ${active.length} meals across '
                '${days.length} planned days',
                style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
              ),
              const SizedBox(height: KsTokens.space4),
              Text(
                'Cancelled meals are excluded. You can edit any day next.',
                style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

List<KsMenuDay> _previewDays(MenuSet set) {
  const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const palette = [
    KsTokens.catGrain,
    KsTokens.catMeat,
    KsTokens.catProduce,
    KsTokens.catSeafood,
    KsTokens.catSpice,
    KsTokens.catBakery,
  ];
  return [
    for (var i = 0; i < set.lengthInDays.clamp(1, 7); i++)
      KsMenuDay(
        weekday: weekdays[i % weekdays.length],
        dishColors: [
          for (var j = 0; j < (set.dayAt(i)?.entries.length ?? 0); j++)
            palette[(i + j) % palette.length],
        ],
      ),
  ];
}
