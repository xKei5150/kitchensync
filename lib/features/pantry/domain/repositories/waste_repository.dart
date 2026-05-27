import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

abstract class WasteRepository {
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  });
  Future<void> log(WasteEvent event);
}
