import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/image_attribution.dart';

part 'ingredient.freezed.dart';
part 'ingredient.g.dart';

@freezed
class Ingredient with _$Ingredient {
  const factory Ingredient({
    required String id,
    required String name,
    required Map<String, String> displayNames,
    String? parentIngredientId,
    required IngredientCategory category,
    required Unit defaultUnit,
    required List<Unit> allowedUnits,
    int? defaultShelfLifeDays,
    @Default(false) bool isBulkCandidate,
    @Default(false) bool isNonFood,
    String? imageUrl,
    String? barcode,
    @Default(<String>[]) List<String> aliases,
    @Default(<String>[]) List<String> searchTokens,
    @Default(<Allergen>[]) List<Allergen> allergens,
    @Default(<DietaryTag>[]) List<DietaryTag> dietaryTags,
    @Default(<String>[]) List<String> substituteIngredientIds,
    ImageAttribution? imageAttribution,
    required IngredientScope scope,
    String? householdId,
    @Default(1) int schemaVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Ingredient;

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);
}
