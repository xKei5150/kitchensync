part of 'design_tokens.dart';

/// Freshness status used across pantry tiles, badges, and detail screens.
enum Freshness { fresh, expiringSoon, expired, unknown }

/// Extension that maps [Freshness] to its semantic color and label.
extension FreshnessX on Freshness {
  Color get color => switch (this) {
    Freshness.fresh => KsTokens.fresh,
    Freshness.expiringSoon => KsTokens.expiringSoon,
    Freshness.expired => KsTokens.expired,
    Freshness.unknown => KsTokens.textTertiary,
  };

  String get label => switch (this) {
    Freshness.fresh => 'Fresh',
    Freshness.expiringSoon => 'Expiring soon',
    Freshness.expired => 'Expired',
    Freshness.unknown => '',
  };

  /// A redundant, non-colour glyph for each state so freshness never travels
  /// by colour alone (accessibility). Pairs with the edge-bar + day-count in
  /// freshness badges — see "Components I (Primitives)", Freshness indicators.
  IconData get icon => switch (this) {
    Freshness.fresh => Icons.check_circle_outline,
    Freshness.expiringSoon => Icons.schedule,
    Freshness.expired => Icons.warning_amber_rounded,
    Freshness.unknown => Icons.help_outline,
  };
}

/// Maps [IngredientCategory] to its brand color for tiles and badges.
extension IngredientCategoryColor on IngredientCategory {
  Color get color => switch (this) {
    IngredientCategory.produce => KsTokens.catProduce,
    IngredientCategory.meat => KsTokens.catMeat,
    IngredientCategory.seafood => KsTokens.catSeafood,
    IngredientCategory.dairy => KsTokens.catDairy,
    IngredientCategory.grain => KsTokens.catGrain,
    IngredientCategory.bakery => KsTokens.catBakery,
    IngredientCategory.spice => KsTokens.catSpice,
    IngredientCategory.condiment => KsTokens.catCondiment,
    IngredientCategory.baking => KsTokens.catBaking,
    IngredientCategory.beverage => KsTokens.catBeverage,
    IngredientCategory.frozen => KsTokens.catFrozen,
    IngredientCategory.bulkStaple => KsTokens.catBulkStaple,
    IngredientCategory.nonFood => KsTokens.catNonFood,
    IngredientCategory.other => KsTokens.catOther,
  };

  /// Luminance-lifted variant for the dark walnut surface.
  Color get darkColor => switch (this) {
    IngredientCategory.produce => KsTokens.catProduceDark,
    IngredientCategory.meat => KsTokens.catMeatDark,
    IngredientCategory.seafood => KsTokens.catSeafoodDark,
    IngredientCategory.dairy => KsTokens.catDairyDark,
    IngredientCategory.grain => KsTokens.catGrainDark,
    IngredientCategory.bakery => KsTokens.catBakeryDark,
    IngredientCategory.spice => KsTokens.catSpiceDark,
    IngredientCategory.condiment => KsTokens.catCondimentDark,
    IngredientCategory.baking => KsTokens.catBakingDark,
    IngredientCategory.beverage => KsTokens.catBeverageDark,
    IngredientCategory.frozen => KsTokens.catFrozenDark,
    IngredientCategory.bulkStaple => KsTokens.catBulkStapleDark,
    IngredientCategory.nonFood => KsTokens.catNonFoodDark,
    IngredientCategory.other => KsTokens.catOtherDark,
  };

  /// Theme-aware category hue: the light tint on light surfaces, the
  /// luminance-lifted [darkColor] on dark surfaces.
  Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : color;
}

/// Maps [PantrySection] to its brand color for tabs and headers.
extension PantrySectionColor on PantrySection {
  Color get color => switch (this) {
    PantrySection.food => KsTokens.sectionFood,
    PantrySection.bulk => KsTokens.sectionBulk,
    PantrySection.nonFood => KsTokens.sectionNonFood,
    PantrySection.leftover => KsTokens.sectionLeftover,
  };
}
