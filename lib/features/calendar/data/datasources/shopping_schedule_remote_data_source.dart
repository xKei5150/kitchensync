import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/calendar/data/dtos/shopping_schedule_dto.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';

class ShoppingScheduleRemoteDataSource {
  ShoppingScheduleRemoteDataSource(this._refs);

  final FirestoreRefs _refs;

  Stream<ShoppingSchedule?> watch(String householdId) => _refs
      .weeklyShoppingSchedule(householdId)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists
            ? ShoppingScheduleMapper.fromMap(
                snapshot.data()!,
                expectedHouseholdId: householdId,
              )
            : null,
      );

  Future<void> save(ShoppingSchedule schedule) => _refs
      .weeklyShoppingSchedule(schedule.householdId)
      .set(ShoppingScheduleMapper.toMap(schedule));
}
