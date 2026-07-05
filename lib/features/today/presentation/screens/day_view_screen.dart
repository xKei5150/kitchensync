import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

/// Screen 03 · Dish-in-Date · daily view — a day as a lifecycle filmstrip.
///
/// A vertical day-timeline, dishes threaded down a rail rather than stacked
/// cards. Each persisted meal shows its lifecycle state and actions.
class DayViewScreen extends ConsumerWidget {
  const DayViewScreen({super.key, this.selectedDate});

  final DateTime? selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final day = _dateKey(selectedDate ?? ref.watch(clockProvider).now());
    final mealsAsync = ref.watch(
      activeCalendarMealsProvider((start: day, end: day)),
    );
    final meals = _orderedMeals(mealsAsync.valueOrNull ?? const []);
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            KsFolioHeader(
              eyebrow: 'The Day',
              title: _dayTitle(day),
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space20),
            if (mealsAsync.isLoading)
              const _TimelineEntry(
                time: '',
                node: _NodeKind.scheduled,
                isLast: true,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (meals.isEmpty)
              const _TimelineEntry(
                time: '',
                node: _NodeKind.scheduled,
                isLast: true,
                child: KsEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No meal planned',
                  subtitle: 'Schedule a recipe to cook on this day.',
                ),
              )
            else
              for (var i = 0; i < meals.length; i++)
                _mealTimelineEntry(
                  context: context,
                  ref: ref,
                  meal: meals[i],
                  isLast: i == meals.length - 1,
                ),
          ],
        ),
      ),
    );
  }

  Widget _mealTimelineEntry({
    required BuildContext context,
    required WidgetRef ref,
    required MealScheduleEntry meal,
    required bool isLast,
  }) {
    final recipe = ref.watch(recipeRecordProvider(meal.recipeId)).valueOrNull;
    return _TimelineEntry(
      time: _timeForMeal(meal.mealLabel),
      node: _nodeForState(meal.state),
      isLast: isLast,
      child: _TonightExpanded(
        mealLabel: meal.mealLabel,
        stateLabel: _stateLabel(meal.state),
        title: recipe?.name ?? meal.recipeId,
        servingSize: meal.servingSize,
        onMarkCooked: () async {
          try {
            await ref.read(cookingLifecycleControllerProvider).markCooked(meal);
          } on MissingMealIngredientsException catch (error) {
            final list = await ref
                .read(shoppingPlanningControllerProvider)
                .createEmergencyListFromMissing(
                  date: error.meal.date,
                  missingIngredients: error.missingIngredients,
                );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Emergency shopping list created.')),
            );
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              unawaited(router.push('/shop/list/${list.id}'));
            }
            return;
          } catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not mark cooked: $error')),
            );
            return;
          }
          if (!context.mounted) return;
          final router = GoRouter.maybeOf(context);
          if (router?.canPop() ?? false) {
            router!.pop();
          } else {
            await Navigator.of(context).maybePop();
          }
        },
        onChangeServings: () async {
          await _runMealAction(
            context,
            () => ref
                .read(cookingLifecycleControllerProvider)
                .changeServingSize(meal, 6),
            failureLabel: 'Could not change servings',
          );
        },
        onMergeMeals: () async {
          await _runMealAction(
            context,
            () => ref
                .read(cookingLifecycleControllerProvider)
                .mergeMeals(meal: meal, mealCount: 2),
            failureLabel: 'Could not merge meals',
          );
        },
        onSaveLeftovers: () async {
          try {
            await ref
                .read(cookingLifecycleControllerProvider)
                .saveLeftovers(meal: meal, servings: 2);
          } catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save leftovers: $error')),
            );
            return;
          }
          if (!context.mounted) return;
          final router = GoRouter.maybeOf(context);
          if (router?.canPop() ?? false) {
            router!.pop();
          } else {
            await Navigator.of(context).maybePop();
          }
        },
        onSwap: () async {
          await _runMealAction(
            context,
            () => ref
                .read(cookingLifecycleControllerProvider)
                .swapRecipe(meal: meal, recipeId: 'pad-thai', servingSize: 4),
            failureLabel: 'Could not swap recipe',
          );
        },
        onCookNext: () async {
          await _runMealAction(
            context,
            () => ref
                .read(cookingLifecycleControllerProvider)
                .rescheduleCookNext(meal),
            failureLabel: 'Could not reschedule',
          );
        },
        onCancel: () async {
          await _runMealAction(
            context,
            () => ref.read(cookingLifecycleControllerProvider).cancelMeal(meal),
            failureLabel: 'Could not cancel meal',
          );
        },
        onRecipe: () => context.push('/recipe/${meal.recipeId}'),
      ),
    );
  }

  Future<void> _runMealAction(
    BuildContext context,
    Future<void> Function() action, {
    required String failureLabel,
  }) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failureLabel: $error')));
      return;
    }
    if (!context.mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router?.canPop() ?? false) {
      router!.pop();
    } else {
      await Navigator.of(context).maybePop();
    }
  }
}

