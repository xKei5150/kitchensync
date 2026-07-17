import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_unit_converter.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

abstract final class IngredientPriceEstimator {
  /// Estimates recipe cost from each ingredient's price per default unit.
  /// A manual recipe price remains authoritative when present.
  static double? recipe(
    Recipe recipe,
    Map<String, Ingredient> ingredientsById,
  ) =>
      recipe.priceEstimate ??
      _lines(
        recipe.ingredients.map(
          (line) => (
            ingredientId: line.ingredientId,
            quantity: line.quantity,
            unit: line.unit,
          ),
        ),
        ingredientsById,
      );

  static double? shoppingList(
    ShoppingListPlan plan,
    Map<String, Ingredient> ingredientsById,
  ) => _lines(
    plan.items.map(
      (line) => (
        ingredientId: line.ingredientId,
        quantity: line.quantity,
        unit: line.unit,
      ),
    ),
    ingredientsById,
  );

  static double? _lines(
    Iterable<({String ingredientId, double quantity, UnitId unit})> lines,
    Map<String, Ingredient> ingredientsById,
  ) {
    var total = 0.0;
    var hasLine = false;
    for (final line in lines) {
      final ingredient = ingredientsById[line.ingredientId];
      final price = ingredient?.pricePerUnitHint;
      if (ingredient == null || price == null) return null;
      final quantity = IngredientUnitConverter.convert(
        quantity: line.quantity,
        from: line.unit,
        to: ingredient.defaultUnit,
        localUnitDefinitions: ingredient.localUnitDefinitions,
      );
      if (quantity == null) return null;
      total += quantity * price;
      hasLine = true;
    }
    return hasLine ? total : null;
  }
}
