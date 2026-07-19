import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/services/calendar_day_settings_resolver.dart';
import 'package:kitchensync/features/calendar/domain/services/calendar_day_status_resolver.dart';
import 'package:kitchensync/features/calendar/domain/services/weekly_shopping_schedule_engine.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

part 'calendar_screen_default_field.dart';
part 'calendar_screen_defaults.dart';
part 'calendar_screen_helpers.dart';
part 'calendar_screen_peek.dart';

enum _CalendarView { month, week }

/// Screen 02 · Calendar — an almanac you read in seconds.
///
/// The grid *is* the hero; chrome recedes. Status colour + glyph rhythm tells
/// the household's month at a glance.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    super.key,
    this.initialMonth,
    this.initialSelectedDate,
  });

  final DateTime? initialMonth;
  final DateTime? initialSelectedDate;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  _CalendarView _view = _CalendarView.month;

  @override
  void initState() {
    super.initState();
    final initialSelectedDate = widget.initialSelectedDate ?? DateTime.now();
    final initialMonth = widget.initialMonth ?? initialSelectedDate;
    _visibleMonth = DateTime(initialMonth.year, initialMonth.month);
    _selectedDate = _clampToMonth(initialSelectedDate, _visibleMonth);
  }

  void _changePeriod(int delta) {
    setState(() {
      if (_view == _CalendarView.month) {
        _visibleMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + delta,
        );
        _selectedDate = _clampToMonth(_selectedDate, _visibleMonth);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
        _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
      }
    });
  }

  void _setView(Set<_CalendarView> selection) {
    setState(() {
      _view = selection.single;
      _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleStart = _view == _CalendarView.month
        ? DateTime(_visibleMonth.year, _visibleMonth.month)
        : _startOfWeek(_selectedDate);
    final visibleEnd = _view == _CalendarView.month
        ? DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0)
        : visibleStart.add(const Duration(days: 6));
    final persistedMeals = ref.watch(
      activeCalendarMealsProvider((start: visibleStart, end: visibleEnd)),
    );
    final activeSettings = ref.watch(activeCalendarDaySettingsProvider);
    final persistedRecipes = ref.watch(activeHouseholdRecipesProvider);
    final pantryItems = ref.watch(pantryAllItemsStreamProvider);
    final wasteEvents = ref.watch(wasteHistoryStreamProvider);
    final shoppingSchedule = ref.watch(activeShoppingScheduleProvider);
    final shoppingLists = ref.watch(activeShoppingListsProvider);
    final household = ref.watch(activeHouseholdContextProvider);
    final canConfigureDefaults =
        household == null ||
        const HouseholdPolicy().roleCan(
          household.role,
          HouseholdCapability.configureCalendarDefaults,
          isSoloHousehold: household.isSolo,
        );
    final schedule = persistedMeals.valueOrNull ?? const <MealScheduleEntry>[];
    final recipesById = _recipesById(persistedRecipes.valueOrNull);
    final mealsByDay = _mealsByDay(schedule);
    final wasteDays = _wasteDays(wasteEvents.valueOrNull ?? const []);
    final persistedLists = shoppingLists.valueOrNull ?? const [];
    final shoppingDates = <DateTime>{
      for (final list in persistedLists)
        if (list.type == ShoppingListType.scheduled)
          _dateKey(list.shoppingDate),
      if (shoppingSchedule.valueOrNull case final activeSchedule?)
        ...const WeeklyShoppingScheduleEngine()
            .occurrencesInRange(
              schedule: activeSchedule,
              plannedRangeStart: visibleStart,
              plannedRangeEnd: visibleEnd,
            )
            .where(
              (date) =>
                  !date.isBefore(visibleStart) && !date.isAfter(visibleEnd),
            )
            .map(_dateKey),
    };
    final completedShoppingDates = {
      for (final list in persistedLists)
        if (list.type == ShoppingListType.scheduled &&
            list.status == ShoppingListStatus.completed)
          _dateKey(list.shoppingDate),
    };
    final dayStatuses = const CalendarDayStatusResolver().resolve(
      start: visibleStart,
      end: visibleEnd,
      now: ref.watch(clockProvider).now(),
      meals: schedule,
      recipesById: recipesById,
      pantryItems: pantryItems.valueOrNull ?? const [],
      shoppingDates: shoppingDates,
      completedShoppingDates: completedShoppingDates,
      wasteDates: wasteDays,
    );
    final days = _view == _CalendarView.month
        ? _monthDays(
            month: _visibleMonth,
            dayStatuses: dayStatuses,
            selectedDate: _selectedDate,
          )
        : _weekDays(
            start: visibleStart,
            dayStatuses: dayStatuses,
            selectedDate: _selectedDate,
          );
    final selectedMeals = mealsByDay[_dateKey(_selectedDate)] ?? const [];
    final selectedMeal = selectedMeals.isEmpty ? null : selectedMeals.first;
    final selectedRecipe = selectedMeal == null
        ? null
        : recipesById[selectedMeal.recipeId];
    return SafeArea(
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
            eyebrow: 'The Calendar',
            title: _view == _CalendarView.month
                ? _monthTitle(_visibleMonth)
                : _weekTitle(visibleStart, visibleEnd),
            actions: [
              KsHeaderAction(
                icon: Icons.shopping_cart_checkout_rounded,
                tooltip: 'Shopping schedule',
                onTap: () => context.push('/calendar/shopping-schedule'),
              ),
              if (canConfigureDefaults)
                KsHeaderAction(
                  key: const ValueKey('calendar-defaults-action'),
                  icon: Icons.tune_rounded,
                  tooltip: 'Calendar defaults',
                  onTap: () => _openDefaultsSheet(
                    activeSettings.valueOrNull,
                    visibleStart,
                    visibleEnd,
                  ),
                ),
              KsHeaderAction(
                icon: Icons.dashboard_customize_outlined,
                tooltip: 'Menu Sets',
                onTap: () => context.push('/menu-sets'),
              ),
              KsHeaderAction(
                icon: Icons.chevron_left_rounded,
                tooltip: _view == _CalendarView.month
                    ? 'Previous month'
                    : 'Previous week',
                onTap: () => _changePeriod(-1),
              ),
              KsHeaderAction(
                icon: Icons.chevron_right_rounded,
                tooltip: _view == _CalendarView.month
                    ? 'Next month'
                    : 'Next week',
                onTap: () => _changePeriod(1),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          SegmentedButton<_CalendarView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _CalendarView.month,
                icon: Icon(Icons.calendar_view_month_rounded),
                label: Text('Month'),
              ),
              ButtonSegment(
                value: _CalendarView.week,
                icon: Icon(Icons.view_week_outlined),
                label: Text('Week'),
              ),
            ],
            selected: {_view},
            onSelectionChanged: _setView,
          ),
          const SizedBox(height: KsTokens.space16),
          KsAlmanacGrid(
            days: days,
            onDayTap: (day) {
              final date = _view == _CalendarView.month
                  ? DateTime(_visibleMonth.year, _visibleMonth.month, day)
                  : _dateInWeek(visibleStart, day);
              context.push('/day/${_datePath(date)}');
            },
          ),
          const SizedBox(height: KsTokens.space16),
          _SelectedDayPeek(
            date: _selectedDate,
            meal: selectedMeal,
            recipe: selectedRecipe,
            onTap: () => context.push('/day/${_datePath(_selectedDate)}'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDefaultsSheet(
    List<CalendarDaySettings>? settings,
    DateTime visibleStart,
    DateTime visibleEnd,
  ) async {
    final List<CalendarDaySettings> resolvedSettings;
    if (settings != null) {
      resolvedSettings = settings;
    } else {
      resolvedSettings = await ref.read(
        activeCalendarDaySettingsProvider.future,
      );
    }
    if (!mounted) return;
    final existing = CalendarDaySettingsResolver.forDate(
      _selectedDate,
      resolvedSettings,
    );
    final input = await showModalBottomSheet<_CalendarDefaultsInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CalendarDefaultsSheet(
        existing: existing,
        initialStart: existing?.dateRangeStart ?? visibleStart,
        initialEnd: existing?.dateRangeEnd ?? visibleEnd,
      ),
    );
    if (input == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(calendarSettingsControllerProvider)
          .saveDefaults(
            existing: existing,
            dateRangeStart: input.dateRangeStart,
            dateRangeEnd: input.dateRangeEnd,
            defaultServingSize: input.defaultServingSize,
            mealsPerDay: input.mealsPerDay,
            dishesPerMeal: input.dishesPerMeal,
            mealModeName: input.mealModeName,
          );
      ref.invalidate(activeCalendarDaySettingsProvider);
      if (!mounted) {
        return;
      }
      _showSnackBar('Calendar defaults saved');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Could not save defaults: $error');
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
