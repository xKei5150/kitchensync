import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_reconciler.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';

const householdId = 'household-1';

void main() {
  final occurrence = DateTime(2026, 7, 11);
  final schedule = ShoppingSchedule(
    householdId: householdId,
    cadence: ShoppingScheduleCadence.weekly,
    isoWeekday: DateTime.saturday,
    effectiveFrom: DateTime(2026, 7, 4),
    isActive: true,
    createdAt: DateTime(2026, 7, 4),
    updatedAt: DateTime(2026, 7, 4),
    updatedByUserId: 'user-1',
  );

  test(
    'submits scheduled typed intent without client list or draft identifiers',
    () async {
      final backend = _Backend(const []);

      await _reconciler(backend).reconcile(
        schedule: schedule,
        ranges: [
          ScheduledShoppingRange(start: DateTime(2026, 7, 9), end: occurrence),
        ],
      );

      final command = backend.commands.single;
      expect(command.commandId, 'command-1');
      expect(command.intent, isA<ScheduledShoppingAllocationIntent>());
      final intent = switch (command.intent) {
        final ScheduledShoppingAllocationIntent value => value,
        _ => throw StateError('Expected scheduled shopping intent.'),
      };
      expect(intent.householdId, householdId);
      expect(intent.startDate, DateTime(2026, 7, 5));
      expect(intent.endDate, occurrence);
      expect(intent.occurrenceDate, occurrence);
      expect(intent.scheduleKey, 'weekly-6-2026-07-04');
    },
  );

  test('does not submit an allocation when the server-derived canonical list '
      'exists', () async {
    final backend = _Backend([_scheduledRecord(occurrence)]);

    await _reconciler(backend).reconcile(
      schedule: schedule,
      ranges: [
        ScheduledShoppingRange(start: DateTime(2026, 7, 9), end: occurrence),
      ],
    );

    expect(backend.commands, isEmpty);
  });

  test('does not recreate a cancelled scheduled occurrence', () async {
    final cancelled = _scheduledRecord(occurrence, cancelled: true);
    final backend = _Backend([cancelled]);

    await _reconciler(backend).reconcile(
      schedule: schedule,
      ranges: [
        ScheduledShoppingRange(start: DateTime(2026, 7, 9), end: occurrence),
      ],
    );

    expect(backend.commands, isEmpty);
  });

  test('does not submit an allocation for inactive schedules', () async {
    final backend = _Backend(const []);

    await _reconciler(backend).reconcile(
      schedule: ShoppingSchedule(
        householdId: householdId,
        cadence: schedule.cadence,
        isoWeekday: schedule.isoWeekday,
        effectiveFrom: schedule.effectiveFrom,
        isActive: false,
        createdAt: schedule.createdAt,
        updatedAt: schedule.updatedAt,
        updatedByUserId: schedule.updatedByUserId,
      ),
      ranges: [
        ScheduledShoppingRange(start: DateTime(2026, 7, 9), end: occurrence),
      ],
    );

    expect(backend.commands, isEmpty);
  });

  test('suppresses a duplicate in-flight scheduled allocation', () async {
    final backend = _Backend(const [])..block = Completer<void>();
    final reconciler = _reconciler(backend);
    final first = reconciler.reconcile(
      schedule: schedule,
      ranges: [
        ScheduledShoppingRange(start: DateTime(2026, 7, 9), end: occurrence),
      ],
    );
    await backend.started.future;
    await reconciler.reconcile(
      schedule: schedule,
      ranges: [
        ScheduledShoppingRange(start: DateTime(2026, 7, 9), end: occurrence),
      ],
    );
    backend.block!.complete();
    await first;

    expect(backend.commands, hasLength(1));
  });
}

ScheduledShoppingListReconciler _reconciler(_Backend backend) =>
    ScheduledShoppingListReconciler(
      shoppingRepository: _ReadRepository(backend.records),
      writeCoordinator: ShoppingWriteCoordinator(
        repository: backend,
        householdId: householdId,
        idGenerator: _Ids(),
      ),
      calendarRepository: _UnsupportedCalendarRepository(),
      recipeRepository: _UnsupportedRecipeRepository(),
      pantryRepository: _UnsupportedPantryRepository(),
      householdId: householdId,
      clock: FakeClock(DateTime(2026, 7, 6)),
    );

ShoppingListRecord _scheduledRecord(DateTime date, {bool cancelled = false}) =>
    ShoppingListRecord(
      id: ShoppingListRecord.weeklyOccurrenceListId(date),
      householdId: householdId,
      type: ShoppingListType.scheduled,
      shoppingDate: date,
      generatedForRangeStart: date,
      generatedForRangeEnd: date,
      status: cancelled
          ? ShoppingListStatus.cancelled
          : ShoppingListStatus.pending,
      createdAt: date,
      updatedAt: date,
      items: const [],
    );

class _Ids implements IdGenerator {
  var _value = 0;
  @override
  String newId() => 'command-${++_value}';
}

class _ReadRepository extends ShoppingRepository {
  _ReadRepository(this.records);
  final List<ShoppingListRecord> records;
  @override
  Stream<List<ShoppingListRecord>> watchLists(String _) =>
      Stream.value(records);
  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(null);
}

class _Backend implements ShoppingAllocationCommandRepository {
  _Backend(List<ShoppingListRecord> records) : records = List.of(records);
  final List<ShoppingListRecord> records;
  final commands = <ConsumeShoppingAllocationIntent>[];
  final started = Completer<void>();
  Completer<void>? block;
  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    commands.add(command);
    if (!started.isCompleted) started.complete();
    await block?.future;
    return const ShoppingCommandResult(
      listId: 'server-derived',
      status: ShoppingCommandStatus.pending,
      alreadyApplied: false,
      revision: 0,
    );
  }

  @override
  Future<ShoppingCommandResult> upsertList(ShoppingListUpsertCommand _) =>
      throw UnimplementedError();
  @override
  Future<ShoppingCommandResult> mutateItem(ShoppingListItemMutationCommand _) =>
      throw UnimplementedError();
  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest _) =>
      throw UnimplementedError();
  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest _) =>
      throw UnimplementedError();
}

class _UnsupportedCalendarRepository extends CalendarRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnsupportedRecipeRepository extends RecipeRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnsupportedPantryRepository extends PantryRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
