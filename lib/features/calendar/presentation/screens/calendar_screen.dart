import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/planning_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

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
    final planning = ref.watch(planningControllerProvider);
    final visibleStart = DateTime(_visibleMonth.year, _visibleMonth.month);
    final visibleEnd = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final persistedMeals = ref.watch(
      activeCalendarMealsProvider((start: visibleStart, end: visibleEnd)),
    );
    final persistedRecipes = ref.watch(activeHouseholdRecipesProvider);
    final schedule = persistedMeals.valueOrNull?.isNotEmpty ?? false
        ? persistedMeals.valueOrNull!
        : planning.schedule;
    final recipesById = _recipesById(
      persistedRecipes.valueOrNull,
      planning.recipesById,
    );
    final mealsByDay = _mealsByDay(schedule);
    final days = _monthDays(
      month: _visibleMonth,
      mealsByDay: mealsByDay,
      shoppingDate: planning.activeShoppingList?.endDate,
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

  Map<DateTime, List<MealScheduleEntry>> _mealsByDay(
    List<MealScheduleEntry> schedule,
  ) {
    final result = <DateTime, List<MealScheduleEntry>>{};
    for (final meal in schedule) {
      final key = _dateKey(meal.date);
      result.putIfAbsent(key, () => []).add(meal);
    }
    return result;
  }

  Map<String, PlannedRecipe> _recipesById(
    List<Recipe>? recipes,
    Map<String, PlannedRecipe> fallback,
  ) {
    if (recipes == null || recipes.isEmpty) {
      return fallback;
    }
    return {
      for (final recipe in recipes)
        recipe.id: PlannedRecipe(
          id: recipe.id,
          title: recipe.name,
          defaultServingSize: recipe.defaultServingSize,
          ingredients: [
            for (final ingredient in recipe.ingredients)
              RecipeIngredientRequirement(
                ingredientId: ingredient.ingredientId,
                quantity: ingredient.quantity,
                unit: ingredient.unit,
              ),
          ],
        ),
    };
  }

  List<KsAlmanacDay> _monthDays({
    required DateTime month,
    required Map<DateTime, List<MealScheduleEntry>> mealsByDay,
    required DateTime? shoppingDate,
  }) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingPad = first.weekday - DateTime.monday;
    return [
      for (var i = 0; i < leadingPad; i++) KsAlmanacDay.blank,
      for (var day = 1; day <= daysInMonth; day++)
        KsAlmanacDay(
          _statusForDay(
            DateTime(month.year, month.month, day),
            mealsByDay,
            shoppingDate,
          ),
          isToday:
              _dateKey(DateTime(month.year, month.month, day)) ==
              _dateKey(_selectedDate),
        ),
    ];
  }

  CalendarDayStatus _statusForDay(
    DateTime date,
    Map<DateTime, List<MealScheduleEntry>> mealsByDay,
    DateTime? shoppingDate,
  ) {
    if (shoppingDate != null && _dateKey(shoppingDate) == _dateKey(date)) {
      return CalendarDayStatus.shopping;
    }
    final meals = mealsByDay[_dateKey(date)] ?? const [];
    if (meals.isEmpty) {
      return CalendarDayStatus.empty;
    }
    if (meals.any((meal) => meal.state == ScheduledMealState.cancelled)) {
      return CalendarDayStatus.problem;
    }
    if (meals.any((meal) => meal.state == ScheduledMealState.leftover)) {
      return CalendarDayStatus.leftover;
    }
    return CalendarDayStatus.planned;
  }
}

/// The selected-day peek — today's plan in a tappable card that opens the
/// day's lifecycle filmstrip.
class _SelectedDayPeek extends StatelessWidget {
  const _SelectedDayPeek({
    required this.date,
    required this.meal,
    required this.recipe,
    required this.onTap,
  });

  final DateTime date;
  final MealScheduleEntry? meal;
  final PlannedRecipe? recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_weekday(date)} ${date.day} · Planned'.toUpperCase(),
                      style: KsTokens.labelSmall.copyWith(
                        color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline,
                    size: 12,
                    color: KsTokens.fresh,
                  ),
                  const SizedBox(width: KsTokens.space4),
                  Text(
                    'ready',
                    style: KsTokens.labelSmall.copyWith(
                      color: KsTokens.fresh,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space6),
              Text(
                recipe?.title ?? 'No meals planned',
                style: KsTokens.headlineMedium.copyWith(
                  color: ks.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (meal != null) ...[
                const SizedBox(height: KsTokens.space2),
                Text(
                  '${meal!.mealLabel} · serves ${meal!.servingSize}',
                  style: KsTokens.bodySmall.copyWith(
                    color: ks.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _dateKey(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _clampToMonth(DateTime date, DateTime month) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, date.day.clamp(1, lastDay));
}

String _monthTitle(DateTime month) {
  return '${_months[month.month - 1]} ${month.year}';
}

String _weekday(DateTime date) {
  return _weekdays[date.weekday - 1];
}

String _datePath(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
