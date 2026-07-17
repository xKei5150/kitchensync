import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';

abstract class ShoppingScheduleRepository {
  Stream<ShoppingSchedule?> watch(String householdId);

  Future<void> save(ShoppingSchedule schedule);
}
