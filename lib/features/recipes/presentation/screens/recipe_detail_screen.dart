import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

/// Screen 06 · Recipe detail · "Closer Look" — a cookbook spread that scales
/// live.
///
/// Full-bleed and photo-led: a category-tinted hero, a drop-cap intro, then the
/// [KsServingScaler] rescaling the ingredient list in real time. Reused by the
/// calendar when picking a meal; loads a saved recipe when a route id is given.
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({this.recipeId, super.key});

  final String? recipeId;

  /// The braise carried through from Today / the calendar's tonight card.
  static const _title = 'Tomato & white bean braise';
  static const _intro =
      'weeknight braise that tastes like a Sunday — soft beans, blistered '
      'tomatoes, a slick of good oil. Forgiving, and better the next day.';

  static const _ingredients = [
    KsScalableIngredient(name: 'White beans', baseAmount: 2, unit: 'tins'),
    KsScalableIngredient(name: 'Tomatoes', baseAmount: 800, unit: 'g'),
    KsScalableIngredient(name: 'Spinach', baseAmount: 1, unit: 'bunch'),
    KsScalableIngredient(name: 'Olive oil', baseAmount: 3, unit: 'tbsp'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recipeId;
    if (id != null) {
      final recipeAsync = ref.watch(recipeRecordProvider(id));
      return recipeAsync.when(
        data: (recipe) {
          if (recipe == null) {
            return const Scaffold(
              body: Center(
                child: KsEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Recipe not found',
                  subtitle: 'It may have been deleted or moved.',
                ),
              ),
            );
          }
          return _RecipeDetailBody(
            recipeId: recipe.id,
            title: recipe.name,
            intro: recipe.description.isEmpty
                ? recipe.name
                : recipe.description,
            baseServings: recipe.defaultServingSize,
            ingredients: recipe.ingredients
                .map(_scaledIngredient)
                .toList(growable: false),
            tags: [...recipe.mealTimeTags, ...recipe.recipeTags],
            priceEstimate: recipe.priceEstimate,
            instructions: recipe.instructions,
            onBack: () => context.pop(),
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(KsTokens.space16),
            child: Center(
              child: KsErrorAlert(message: 'Could not load recipe: $error'),
            ),
          ),
        ),
      );
    }
    return _RecipeDetailBody(
      recipeId: 'braise',
      title: _title,
      intro: _intro,
      baseServings: 4,
      ingredients: _ingredients,
      tags: const ['Vegetarian'],
      instructions: const [],
      onBack: () => context.pop(),
    );
  }

  static KsScalableIngredient _scaledIngredient(RecipeIngredient ingredient) {
    return KsScalableIngredient(
      name: ingredient.description ?? ingredient.ingredientId,
      baseAmount: ingredient.quantity,
      unit: _unitLabel(ingredient.unit),
    );
  }

  static String _unitLabel(Unit unit) => switch (unit) {
    Unit.g => 'g',
    Unit.kg => 'kg',
    Unit.ml => 'ml',
    Unit.l => 'l',
    Unit.piece => 'pc',
    Unit.tsp => 'tsp',
    Unit.tbsp => 'tbsp',
    Unit.cup => 'cup',
  };
}

class _RecipeDetailBody extends ConsumerWidget {
  const _RecipeDetailBody({
    required this.recipeId,
    required this.title,
    required this.intro,
    required this.baseServings,
    required this.ingredients,
    required this.tags,
    required this.instructions,
    required this.onBack,
    this.priceEstimate,
  });

