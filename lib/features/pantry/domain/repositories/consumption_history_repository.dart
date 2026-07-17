import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';

abstract class ConsumptionHistoryRepository {
  Stream<List<ConsumptionEvent>> watchByHousehold(String householdId);
  Future<void> add(ConsumptionEvent event);
}
