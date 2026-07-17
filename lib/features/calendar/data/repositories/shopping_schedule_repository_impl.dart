import 'package:kitchensync/features/calendar/data/datasources/shopping_schedule_remote_data_source.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';

class ShoppingScheduleRepositoryImpl implements ShoppingScheduleRepository {
  ShoppingScheduleRepositoryImpl(this._remote);

  final ShoppingScheduleRemoteDataSource _remote;

  @override
  Stream<ShoppingSchedule?> watch(String householdId) =>
      _remote.watch(householdId);

  @override
  Future<void> save(ShoppingSchedule schedule) => _remote.save(schedule);
}
