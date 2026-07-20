// SIZE_OK: recipe detail screen keeps the existing full recipe view surface.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/services/calendar_day_settings_resolver.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_price_estimator.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_social_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipes_screen.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

part 'recipe_detail_body.dart';
part 'recipe_detail_hero.dart';
part 'recipe_detail_schedule.dart';
part 'recipe_detail_schedule_helpers.dart';
part 'recipe_detail_schedule_primitives.dart';
part 'recipe_detail_intro.dart';
part 'recipe_detail_social.dart';

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
          final household = ref.watch(activeHouseholdContextProvider);
          const policy = HouseholdPolicy();
          final belongsToActiveHousehold = household?.id == recipe.householdId;
          final canEdit =
              belongsToActiveHousehold &&
              policy.roleCan(
                household!.role,
                HouseholdCapability.editRecipes,
                isSoloHousehold: household.isSolo,
              );
          final canDelete =
              belongsToActiveHousehold &&
              policy.roleCan(
                household!.role,
                HouseholdCapability.deleteRecipes,
                isSoloHousehold: household.isSolo,
              );
          final canSchedule =
              household != null &&
              policy.roleCan(
                household.role,
                HouseholdCapability.scheduleMeals,
                isSoloHousehold: household.isSolo,
              );
          final savedRecipe = recipe.visibility == RecipeVisibility.public
              ? ref.watch(savedRecipeForSourceProvider(recipe.id))
              : ref.watch(savedRecipeForLocalCopyProvider(recipe.id));
          return FutureBuilder<Map<String, Ingredient>>(
            future: _ingredientsById(ref, recipe),
            builder: (context, snapshot) {
              final ingredientsById =
                  snapshot.data ?? const <String, Ingredient>{};
              return _RecipeDetailBody(
                recipeId: recipe.id,
                title: recipe.name,
                author: authorLabel(
                  recipe.authorUserId,
                  ref.watch(activeUserIdProvider),
                ),
                location: recipe.location,
                intro: recipe.description.isEmpty
                    ? recipe.name
                    : recipe.description,
                baseServings: recipe.defaultServingSize,
                ingredients: recipe.ingredients
                    .map(
                      (ingredient) => _scaledIngredient(
                        context,
                        recipe.householdId,
                        ingredient,
                        ingredientsById[ingredient.ingredientId],
                      ),
                    )
                    .toList(growable: false),
                tags: [...recipe.mealTimeTags, ...recipe.recipeTags],
                priceEstimate: IngredientPriceEstimator.recipe(
                  recipe,
                  ingredientsById,
                ),
                instructions: recipe.instructions,
                isPublic: recipe.visibility == RecipeVisibility.public,
                youtubeUrl: recipe.youtubeEmbedUrl,
                saved: savedRecipe != null,
                canSchedule: canSchedule,
                onEdit: canEdit
                    ? () => _editRecipe(context, ref, recipe)
                    : null,
                onDelete: canDelete && savedRecipe == null
                    ? () => _deleteRecipe(context, ref, recipe)
                    : null,
                onToggleSaved:
                    recipe.visibility == RecipeVisibility.public ||
                        savedRecipe != null
                    ? () => _toggleSaved(context, ref, recipe, savedRecipe)
                    : null,
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
      author: 'KitchenSync',
      location: '',
      intro: _intro,
      baseServings: 4,
      ingredients: _ingredients,
      tags: const ['Vegetarian'],
      instructions: const [],
      isPublic: false,
      saved: false,
      canSchedule: true,
      onBack: () => context.pop(),
    );
  }

  static Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    SavedRecipe? savedRecipe,
  ) async {
    try {
      if (savedRecipe == null) {
        await ref
            .read(recipeDiscoveryControllerProvider)
            .savePublicRecipe(recipe);
      } else {
        await ref
            .read(recipeDiscoveryControllerProvider)
            .unsavePublicRecipe(savedRecipe);
      }
      ref.invalidate(activeHouseholdRecipesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedRecipe == null
                ? '${recipe.name} saved to My Recipes'
                : '${recipe.name} removed from My Recipes',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update saved recipe: $error')),
      );
    }
  }

  static Future<void> _editRecipe(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final result = await showRecipeEditorSheet(context, existingRecipe: recipe);
    if (result == null || result.drafts.isEmpty) return;
    try {
      final updated = await ref
          .read(recipeLibraryControllerProvider)
          .updateLocalRecipe(recipe: recipe, draft: result.drafts.single);
      ref
        ..invalidate(recipeRecordProvider(recipe.id))
        ..invalidate(activeHouseholdRecipesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${updated.name} updated')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update recipe: $error')),
      );
    }
  }

  static Future<void> _deleteRecipe(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    try {
      await ref.read(recipeLibraryControllerProvider).deleteLocalRecipe(recipe);
      ref.invalidate(activeHouseholdRecipesProvider);
      if (!context.mounted) return;
      context.pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete recipe: $error')),
      );
    }
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
    BuildContext context,
    String householdId,
    RecipeIngredient ingredient,
    Ingredient? linkedIngredient,
  ) {
    return KsScalableIngredient(
      // Prefer the recipe's own note, then the dictionary's display name,
      // and only fall back to the raw id if neither is available.
      name:
          ingredient.description ??
          linkedIngredient?.name ??
          _humanizeId(ingredient.ingredientId),
      baseAmount: ingredient.quantity,
      unit: _unitLabel(
        ingredient.unit,
        ingredient.quantity,
        linkedIngredient?.localUnitDefinitions ?? const [],
      ),
      onTap: () => context.push(
        '/ingredient/${ingredient.ingredientId}'
        '?householdId=${Uri.encodeQueryComponent(householdId)}',
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

  /// Turns a kebab-case ingredient id ("baby-spinach") into a readable label
  /// ("Baby spinach") as a last resort when no dictionary name is available.
  static String _humanizeId(String id) {
    final words = id.replaceAll('-', ' ').trim();
    if (words.isEmpty) return id;
    return words[0].toUpperCase() + words.substring(1);
  }

  /// A friendly byline: your own recipes read "You"; an opaque uid author with
  /// no resolvable display name reads "A KitchenSync cook" rather than a uid.
  static String authorLabel(String authorUserId, String currentUserId) {
    if (authorUserId == currentUserId) return 'You';
    final looksLikeUid =
        authorUserId.length >= 20 && !authorUserId.contains(' ');
    return looksLikeUid ? 'A KitchenSync cook' : authorUserId;
  }
}
