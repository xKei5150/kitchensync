import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

part 'calendar_screen_default_field.dart';
part 'calendar_screen_defaults.dart';
part 'calendar_screen_helpers.dart';
part 'calendar_screen_peek.dart';

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

  @override
  void initState() {
    super.initState();
    final initialSelectedDate = widget.initialSelectedDate ?? DateTime.now();
    final initialMonth = widget.initialMonth ?? initialSelectedDate;
    _visibleMonth = DateTime(initialMonth.year, initialMonth.month);
    _selectedDate = _clampToMonth(initialSelectedDate, _visibleMonth);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDate = _clampToMonth(_selectedDate, _visibleMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleStart = DateTime(_visibleMonth.year, _visibleMonth.month);
    final visibleEnd = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final persistedMeals = ref.watch(
      activeCalendarMealsProvider((start: visibleStart, end: visibleEnd)),
    );
    final activeSettings = ref.watch(activeCalendarDaySettingsProvider);
    final persistedRecipes = ref.watch(activeHouseholdRecipesProvider);
    final wasteEvents = ref.watch(wasteHistoryStreamProvider);
    final schedule = persistedMeals.valueOrNull ?? const <MealScheduleEntry>[];
    final recipesById = _recipesById(persistedRecipes.valueOrNull);
    final mealsByDay = _mealsByDay(schedule);
    final wasteDays = _wasteDays(wasteEvents.valueOrNull ?? const []);
    final days = _monthDays(
      month: _visibleMonth,
      mealsByDay: mealsByDay,
      wasteDays: wasteDays,
      shoppingDate: null,
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
            title: _monthTitle(_visibleMonth),
            actions: [
              KsHeaderAction(
                icon: Icons.shopping_cart_checkout_rounded,
                tooltip: 'Shopping schedule',
                onTap: () => context.push('/calendar/shopping-schedule'),
              ),
              KsHeaderAction(
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
                tooltip: 'Previous month',
                onTap: () => _changeMonth(-1),
              ),
              KsHeaderAction(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next month',
                onTap: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space16),
          KsAlmanacGrid(
            days: days,
            onDayTap: (day) {
              final date = DateTime(
                _visibleMonth.year,
                _visibleMonth.month,
                day,
              );
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
    final existing = _settingsForDate(_selectedDate, settings ?? const []);
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
