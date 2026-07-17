part of 'recipe_detail_screen.dart';

class _RecipeScheduleFlow {
  const _RecipeScheduleFlow({
    required this.recipeId,
    required this.title,
    required this.baseServings,
    required this.tags,
  });

  final String recipeId;
  final String title;
  final int baseServings;
  final List<String> tags;

  Future<void> open(
    BuildContext pageContext,
    WidgetRef ref, {
    required DateTime initialDate,
  }) async {
    final settings = await ref.read(activeCalendarDaySettingsProvider.future);
    if (!pageContext.mounted) return;
    var selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    var selectedMealLabel = _normalizedMealLabel(_mealLabel);
    var servingSize =
        _scheduleServingSizeForDate(selectedDate, settings) ?? baseServings;
    await showModalBottomSheet<void>(
      context: pageContext,
      showDragHandle: true,
      builder: (sheetContext) {
        final ks = sheetContext.ksColors;
        final today = this.today(ref);
        final options = [
          _ScheduleDateOption('Today', today),
          _ScheduleDateOption(
            'Tomorrow',
            DateTime(today.year, today.month, today.day + 1),
          ),
          _ScheduleDateOption(
            'Next week',
            DateTime(today.year, today.month, today.day + 7),
          ),
        ];
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> confirm() async {
              await _schedule(
                pageContext,
                sheetContext,
                ref,
                date: selectedDate,
                mealLabel: selectedMealLabel,
                servingSize: servingSize,
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KsTokens.space20,
                  KsTokens.space4,
                  KsTokens.space20,
                  KsTokens.space20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Schedule meal',
                      style: KsTokens.titleLarge.copyWith(
                        color: ks.textPrimary,
                      ),
                    ),
                    const SizedBox(height: KsTokens.space12),
                    Wrap(
                      spacing: KsTokens.space8,
                      runSpacing: KsTokens.space8,
                      children: [
                        for (final option in options)
                          ChoiceChip(
                            label: Text(
                              '${option.label} · ${_datePath(option.date)}',
                            ),
                            selected: _sameDay(selectedDate, option.date),
                            onSelected: (_) {
                              setSheetState(() {
                                selectedDate = option.date;
                                servingSize =
                                    _scheduleServingSizeForDate(
                                      option.date,
                                      settings,
                                    ) ??
                                    baseServings;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: KsTokens.space12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Breakfast',
                          label: Text('Breakfast'),
                        ),
                        ButtonSegment(value: 'Lunch', label: Text('Lunch')),
                        ButtonSegment(value: 'Dinner', label: Text('Dinner')),
                      ],
                      selected: {selectedMealLabel},
                      onSelectionChanged: (selection) {
                        setSheetState(() {
                          selectedMealLabel = selection.single;
                        });
                      },
                    ),
                    const SizedBox(height: KsTokens.space12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Serves $servingSize',
                            style: KsTokens.titleSmall.copyWith(
                              color: ks.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Decrease servings',
                          onPressed: servingSize <= 1
                              ? null
                              : () => setSheetState(() => servingSize--),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        IconButton(
                          tooltip: 'Increase servings',
                          onPressed: () => setSheetState(() => servingSize++),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: KsTokens.space16),
                    FilledButton.icon(
                      onPressed: confirm,
                      icon: const Icon(Icons.event_available_rounded),
                      label: const Text('Add to calendar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _schedule(
    BuildContext pageContext,
    BuildContext sheetContext,
    WidgetRef ref, {
    required DateTime date,
    required String mealLabel,
    required int servingSize,
  }) async {
    final scheduledDate = DateTime(date.year, date.month, date.day);
    final entry = MealScheduleEntry(
      id: ref.read(idGeneratorProvider).newId(),
      recipeId: recipeId,
      date: scheduledDate,
      mealLabel: mealLabel,
      servingSize: servingSize,
    );
    await ref
        .read(calendarRepositoryProvider)
        .upsertMeal(
          householdId: ref.read(activeHouseholdIdProvider),
          entry: entry,
        );
    final household = ref.read(activeHouseholdContextProvider);
    if (household != null &&
        const HouseholdPolicy().roleCan(
          household.role,
          HouseholdCapability.generateShoppingLists,
          isSoloHousehold: household.isSolo,
        )) {
      await ref
          .read(shoppingPlanningControllerProvider)
          .reconcileScheduledLists([
            ScheduledShoppingRange(start: scheduledDate, end: scheduledDate),
          ]);
    }
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    if (!pageContext.mounted) return;
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(
        content: Text('$title scheduled for ${_datePath(scheduledDate)}.'),
      ),
    );
    final router = GoRouter.maybeOf(pageContext);
    if (router != null) {
      await router.push('/day/${_datePath(scheduledDate)}');
    }
  }

  DateTime today(WidgetRef ref) {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime tomorrow(WidgetRef ref) {
    final today = this.today(ref);
    return DateTime(today.year, today.month, today.day + 1);
  }

  String get _mealLabel {
    for (final tag in tags) {
      final lower = tag.toLowerCase();
      if (lower == 'breakfast' || lower == 'lunch' || lower == 'dinner') {
        return tag;
      }
    }
    return 'Dinner';
  }

  String _normalizedMealLabel(String label) {
    final lower = label.toLowerCase();
    if (lower == 'breakfast') return 'Breakfast';
    if (lower == 'lunch') return 'Lunch';
    return 'Dinner';
  }
}
