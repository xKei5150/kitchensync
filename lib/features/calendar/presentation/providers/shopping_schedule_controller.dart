import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';

class ShoppingScheduleController {
  const ShoppingScheduleController({
    required this.repository,
    required this.householdId,
    required this.userId,
    required this.role,
    required this.isSoloHousehold,
    required this.clock,
  });

  final ShoppingScheduleRepository repository;
  final String householdId;
  final String userId;
  final HouseholdRole role;
  final bool isSoloHousehold;
  final Clock clock;
  static const _policy = HouseholdPolicy();

  Future<ShoppingSchedule> save({
    ShoppingSchedule? existing,
    required int isoWeekday,
    required DateTime effectiveFrom,
    required bool isActive,
  }) async {
    _requireManageSchedule();
    final now = clock.now();
    final schedule = ShoppingSchedule(
      householdId: householdId,
      cadence: ShoppingScheduleCadence.weekly,
      isoWeekday: isoWeekday,
      effectiveFrom: effectiveFrom,
      isActive: isActive,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      updatedByUserId: userId,
    );
    await repository.save(schedule);
    return schedule;
  }

  void _requireManageSchedule() {
    if (!_policy.roleCan(
      role,
      HouseholdCapability.manageShoppingSchedules,
      isSoloHousehold: isSoloHousehold,
    )) {
      throw StateError('${role.label} cannot manage shopping schedules.');
    }
  }
}
