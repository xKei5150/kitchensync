import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

/// Screen 01 · Home / "Today" — a kitchen journal, not a dashboard.
///
/// An oversized Fraunces greeting, one current-meal focus, then a calm
/// urgency-ranked stack backed by the active household's persisted data.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({this.snapshot, super.key});

  /// Deterministic view data for widget and visual tests.
  ///
  /// Production callers leave this null and read the active Firebase-backed
  /// household streams below.
  final TodaySnapshot? snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final injected = snapshot;
    if (injected != null) return _TodayContent(snapshot: injected);

    final now = ref.watch(clockProvider).now();
    if (ref.watch(firebaseAuthProvider) == null) {
      return _TodayContent(snapshot: TodaySnapshot.empty(now: now));
    }

    final day = _dateOnly(now);
    final meals = ref.watch(
      activeCalendarMealsProvider((start: day, end: day)),
    );
    final recipes = ref.watch(activeHouseholdRecipesProvider);
    final pantry = ref.watch(pantryAllItemsStreamProvider);
    final shopping = ref.watch(activeShoppingListsProvider);
    final waste = ref.watch(wasteHistoryStreamProvider);
    final values = <AsyncValue<dynamic>>[
      meals,
      recipes,
      pantry,
      shopping,
      waste,
    ];
    final error = _firstError(values);
    if (error != null) {
      return _TodayStatus(
        child: KsErrorAlert(message: 'Could not load today: $error'),
      );
    }
    if (values.any((value) => value.isLoading && value.valueOrNull == null)) {
      return const _TodayStatus(child: CircularProgressIndicator());
    }

    final household = ref.watch(activeHouseholdContextProvider);
    final user = ref.watch(activeFirebaseUserProvider).valueOrNull;
    return _TodayContent(
      snapshot: TodaySnapshot(
        now: now,
        householdName: household?.name ?? 'My kitchen',
        userDisplayName: user?.displayName ?? user?.email?.split('@').first,
        meals: meals.valueOrNull ?? const [],
        recipes: recipes.valueOrNull ?? const [],
        pantryItems: pantry.valueOrNull ?? const [],
        shoppingLists: shopping.valueOrNull ?? const [],
        wasteEvents: waste.valueOrNull ?? const [],
      ),
    );
  }
}

class TodaySnapshot {
  const TodaySnapshot({
    required this.now,
    required this.householdName,
    required this.meals,
    required this.recipes,
    required this.pantryItems,
    required this.shoppingLists,
    required this.wasteEvents,
    this.userDisplayName,
  });

  factory TodaySnapshot.empty({required DateTime now}) => TodaySnapshot(
    now: now,
    householdName: 'My kitchen',
    meals: const [],
    recipes: const [],
    pantryItems: const [],
    shoppingLists: const [],
    wasteEvents: const [],
  );

  final DateTime now;
  final String householdName;
  final String? userDisplayName;
  final List<MealScheduleEntry> meals;
  final List<Recipe> recipes;
  final List<PantryItem> pantryItems;
  final List<ShoppingListRecord> shoppingLists;
  final List<WasteEvent> wasteEvents;
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.snapshot});

  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(snapshot.now);
    final meal = _primaryMeal(snapshot.meals);
    final recipesById = {
      for (final recipe in snapshot.recipes) recipe.id: recipe,
    };
    final recipe = meal == null ? null : recipesById[meal.recipeId];
    final useSoon = _firstExpiring(snapshot.pantryItems);
    final daysUntilShop = _daysUntilNextShop(snapshot.shoppingLists, today);
    final recentWaste = snapshot.wasteEvents.where((event) {
      final weekStart = today.subtract(const Duration(days: 6));
      return !event.date.isBefore(weekStart);
    }).length;
    final displayName = _firstName(snapshot.userDisplayName);
    final greeting =
        '${_greetingFor(snapshot.now)}'
        '${displayName == null ? '' : ', $displayName'}';
    final plannedCount = snapshot.meals
        .where((entry) => entry.state != ScheduledMealState.cancelled)
        .length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space6,
          KsTokens.space16,
          KsTokens.space24,
        ),
        children: [
          _GreetingHeader(
            householdName: snapshot.householdName,
            accountName: displayName ?? 'Account',
            greeting: greeting,
            subtitle: _planningSubtitle(today, plannedCount),
          ),
          const SizedBox(height: KsTokens.space16),
          if (meal == null)
            _NoMealHero(onPlanMeal: () => context.push('/recipes'))
          else
            _TonightHero(
              mealLabel: meal.mealLabel,
              title: recipe?.name ?? _displayId(meal.recipeId),
              servingSize: meal.servingSize,
              ingredientCount: recipe?.ingredients.length,
              onStartCooking: () => context.push('/day/${_datePath(today)}'),
            ),
          const _SprigDivider(),
          const _SectionLabel('Use soon'),
          const SizedBox(height: KsTokens.space10),
          if (useSoon == null)
            const _UseSoonEmpty()
          else
            _UseSoonRow(
              name: _displayId(useSoon.ingredientId),
              note: _expiryNote(useSoon.expiryDate!, today),
              daysLabel: _expiryLabel(useSoon.expiryDate!, today),
            ),
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: daysUntilShop?.toString() ?? '—',
                  label: daysUntilShop == null
                      ? 'no upcoming shop'
                      : daysUntilShop == 0
                      ? 'shopping day is today'
                      : 'days until next shop',
                  accent: _StatAccent.shopping,
                ),
              ),
              const SizedBox(width: KsTokens.space10),
              Expanded(
                child: _StatCard(
                  value: recentWaste.toString(),
                  label: 'waste events this week',
                  accent: _StatAccent.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStatus extends StatelessWidget {
  const _TodayStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(KsTokens.space20),
        child: child,
      ),
    ),
  );
}

