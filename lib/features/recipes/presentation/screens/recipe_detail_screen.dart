// SIZE_OK: recipe detail screen keeps the existing full recipe view surface.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

part 'recipe_detail_body.dart';
part 'recipe_detail_hero.dart';
part 'recipe_detail_schedule.dart';
part 'recipe_detail_schedule_helpers.dart';
part 'recipe_detail_schedule_primitives.dart';
part 'recipe_detail_intro.dart';

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
          return FutureBuilder<Map<String, Ingredient>>(
            future: _ingredientsById(ref, recipe),
            builder: (context, snapshot) {
              final ingredientsById =
                  snapshot.data ?? const <String, Ingredient>{};
              return _RecipeDetailBody(
                recipeId: recipe.id,
                title: recipe.name,
                intro: recipe.description.isEmpty
                    ? recipe.name
                    : recipe.description,
                baseServings: recipe.defaultServingSize,
                ingredients: recipe.ingredients
                    .map(
                      (ingredient) => _scaledIngredient(
                        ingredient,
                        ingredientsById[ingredient.ingredientId],
                      ),
                    )
                    .toList(growable: false),
                tags: [...recipe.mealTimeTags, ...recipe.recipeTags],
                priceEstimate: recipe.priceEstimate,
                instructions: recipe.instructions,
                onBack: () => context.pop(),
              );
            },
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

  static Future<Map<String, Ingredient>> _ingredientsById(
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final repository = ref.read(ingredientRepositoryProvider);
    final byId = <String, Ingredient>{};
    for (final ingredient in recipe.ingredients) {
      final id = ingredient.ingredientId;
      if (byId.containsKey(id)) continue;
      final linked = await repository.getById(
        id,
        householdId: recipe.householdId,
      );
      if (linked != null) byId[id] = linked;
    }
    return byId;
  }

  static KsScalableIngredient _scaledIngredient(
    RecipeIngredient ingredient,
    Ingredient? linkedIngredient,
  ) {
    return KsScalableIngredient(
      name: ingredient.description ?? ingredient.ingredientId,
      baseAmount: ingredient.quantity,
      unit: _unitLabel(
        ingredient.unit,
        ingredient.quantity,
        linkedIngredient?.localUnitDefinitions ?? const [],
      ),
    );
  }

  static String _unitLabel(
    UnitId unit,
    double quantity,
    List<UnitDefinition> localUnitDefinitions,
  ) {
    final definition =
        UnitRegistry.find(unit) ??
        _localUnitDefinition(unit, localUnitDefinitions);
    if (definition == null) return unit.value;
    return quantity == 1 ? definition.label : definition.pluralLabel;
  }

  static UnitDefinition? _localUnitDefinition(
    UnitId unit,
    List<UnitDefinition> localUnitDefinitions,
  ) {
    for (final definition in localUnitDefinitions) {
      if (definition.id == unit) return definition;
    }
    return null;
  }
}
