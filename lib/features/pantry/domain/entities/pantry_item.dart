import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';

part 'pantry_item.freezed.dart';
part 'pantry_item.g.dart';

@freezed
class PantryItem with _$PantryItem {
  const factory PantryItem({
    required String id,
    required String householdId,
    required String ingredientId,
    required double quantity,
    @UnitIdJsonConverter() required UnitId unit,
    required PantrySection section,
    String? imageUrl,
    String? note,
    String? relatedRecipeId,
    int? leftoverServings,
    DateTime? lastPurchaseDate,
    DateTime? expiryDate,
    DateTime? openedAt,
    @Default(1) int schemaVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PantryItem;

  factory PantryItem.fromJson(Map<String, dynamic> json) =>
      _$PantryItemFromJson(json);
}