/// The eyebrow + avatar row, the oversized greeting, and an italic Fraunces
/// status line. Shared by the calm and busy day layouts.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.householdName,
    required this.accountName,
    required this.greeting,
    required this.subtitle,
  });

  final String householdName;
  final String accountName;
  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                householdName.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            _HeaderTapTarget(
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
              child: const _HeaderDisc(icon: Icons.notifications_none_rounded),
            ),
            _HeaderTapTarget(
              label: 'Settings',
              onTap: () => context.push('/settings'),
              child: const _HeaderDisc(icon: Icons.settings_outlined),
            ),
            _HeaderTapTarget(
              label: 'Account · $accountName',
              onTap: () => context.push('/settings'),
              child: KsMemberAvatar(
                initial: accountName.characters.first.toUpperCase(),
                seat: 0,
                size: 32,
              ),
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space12),
        Text(
          greeting,
          style: KsTokens.displayMedium.copyWith(
            color: ks.textPrimary,
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: KsTokens.space2),
        Text(
          subtitle,
          style: KsTokens.displaySmall.copyWith(
            color: ks.textSecondary,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// A header chrome entry point — keeps the small disc / avatar visual but
/// guarantees a 48×48 tap target and an accessible label (WCAG 2.5.5), via the
/// shared [KsHitTarget].
class _HeaderTapTarget extends StatelessWidget {
  const _HeaderTapTarget({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KsHitTarget(label: label, onTap: onTap, child: child);
  }
}

/// The small neutral disc behind a header glyph, matching `KsHeaderAction`.
class _HeaderDisc extends StatelessWidget {
  const _HeaderDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ks.neutralSubtle,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: ks.textSecondary),
    );
  }
}

/// The hero "tonight" card — a category-tinted cover band, the recipe, an
/// at-a-glance pantry-readiness line, and the primary action.
class _TonightHero extends StatelessWidget {
  const _TonightHero({
    required this.mealLabel,
    required this.title,
    required this.servingSize,
    required this.ingredientCount,
    required this.onStartCooking,
  });

  final String mealLabel;
  final String title;
  final int servingSize;
  final int? ingredientCount;
  final VoidCallback onStartCooking;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
        boxShadow: KsTokens.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 108,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.all(KsTokens.space12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(ks.surfaceRaised, KsTokens.catProduce, 0.34)!,
                  Color.lerp(ks.surfaceRaised, KsTokens.catGrain, 0.30)!,
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KsTokens.space10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: KsTokens.brandPrimaryDark,
                borderRadius: BorderRadius.circular(KsTokens.radiusFull),
              ),
              child: Text(
                'Today · $mealLabel'.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: KsTokens.textOnBrand,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KsTokens.displaySmall.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 21,
                    height: 1.12,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: KsTokens.space8),
                Row(
                  children: [
                    Text(
                      'Serves $servingSize',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: KsTokens.space12),
                    Icon(
                      ingredientCount == null
                          ? Icons.menu_book_outlined
                          : Icons.inventory_2_outlined,
                      size: 13,
                      color: KsTokens.fresh,
                    ),
                    const SizedBox(width: KsTokens.space4),
                    Text(
                      ingredientCount == null
                          ? 'Recipe details unavailable'
                          : _ingredientLabel(ingredientCount!),
                      style: KsTokens.labelSmall.copyWith(
                        color: KsTokens.fresh,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KsTokens.space12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStartCooking,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Start cooking'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMealHero extends StatelessWidget {
  const _NoMealHero({required this.onPlanMeal});

  final VoidCallback onPlanMeal;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No meal planned today',
            style: KsTokens.titleLarge.copyWith(color: ks.textPrimary),
          ),
          const SizedBox(height: KsTokens.space6),
          Text(
            "Choose a recipe and add it to today's calendar.",
            style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
          ),
          const SizedBox(height: KsTokens.space12),
          FilledButton.icon(
            onPressed: onPlanMeal,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Plan a meal'),
          ),
        ],
      ),
    );
  }
}

