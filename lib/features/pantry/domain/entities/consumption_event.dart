import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

part 'consumption_event.freezed.dart';
part 'consumption_event.g.dart';

enum ConsumptionSource { cooking, manual, leftover }

@freezed
class ConsumptionEvent with _$ConsumptionEvent {
  const factory ConsumptionEvent({
    required String id,
    required String householdId,
    required String pantryItemId,
    required String ingredientId,
    required double quantity,
    @UnitIdJsonConverter() required UnitId unit,
    required ConsumptionSource source,
    String? sourceMealId,
    required DateTime date,
    @Default(1) int schemaVersion,
  }) = _ConsumptionEvent;

  factory ConsumptionEvent.fromJson(Map<String, dynamic> json) =>
      _$ConsumptionEventFromJson(json);
}
