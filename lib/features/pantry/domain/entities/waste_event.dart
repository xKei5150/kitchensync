import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';

part 'waste_event.freezed.dart';
part 'waste_event.g.dart';

@freezed
class WasteEvent with _$WasteEvent {
  const factory WasteEvent({
    required String id,
    required String householdId,
    required String pantryItemId,
    required String ingredientId,
    required double quantity,
    required Unit unit,
    required WasteReason reason,
    required DateTime date,
    String? note,
    @Default(1) int schemaVersion,
  }) = _WasteEvent;

  factory WasteEvent.fromJson(Map<String, dynamic> json) =>
      _$WasteEventFromJson(json);
}