  final String recipeId;
  final String title;
  final String intro;
  final int baseServings;
  final List<KsScalableIngredient> ingredients;
  final List<String> tags;
  final List<String> instructions;
  final double? priceEstimate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final unitSystem = ref
        .watch(localePreferencesControllerProvider)
        .unitSystem;
    final currency = ref.watch(localeFormattersProvider).currency;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(title: title, tags: tags, onBack: onBack),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KsTokens.space20,
              KsTokens.space16,
              KsTokens.space20,
              KsTokens.space24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DropCapIntro(initial: _initialFor(intro), body: intro),
                if (tags.isNotEmpty || priceEstimate != null) ...[
                  const SizedBox(height: KsTokens.space12),
                  Wrap(
                    spacing: KsTokens.space8,
                    runSpacing: KsTokens.space8,
                    children: [
                      if (priceEstimate != null)
                        KsTag(
                          label: currency.format(priceEstimate!),
                          icon: Icons.payments_outlined,
                          tone: KsTagTone.outline,
                        ),
                      for (final tag in tags)
                        KsTag(label: tag, tone: KsTagTone.neutral),
                    ],
                  ),
                ],
                const SizedBox(height: KsTokens.space16),
                KsServingScaler(
                  baseServings: baseServings,
                  ingredients: ingredients,
                  unitSystem: unitSystem,
                ),
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: KsTokens.space20),
                  Text(
                    'Instructions',
                    style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
                  ),
                  const SizedBox(height: KsTokens.space10),
                  for (var i = 0; i < instructions.length; i++) ...[
                    Text(
                      '${i + 1}. ${instructions[i]}',
                      style: KsTokens.bodyMedium.copyWith(
                        color: ks.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (i != instructions.length - 1)
                      const SizedBox(height: KsTokens.space8),
                  ],
                ],
                const SizedBox(height: KsTokens.space20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _openScheduleFlow(
                          context,
                          ref,
                          initialDate: _today(ref),
                        ),
                        child: const Text('Start cooking'),
                      ),
                    ),
                    const SizedBox(width: KsTokens.space10),
                    OutlinedButton(
                      onPressed: () => _openScheduleFlow(
                        context,
                        ref,
                        initialDate: _tomorrow(ref),
                      ),
                      child: const Text('Schedule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialFor(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'A' : trimmed.characters.first.toUpperCase();
  }

  Future<void> _openScheduleFlow(
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
        _servingSizeForDate(selectedDate, settings) ?? baseServings;
    await showModalBottomSheet<void>(
      context: pageContext,
      showDragHandle: true,
      builder: (sheetContext) {
        final ks = sheetContext.ksColors;
        final today = _today(ref);
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
                                    _servingSizeForDate(
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

  DateTime _today(WidgetRef ref) {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _tomorrow(WidgetRef ref) {
    final today = _today(ref);
    return DateTime(today.year, today.month, today.day + 1);
  }

  int? _servingSizeForDate(DateTime date, List<CalendarDaySettings> settings) {
    for (final setting in settings) {
      final start = DateTime(
        setting.dateRangeStart.year,
        setting.dateRangeStart.month,
        setting.dateRangeStart.day,
      );
      final end = DateTime(
        setting.dateRangeEnd.year,
        setting.dateRangeEnd.month,
        setting.dateRangeEnd.day,
      );
      if (!date.isBefore(start) && !date.isAfter(end)) {
        return setting.defaultServingSize;
      }
    }
    return null;
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

class _ScheduleDateOption {
  const _ScheduleDateOption(this.label, this.date);

  final String label;
  final DateTime date;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _datePath(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// The full-bleed editorial hero — a category-tinted wash, a circular back and
/// bookmark in the safe area, and the eyebrow + serif title riding a bottom
/// scrim.
class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.tags, required this.onBack});

  final String title;
  final List<String> tags;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raised = ks.surfaceRaised;
    final accent = isDark ? KsTokens.brandAccent : KsTokens.catSpice;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(raised, KsTokens.catProduce, isDark ? 0.30 : 0.40)!,
        Color.lerp(raised, KsTokens.catGrain, isDark ? 0.26 : 0.34)!,
        Color.lerp(raised, accent, isDark ? 0.24 : 0.30)!,
      ],
    );

    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          // Bottom scrim so the white title stays legible over any wash.
          const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x80000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space16,
                KsTokens.space8,
                KsTokens.space16,
                KsTokens.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ScrimButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: onBack,
                      ),
                      const _ScrimButton(
                        icon: Icons.bookmark_border_rounded,
                        tooltip: 'Save recipe',
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _eyebrow.toUpperCase(),
                    style: KsTokens.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space4),
                  Text(
                    title,
                    style: KsTokens.displayMedium.copyWith(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.05,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _eyebrow {
    final tag = tags.isEmpty ? 'Recipe' : tags.first;
    return 'Closer Look · $tag';
  }
}

/// A circular translucent control on the hero scrim.
class _ScrimButton extends StatelessWidget {
  const _ScrimButton({required this.icon, this.tooltip, this.onTap});

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// A drop-cap editorial intro — an oversized serif initial that the body text
/// wraps around, set via an inline [WidgetSpan].
class _DropCapIntro extends StatelessWidget {
  const _DropCapIntro({required this.initial, required this.body});

  final String initial;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Padding(
              padding: const EdgeInsets.only(right: 9, top: 5),
              child: Text(
                initial,
                style: KsTokens.displayLarge.copyWith(
                  color: isDark
                      ? KsTokens.brandAccent
                      : KsTokens.brandPrimaryDark,
                  fontSize: 46,
                  height: 0.74,
                ),
              ),
            ),
          ),
          TextSpan(
            text: body,
            style: KsTokens.bodyMedium.copyWith(
              color: ks.textSecondary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
