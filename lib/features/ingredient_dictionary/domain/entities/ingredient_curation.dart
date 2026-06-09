import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient_curation.freezed.dart';
part 'ingredient_curation.g.dart';

@freezed
class IngredientCuration with _$IngredientCuration {
  const factory IngredientCuration({
    required String status,
    required double confidence,
    required String source,
    required String notes,
  }) = _IngredientCuration;

  factory IngredientCuration.fromJson(Map<String, dynamic> json) =>
      _$IngredientCurationFromJson(json);
}