/// A wheat-sprig rule that breaks the urgent hero from the calm stack below.
class _SprigDivider extends StatelessWidget {
  const _SprigDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    final sprig = isDark ? KsTokens.brandAccent : ks.brandPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space2,
        KsTokens.space20,
        KsTokens.space2,
        KsTokens.space16,
      ),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: ks.hairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KsTokens.space10),
            child: Icon(Icons.eco_outlined, size: 14, color: sprig),
          ),
          Expanded(child: Container(height: 1, color: ks.hairline)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: KsTokens.labelSmall.copyWith(
        color: context.ksColors.textTertiary,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1,
      ),
    );
  }
}

/// A single "use soon" nudge — a freshness-barred row with an italic prompt
/// and a days-remaining stamp.
class _UseSoonRow extends StatelessWidget {
  const _UseSoonRow({
    required this.name,
    required this.note,
    required this.daysLabel,
  });

  final String name;
  final String note;
  final String daysLabel;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: KsTokens.expiringSoon),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: KsTokens.titleSmall.copyWith(
                              color: ks.textPrimary,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          Text(
                            note,
                            style: KsTokens.displaySmall.copyWith(
                              color: ks.textSecondary,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KsTokens.space8),
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: KsTokens.expiringSoon,
                    ),
                    const SizedBox(width: KsTokens.space4),
                    Text(
                      daysLabel,
                      style: KsTokens.labelMedium.copyWith(
                        color: KsTokens.lowStock,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UseSoonEmpty extends StatelessWidget {
  const _UseSoonEmpty();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Text(
        'No stocked items have an upcoming expiry date.',
        style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
      ),
    );
  }
}

enum _StatAccent { shopping, brand }

/// A small "by the numbers" card — an oversized Fraunces numeral over a quiet
/// caption.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final _StatAccent accent;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final color = switch (accent) {
      _StatAccent.shopping => ks.calShopping,
      _StatAccent.brand => ks.brandPrimary,
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: KsTokens.displayMedium.copyWith(
              color: color,
              fontSize: 26,
              height: 1,
            ),
          ),
          const SizedBox(height: KsTokens.space3),
          Text(
            label,
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

Object? _firstError(List<AsyncValue<dynamic>> values) {
  for (final value in values) {
    if (value.hasError) return value.error;
  }
  return null;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

MealScheduleEntry? _primaryMeal(List<MealScheduleEntry> meals) {
  final active =
      meals.where((meal) => meal.state != ScheduledMealState.cancelled).toList()
        ..sort((left, right) {
          final state = left.state.index.compareTo(right.state.index);
          if (state != 0) return state;
          return _mealOrder(
            left.mealLabel,
          ).compareTo(_mealOrder(right.mealLabel));
        });
  return active.isEmpty ? null : active.first;
}

int _mealOrder(String label) => switch (label.toLowerCase()) {
  'breakfast' => 0,
  'brunch' => 1,
  'lunch' => 2,
  'snack' => 3,
  'dinner' => 4,
  _ => 5,
};

PantryItem? _firstExpiring(List<PantryItem> items) {
  final expiring =
      items
          .where((item) => item.quantity > 0 && item.expiryDate != null)
          .toList()
        ..sort((left, right) => left.expiryDate!.compareTo(right.expiryDate!));
  return expiring.isEmpty ? null : expiring.first;
}

int? _daysUntilNextShop(List<ShoppingListRecord> lists, DateTime today) {
  final upcoming =
      lists
          .where(
            (list) =>
                list.status == ShoppingListStatus.pending &&
                !_dateOnly(list.shoppingDate).isBefore(today),
          )
          .toList()
        ..sort(
          (left, right) => left.shoppingDate.compareTo(right.shoppingDate),
        );
  if (upcoming.isEmpty) return null;
  return _dateOnly(upcoming.first.shoppingDate).difference(today).inDays;
}

String? _firstName(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}

String _greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _longDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

String _planningSubtitle(DateTime date, int plannedCount) {
  final count = plannedCount == 0
      ? 'no meals planned'
      : '$plannedCount ${plannedCount == 1 ? 'meal' : 'meals'} planned';
  return '${_longDate(date)} · $count';
}

String _ingredientLabel(int ingredientCount) =>
    '$ingredientCount '
    '${ingredientCount == 1 ? 'ingredient' : 'ingredients'} planned';

String _datePath(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _displayId(String value) => value
    .replaceAll(RegExp('[-_]'), ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _expiryNote(DateTime expiry, DateTime today) {
  final days = _dateOnly(expiry).difference(today).inDays;
  if (days < 0) return 'past its expiry date';
  if (days == 0) return 'expires today';
  if (days == 1) return 'expires tomorrow';
  return 'use before ${_longDate(_dateOnly(expiry))}';
}

String _expiryLabel(DateTime expiry, DateTime today) {
  final days = _dateOnly(expiry).difference(today).inDays;
  if (days < 0) return '${days.abs()}d late';
  return '${days}d';
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

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
