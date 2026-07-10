import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

part 'purchase_record.freezed.dart';
part 'purchase_record.g.dart';

@freezed
class PurchaseRecord with _$PurchaseRecord {
  const factory PurchaseRecord({
    required String id,
    required String householdId,
    required String ingredientId,
    required double quantity,
    @UnitIdJsonConverter() required UnitId unit,
    required DateTime purchaseDate,
    String? sourceShoppingListId,
    @Default(false) bool isBulk,
    @Default(false) bool isNonFood,
    @Default(1) int schemaVersion,
  }) = _PurchaseRecord;

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) =>
      _$PurchaseRecordFromJson(json);
}
