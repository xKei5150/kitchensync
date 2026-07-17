part of 'shopping_engine.dart';

class _RequirementBucket {
  _RequirementBucket(this.ingredientId, this.unit);
  final String ingredientId;
  final UnitId unit;
  double quantity = 0;
  final List<MealSourceLink> sourceMealLinks = [];

  void add(MealSourceLink link) {
    quantity += link.quantity;
    sourceMealLinks.add(link);
  }

  List<MealSourceLink> deficitSourceMealLinks({
    required double available,
    required double roundedDeficit,
    required double Function(double) roundQuantity,
  }) {
    final ordered = sourceMealLinks.toList()
      ..sort((left, right) {
        final dateComparison = left.date.compareTo(right.date);
        return dateComparison != 0
            ? dateComparison
            : left.mealEntryId.compareTo(right.mealEntryId);
      });
    var pantryRemaining = available;
    final deficitLinks = <MealSourceLink>[];
    for (final link in ordered) {
      if (pantryRemaining >= link.quantity) {
        pantryRemaining -= link.quantity;
        continue;
      }
      final deficitQuantity = link.quantity - pantryRemaining;
      pantryRemaining = 0;
      deficitLinks.add(
        MealSourceLink(
          mealEntryId: link.mealEntryId,
          recipeId: link.recipeId,
          date: link.date,
          quantity: deficitQuantity,
        ),
      );
    }
    final roundedDeficitLinks = deficitLinks
        .map((link) => (link: link, quantity: roundQuantity(link.quantity)))
        .where((entry) => entry.quantity > 0)
        .toList();
    if (roundedDeficitLinks.isEmpty) {
      roundedDeficitLinks.add((link: deficitLinks.first, quantity: 0));
    }
    var roundedRemaining = roundedDeficit;
    final roundedLinks = <MealSourceLink>[];
    for (var index = 0; index < roundedDeficitLinks.length; index++) {
      final entry = roundedDeficitLinks[index];
      final quantity = index == roundedDeficitLinks.length - 1
          ? roundedRemaining
          : entry.quantity.clamp(0, roundedRemaining).toDouble();
      if (quantity <= 0) {
        continue;
      }
      roundedRemaining -= quantity;
      roundedLinks.add(
        MealSourceLink(
          mealEntryId: entry.link.mealEntryId,
          recipeId: entry.link.recipeId,
          date: entry.link.date,
          quantity: quantity,
        ),
      );
    }
    return roundedLinks;
  }
}
