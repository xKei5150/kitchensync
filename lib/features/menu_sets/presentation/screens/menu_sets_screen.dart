import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';

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
    final today = DateTime.now();
    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 6));
    try {
      await ref
          .read(menuSetEditorControllerProvider)
          .createFromPastCalendar(
            startDate: start,
            endDate: end,
            name: 'Last week',
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create menu set: $error')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Created a menu set from last week.')),
    );
  }

  Future<void> _apply(MenuSet set, bool allowed) async {
    if (!allowed) return _showAccessRequired();
    final start = DateTime(2026, 7, 6);
    final end = DateTime(2026, 8, 2);
    try {
      await ref
          .read(menuSetApplyPersistenceControllerProvider)
          .applyPersistedMenuSet(
            menuSet: set,
            startDate: start,
            endDate: end,
            mode: MenuSetApplyMode.fillEmpty,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply menu set: $error')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied ${set.name} to the calendar.')),
    );
  }

  Future<void> _duplicate(MenuSet set, bool allowed) async {
    if (!allowed) return _showAccessRequired();
    final now = DateTime.now();
    final duplicateId = '${set.id}-copy-${now.microsecondsSinceEpoch}';
    final duplicate = MenuSet(
      id: duplicateId,
      householdId: set.householdId,
      name: '${set.name} copy',
      description: set.description,
      lengthInDays: set.lengthInDays,
      createdByUserId: set.createdByUserId,
      createdAt: now,
      updatedAt: now,
      isPublicTemplate: set.isPublicTemplate,
      days: [
        for (final day in set.days)
          _duplicateDay(day, duplicateId, now.microsecondsSinceEpoch),
      ],
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

MenuSetDay _duplicateDay(MenuSetDay day, String menuSetId, int suffix) {
  final dayId = '${day.id}-copy-$suffix';
  return MenuSetDay(
    id: dayId,
    menuSetId: menuSetId,
    dayIndex: day.dayIndex,
    label: day.label,
    entries: [
      for (final entry in day.entries)
        MenuSetEntry(
          id: '${entry.id}-copy-$suffix',
          menuSetDayId: dayId,
          mealSlot: entry.mealSlot,
          recipeId: entry.recipeId,
          orderInSlot: entry.orderInSlot,
        ),
    ],
  );
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
