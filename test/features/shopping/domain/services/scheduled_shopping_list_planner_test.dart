import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';

void main() {
  const planner = ScheduledShoppingListPlanner();

  ShoppingSchedule schedule({
    int isoWeekday = DateTime.saturday,
    DateTime? effectiveFrom,
  }) => ShoppingSchedule(
    householdId: 'household-1',
    cadence: ShoppingScheduleCadence.weekly,
    isoWeekday: isoWeekday,
    effectiveFrom: effectiveFrom ?? DateTime(2026, 7, 4),
    isActive: true,
    createdAt: DateTime(2026, 7),
    updatedAt: DateTime(2026, 7),
    updatedByUserId: 'user-1',
  );

  test(
    'deduplicates and sorts weekly occurrences across overlapping ranges',
    () {
      final occurrences = planner.occurrencesForRanges(
        schedule: schedule(),
        ranges: [
          ScheduledShoppingRange(
            start: DateTime(2026, 7, 4),
            end: DateTime(2026, 7, 10),
          ),
          ScheduledShoppingRange(
            start: DateTime(2026, 7, 6),
            end: DateTime(2026, 7, 18),
          ),
        ],
      );

      expect(occurrences, [
        DateTime(2026, 7, 4),
        DateTime(2026, 7, 11),
        DateTime(2026, 7, 18),
      ]);
    },
  );

  test(
    'plans a date-normalized scheduled list for the prior six-day window',
    () {
      final plan = planner.planForOccurrence(
        schedule: schedule(),
        occurrence: DateTime(2026, 7, 11, 14),
        meals: [
          MealScheduleEntry(
            id: 'meal-1',
            recipeId: 'recipe-1',
            date: DateTime(2026, 7, 9),
            mealLabel: 'Dinner',
            servingSize: 2,
          ),
        ],
        recipesById: const {
          'recipe-1': PlannedRecipe(
            id: 'recipe-1',
            title: 'Tomato soup',
            defaultServingSize: 2,
            ingredients: [
              RecipeIngredientRequirement(
                ingredientId: 'tomato',
                quantity: 400,
                unit: UnitId.g,
              ),
            ],
          ),
        },
        pantryItems: [
          PantryItem(
            id: 'pantry-1',
            householdId: 'household-1',
            ingredientId: 'tomato',
            quantity: 100,
            unit: UnitId.g,
            section: PantrySection.food,
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
          ),
        ],
      );

      expect(plan.id, 'scheduled_weekly_20260711');
      expect(plan.type, ShoppingListType.scheduled);
      expect(plan.startDate, DateTime(2026, 7, 5));
      expect(plan.endDate, DateTime(2026, 7, 11));
      expect(plan.items, hasLength(1));
      expect(plan.items.single.ingredientId, 'tomato');
      expect(plan.items.single.quantity, 300);
    },
  );

  test(
    'clips the first occurrence to effectiveFrom and excludes earlier meals',
    () {
      final plan = planner.planForOccurrence(
        schedule: schedule(effectiveFrom: DateTime(2026, 7, 8)),
        occurrence: DateTime(2026, 7, 11, 14),
        meals: [
          MealScheduleEntry(
            id: 'before-effective',
            recipeId: 'recipe-1',
            date: DateTime(2026, 7, 7),
            mealLabel: 'Dinner',
            servingSize: 2,
          ),
          MealScheduleEntry(
            id: 'after-effective',
            recipeId: 'recipe-1',
            date: DateTime(2026, 7, 9),
            mealLabel: 'Dinner',
            servingSize: 2,
          ),
        ],
        recipesById: const {
          'recipe-1': PlannedRecipe(
            id: 'recipe-1',
            title: 'Tomato soup',
            defaultServingSize: 2,
            ingredients: [
              RecipeIngredientRequirement(
                ingredientId: 'tomato',
                quantity: 400,
                unit: UnitId.g,
              ),
            ],
          ),
        },
        pantryItems: const [],
      );

      expect(plan.startDate, DateTime(2026, 7, 8));
      expect(plan.items.single.quantity, 400);
      expect(
        plan.items.single.sourceMealLinks.single.mealEntryId,
        'after-effective',
      );
    },
  );
}