List<MealScheduleEntry> _orderedMeals(List<MealScheduleEntry> meals) {
  return [...meals]..sort((a, b) {
    final slot = _mealOrder(a.mealLabel).compareTo(_mealOrder(b.mealLabel));
    if (slot != 0) return slot;
    return a.id.compareTo(b.id);
  });
}

int _mealOrder(String mealLabel) {
  return switch (mealLabel.toLowerCase()) {
    'breakfast' => 0,
    'lunch' => 1,
    'dinner' => 2,
    _ => 3,
  };
}

String _timeForMeal(String mealLabel) {
  return switch (mealLabel.toLowerCase()) {
    'breakfast' => '8a',
    'lunch' => '1p',
    'dinner' => '7p',
    _ => '',
  };
}

_NodeKind _nodeForState(ScheduledMealState state) {
  return switch (state) {
    ScheduledMealState.cooked => _NodeKind.done,
    ScheduledMealState.leftover => _NodeKind.leftover,
    ScheduledMealState.scheduled ||
    ScheduledMealState.cancelled => _NodeKind.scheduled,
  };
}

String _stateLabel(ScheduledMealState state) {
  return switch (state) {
    ScheduledMealState.scheduled => 'Scheduled',
    ScheduledMealState.cooked => 'Cooked',
    ScheduledMealState.leftover => 'Leftover',
    ScheduledMealState.cancelled => 'Cancelled',
  };
}

DateTime _dateKey(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _dayTitle(DateTime date) => '${_weekdays[date.weekday - 1]} ${date.day}';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

enum _NodeKind { done, leftover, scheduled }

/// A single rail entry: a time gutter, the rail node + connector, and content.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.time,
    required this.node,
    required this.child,
    this.isLast = false,
  });

  final String time;
  final _NodeKind node;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final nodeColor = switch (node) {
      _NodeKind.done => ks.brandPrimary,
      _NodeKind.leftover => KsTokens.sectionLeftover,
      _NodeKind.scheduled => ks.brandPrimary,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                time,
                style: KsTokens.labelSmall.copyWith(
                  color: ks.textTertiary,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: KsTokens.space8),
          _Rail(color: nodeColor, ring: node == _NodeKind.scheduled),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : KsTokens.space16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.color, required this.ring});

  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SizedBox(
      width: 14,
      child: Column(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: ring ? ks.surfaceRaised : color,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: ring ? 2.5 : 0),
            ),
          ),
          Expanded(child: Container(width: 2, color: ks.hairline)),
        ],
      ),
    );
  }
}

/// Tonight's dish, expanded to its full action surface.
class _TonightExpanded extends StatelessWidget {
  const _TonightExpanded({
    required this.mealLabel,
    required this.stateLabel,
    required this.title,
    required this.servingSize,
    required this.onMarkCooked,
    required this.onChangeServings,
    required this.onMergeMeals,
    required this.onSaveLeftovers,
    required this.onSwap,
    required this.onCookNext,
    required this.onCancel,
    required this.onRecipe,
  });

  final String mealLabel;
  final String stateLabel;
  final String title;
  final int servingSize;
  final VoidCallback onMarkCooked;
  final VoidCallback onChangeServings;
  final VoidCallback onMergeMeals;
  final VoidCallback onSaveLeftovers;
  final VoidCallback onSwap;
  final VoidCallback onCookNext;
  final VoidCallback onCancel;
  final VoidCallback onRecipe;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
        boxShadow: KsTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$mealLabel · $stateLabel'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.brandPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Icon(
                Icons.check_circle_outline,
                size: 13,
                color: KsTokens.fresh,
              ),
              const SizedBox(width: KsTokens.space4),
              Text(
                'all in pantry',
                style: KsTokens.labelSmall.copyWith(
                  color: KsTokens.fresh,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            title,
            style: KsTokens.displaySmall.copyWith(
              color: ks.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              height: 1.1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: KsTokens.space3),
          Text(
            'serves $servingSize',
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMarkCooked,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Mark cooked'),
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              OutlinedButton(onPressed: onRecipe, child: const Text('Recipe')),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          Wrap(
            spacing: KsTokens.space16,
            runSpacing: KsTokens.space8,
            children: [
              _MiniAction(
                icon: Icons.tune_rounded,
                label: 'Servings',
                onTap: onChangeServings,
              ),
              _MiniAction(
                icon: Icons.call_merge_rounded,
                label: 'Merge 2 meals',
                onTap: onMergeMeals,
              ),
              _MiniAction(
                icon: Icons.room_service_outlined,
                label: 'Leftovers',
                onTap: onSaveLeftovers,
              ),
              _MiniAction(
                icon: Icons.swap_horiz_rounded,
                label: 'Swap',
                onTap: onSwap,
              ),
              _MiniAction(
                icon: Icons.skip_next_rounded,
                label: 'Cook next',
                onTap: onCookNext,
              ),
              _MiniAction(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onTap: onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KsTokens.radius8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KsTokens.space2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ks.textSecondary),
            const SizedBox(width: KsTokens.space4),
            Text(
              label,
              style: KsTokens.labelSmall.copyWith(
                color: ks.textSecondary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
