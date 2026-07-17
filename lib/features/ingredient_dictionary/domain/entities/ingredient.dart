import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/image_attribution.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient_curation.dart';

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
    @UnitIdJsonConverter() required UnitId defaultUnit,
    @UnitIdListJsonConverter() required List<UnitId> allowedUnits,
    @Default(<UnitDefinition>[])
    @UnitDefinitionListJsonConverter()
    List<UnitDefinition> localUnitDefinitions,
    int? defaultShelfLifeDays,
    int? defaultPurchaseIntervalDays,
    double? pricePerUnitHint,
    @Default(false) bool isBulkCandidate,
    @Default(false) bool isNonFood,
    String? imageUrl,
    String? barcode,
    @Default(<String>[]) List<String> aliases,
    @Default(<String>[]) List<String> taxonomyTags,
    @Default(<String>[]) List<String> formTags,
    IngredientCuration? curation,
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
