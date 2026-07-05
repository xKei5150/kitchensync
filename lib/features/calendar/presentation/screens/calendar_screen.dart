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

  Map<String, PlannedRecipe> _recipesById(List<Recipe>? recipes) {
    return {
      for (final recipe in recipes ?? const <Recipe>[])
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

  CalendarDaySettings? _settingsForDate(
    DateTime date,
    List<CalendarDaySettings> settings,
  ) {
    final key = _dateKey(date);
    for (final setting in settings) {
      if (!setting.isActive) continue;
      if (!key.isBefore(_dateKey(setting.dateRangeStart)) &&
          !key.isAfter(_dateKey(setting.dateRangeEnd))) {
        return setting;
      }
    }
    for (final setting in settings) {
      if (setting.isActive) {
        return setting;
      }
    }
    return null;
  }

  Set<DateTime> _wasteDays(Iterable<WasteEvent> wasteEvents) {
    return {for (final event in wasteEvents) _dateKey(event.date)};
  }

  List<KsAlmanacDay> _monthDays({
    required DateTime month,
    required Map<DateTime, List<MealScheduleEntry>> mealsByDay,
    required Set<DateTime> wasteDays,
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
            wasteDays,
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
    Set<DateTime> wasteDays,
    DateTime? shoppingDate,
  ) {
    if (shoppingDate != null && _dateKey(shoppingDate) == _dateKey(date)) {
      return CalendarDayStatus.shopping;
    }
    final meals = mealsByDay[_dateKey(date)] ?? const [];
    if (meals.any((meal) => meal.state == ScheduledMealState.cancelled)) {
      return CalendarDayStatus.problem;
    }
    if (wasteDays.contains(_dateKey(date))) {
      return CalendarDayStatus.problem;
    }
    if (meals.isEmpty) {
      return CalendarDayStatus.empty;
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

class _CalendarDefaultsInput {
  const _CalendarDefaultsInput({
    required this.dateRangeStart,
    required this.dateRangeEnd,
    required this.defaultServingSize,
    required this.mealsPerDay,
    required this.dishesPerMeal,
    required this.mealModeName,
  });

  final DateTime dateRangeStart;
  final DateTime dateRangeEnd;
  final int defaultServingSize;
  final int mealsPerDay;
  final int dishesPerMeal;
  final String mealModeName;
}

class _CalendarDefaultsSheet extends StatefulWidget {
  const _CalendarDefaultsSheet({
    required this.existing,
    required this.initialStart,
    required this.initialEnd,
  });

  final CalendarDaySettings? existing;
  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_CalendarDefaultsSheet> createState() => _CalendarDefaultsSheetState();
}

class _CalendarDefaultsSheetState extends State<_CalendarDefaultsSheet> {
  late final TextEditingController _servingsController;
  late final TextEditingController _mealsController;
  late final TextEditingController _dishesController;
  late final TextEditingController _modeController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _servingsController = TextEditingController(
      text: '${existing?.defaultServingSize ?? 4}',
    );
    _mealsController = TextEditingController(
      text: '${existing?.mealsPerDay ?? 3}',
    );
    _dishesController = TextEditingController(
      text: '${existing?.dishesPerMeal ?? 1}',
    );
    _modeController = TextEditingController(
      text: existing?.mealModeName ?? 'Standard',
    );
    _startController = TextEditingController(
      text: _datePath(existing?.dateRangeStart ?? widget.initialStart),
    );
    _endController = TextEditingController(
      text: _datePath(existing?.dateRangeEnd ?? widget.initialEnd),
    );
  }

  @override
  void dispose() {
    _servingsController.dispose();
    _mealsController.dispose();
    _dishesController.dispose();
    _modeController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _save() {
    final servings = int.tryParse(_servingsController.text.trim());
    final meals = int.tryParse(_mealsController.text.trim());
    final dishes = int.tryParse(_dishesController.text.trim());
    final start = _parseDate(_startController.text.trim());
    final end = _parseDate(_endController.text.trim());
    if (servings == null || servings <= 0) {
      setState(() => _error = 'Default serving size must be positive.');
      return;
    }
    if (meals == null || meals <= 0) {
      setState(() => _error = 'Meals per day must be positive.');
      return;
    }
    if (dishes == null || dishes <= 0) {
      setState(() => _error = 'Dishes per meal must be positive.');
      return;
    }
    if (start == null || end == null || end.isBefore(start)) {
      setState(() => _error = 'Use a valid date range.');
      return;
    }
    Navigator.of(context).pop(
      _CalendarDefaultsInput(
        dateRangeStart: start,
        dateRangeEnd: end,
        defaultServingSize: servings,
        mealsPerDay: meals,
        dishesPerMeal: dishes,
        mealModeName: _modeController.text.trim(),
      ),
    );
  }

  DateTime? _parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return _datePath(parsed) == value
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space12,
          KsTokens.space20,
          KsTokens.space20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
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
              'Calendar defaults',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: KsTokens.space12),
            _CalendarDefaultsTextField(
              controller: _startController,
              label: 'Start date',
            ),
            const SizedBox(height: KsTokens.space8),
            _CalendarDefaultsTextField(
              controller: _endController,
              label: 'End date',
            ),
            const SizedBox(height: KsTokens.space8),
            Row(
              children: [
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _servingsController,
                    label: 'Default serving size',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: KsTokens.space8),
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _mealsController,
                    label: 'Meals per day',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space8),
            Row(
              children: [
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _dishesController,
                    label: 'Dishes per meal',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: KsTokens.space8),
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _modeController,
                    label: 'Meal mode',
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: KsTokens.space10),
              KsErrorAlert(message: _error!),
            ],
            const SizedBox(height: KsTokens.space12),
            FilledButton(onPressed: _save, child: const Text('Save defaults')),
          ],
        ),
      ),
    );
  }
}

class _CalendarDefaultsTextField extends StatelessWidget {
  const _CalendarDefaultsTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ks.surfaceBase,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
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
