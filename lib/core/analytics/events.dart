/// Centralized Firebase Analytics event names.
/// Keep names snake_case; never log PII (e.g., ingredient names).
class AnalyticsEvents {
  const AnalyticsEvents._();

  static const pantryItemAdded = 'pantry_item_added';
  static const pantryItemWasted = 'pantry_item_wasted';
  static const pantryItemQuantityAdjusted = 'pantry_item_quantity_adjusted';
  static const pantryItemPhotoUpdated = 'pantry_item_photo_updated';
  static const ingredientCreatedCustom = 'ingredient_created_custom';
  static const dictionarySeeded = 'dictionary_seeded';
  static const dictionarySearchPerformed = 'dictionary_search_performed';
}

class AnalyticsParams {
  const AnalyticsParams._();

  static const section = 'section';
  static const ingredientCategory = 'ingredient_category';
  static const wasteReason = 'waste_reason';
  static const resultCount = 'result_count';
}
