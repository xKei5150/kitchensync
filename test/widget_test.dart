import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';

TodaySnapshot _snapshot() {
  final now = DateTime(2026, 7, 6, 19);
  final recipe = Recipe(
    id: 'braise',
    authorUserId: 'ana',
    householdId: 'household-1',
    name: 'Tomato & white bean braise',
    description: '',
    defaultServingSize: 4,
    mealTimeTags: const ['Dinner'],
    recipeTags: const [],
    location: 'Home',
    visibility: RecipeVisibility.private,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: const [
      RecipeIngredient(
        id: 'ingredient-1',
        recipeId: 'braise',
        ingredientId: 'white-beans',
        quantity: 2,
        unit: UnitId.tin,
      ),
    ],
    instructions: const [],
  );
  return TodaySnapshot(
    now: now,
    householdName: 'Shared kitchen',
    userDisplayName: 'Ana Santos',
    meals: [
      MealScheduleEntry(
        id: 'meal-1',
        recipeId: recipe.id,
        date: DateTime(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 4,
      ),
    ],
    recipes: [recipe],
    pantryItems: [
      PantryItem(
        id: 'pantry-1',
        householdId: 'household-1',
        ingredientId: 'spinach',
        quantity: 1,
        unit: UnitId.bunch,
        section: PantrySection.food,
        expiryDate: DateTime(2026, 7, 7),
        createdAt: now,
        updatedAt: now,
      ),
    ],
    shoppingLists: [
      ShoppingListRecord(
        id: 'list-1',
        householdId: 'household-1',
        type: ShoppingListType.scheduled,
        shoppingDate: DateTime(2026, 7, 8),
        generatedForRangeStart: DateTime(2026, 7, 8),
        generatedForRangeEnd: DateTime(2026, 7, 14),
        status: ShoppingListStatus.pending,
        createdAt: now,
        updatedAt: now,
        items: const [],
      ),
    ],
    wasteEvents: [
      WasteEvent(
        id: 'waste-1',
        householdId: 'household-1',
        pantryItemId: 'old-spinach',
        ingredientId: 'spinach',
        quantity: 1,
        unit: UnitId.bunch,
        reason: WasteReason.spoiled,
        date: DateTime(2026, 7, 5),
      ),
    ],
  );
}

Widget _app({required ThemeData theme, TodaySnapshot? snapshot}) =>
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: TodayScreen(snapshot: snapshot ?? _snapshot()),
      ),
    );

void main() {
  testWidgets('TodayScreen renders persisted household summary data', (
    tester,
  ) async {
    await tester.pumpWidget(_app(theme: AppTheme.light()));

    expect(find.text('Good evening, Ana'), findsOneWidget);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
    expect(find.text('Spinach'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Start cooking'), findsOneWidget);
    expect(find.text('Use soon'.toUpperCase()), findsOneWidget);
  });

  testWidgets('TodayScreen renders honest empty states', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: AppTheme.light(),
        snapshot: TodaySnapshot.empty(now: DateTime(2026, 7, 6, 9)),
      ),
    );

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('No meal planned today'), findsOneWidget);
    expect(
      find.text('No stocked items have an upcoming expiry date.'),
      findsOneWidget,
    );
    expect(find.text('no upcoming shop'), findsOneWidget);
  });

  testWidgets('TodayScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(_app(theme: AppTheme.dark()));

    expect(tester.takeException(), isNull);
    expect(find.text('Good evening, Ana'), findsOneWidget);
  });
}
