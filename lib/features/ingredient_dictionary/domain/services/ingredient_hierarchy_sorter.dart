import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

class IngredientHierarchySorter {
  const IngredientHierarchySorter._();

  static List<Ingredient> parentBeforeChildren(List<Ingredient> ingredients) {
    final byId = {for (final ingredient in ingredients) ingredient.id: ingredient};
    final childrenByParent = <String, List<Ingredient>>{};
    final roots = <Ingredient>[];

    for (final ingredient in ingredients) {
      final parentId = ingredient.parentIngredientId;
      if (parentId != null && byId.containsKey(parentId)) {
        childrenByParent.putIfAbsent(parentId, () => <Ingredient>[]).add(ingredient);
      } else {
        roots.add(ingredient);
      }
    }

    roots.sort(_byNameThenId);
    for (final children in childrenByParent.values) {
      children.sort(_byNameThenId);
    }

    final output = <Ingredient>[];
    final emitted = <String>{};
    void emit(Ingredient ingredient) {
      if (!emitted.add(ingredient.id)) return;
      output.add(ingredient);
      for (final child in childrenByParent[ingredient.id] ?? const <Ingredient>[]) {
        emit(child);
      }
    }

    for (final root in roots) {
      emit(root);
    }
    for (final ingredient in ingredients.toList()..sort(_byNameThenId)) {
      emit(ingredient);
    }
    return output;
  }

  static int _byNameThenId(Ingredient a, Ingredient b) {
    final nameCompare = a.name.compareTo(b.name);
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }
}
