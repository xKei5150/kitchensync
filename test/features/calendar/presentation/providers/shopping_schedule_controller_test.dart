import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_controller.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';

class _FakeShoppingScheduleRepository implements ShoppingScheduleRepository {
  ShoppingSchedule? saved;

  @override
  Future<void> save(ShoppingSchedule schedule) async {
    saved = schedule;
  }

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(saved);
}

void main() {
  const householdId = 'household-1';
  const userId = 'user-1';
  final now = DateTime(2026, 7, 1, 8);

  ShoppingScheduleController controller({
    required _FakeShoppingScheduleRepository repository,
    required HouseholdRole role,
    required bool isSoloHousehold,
  }) => ShoppingScheduleController(
    repository: repository,
    householdId: householdId,
    userId: userId,
    role: role,
    isSoloHousehold: isSoloHousehold,
    clock: FakeClock(now),
  );

  test('admin saves the weekly schedule with audit fields', () async {
    final repository = _FakeShoppingScheduleRepository();
    final saved =
        await controller(
          repository: repository,
          role: HouseholdRole.admin,
          isSoloHousehold: false,
        ).save(
          isoWeekday: DateTime.saturday,
          effectiveFrom: DateTime(2026, 7, 4, 17),
          isActive: true,
        );

    expect(saved.householdId, householdId);
    expect(saved.cadence, ShoppingScheduleCadence.weekly);
    expect(saved.effectiveFrom, DateTime(2026, 7, 4));
    expect(saved.createdAt, now);
    expect(saved.updatedAt, now);
    expect(saved.updatedByUserId, userId);
    expect(repository.saved, saved);
  });

  test('solo member can save a schedule', () async {
    final repository = _FakeShoppingScheduleRepository();
    await controller(
      repository: repository,
      role: HouseholdRole.member,
      isSoloHousehold: true,
    ).save(
      isoWeekday: DateTime.saturday,
      effectiveFrom: DateTime(2026, 7, 4),
      isActive: true,
    );

    expect(repository.saved, isNotNull);
  });

  test('replacement preserves createdAt and updates audit ownership', () async {
    final repository = _FakeShoppingScheduleRepository();
    final existing = ShoppingSchedule(
      householdId: householdId,
      cadence: ShoppingScheduleCadence.weekly,
      isoWeekday: DateTime.saturday,
      effectiveFrom: DateTime(2026, 7, 4),
      isActive: true,
      createdAt: DateTime(2026, 6, 1, 9, 30),
      updatedAt: DateTime(2026, 6, 2, 10, 45),
      updatedByUserId: 'former-user',
    );

    final saved =
        await controller(
          repository: repository,
          role: HouseholdRole.admin,
          isSoloHousehold: false,
        ).save(
          existing: existing,
          isoWeekday: DateTime.wednesday,
          effectiveFrom: DateTime(2026, 7, 8),
          isActive: false,
        );

    expect(saved.createdAt, existing.createdAt);
    expect(saved.updatedAt, now);
    expect(saved.updatedByUserId, userId);
  });

  for (final role in [
    HouseholdRole.cook,
    HouseholdRole.shopper,
    HouseholdRole.member,
  ]) {
    test('$role cannot mutate a joint household shopping schedule', () async {
      final repository = _FakeShoppingScheduleRepository();
      final call =
          controller(
            repository: repository,
            role: role,
            isSoloHousehold: false,
          ).save(
            isoWeekday: DateTime.saturday,
            effectiveFrom: DateTime(2026, 7, 4),
            isActive: true,
          );

      await expectLater(call, throwsStateError);
      expect(repository.saved, isNull);
    });
  }

  test('rejects invalid weekday before persisting', () async {
    final repository = _FakeShoppingScheduleRepository();
    final call = controller(
      repository: repository,
      role: HouseholdRole.admin,
      isSoloHousehold: false,
    ).save(isoWeekday: 0, effectiveFrom: DateTime(2026, 7, 4), isActive: true);

    await expectLater(call, throwsArgumentError);
    expect(repository.saved, isNull);
  });
}
