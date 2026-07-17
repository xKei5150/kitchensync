import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';

typedef _ReconciliationSnapshot = ({List<ShoppingListRecord> lists});

class ScheduledShoppingListReconciler {
  const ScheduledShoppingListReconciler({
    required this.shoppingRepository,
    required this.writeCoordinator,
    required this.calendarRepository,
    required this.recipeRepository,
    required this.pantryRepository,
    required this.householdId,
    required this.clock,
    this.planner = const ScheduledShoppingListPlanner(),
  });

  final ShoppingRepository shoppingRepository;
  final ShoppingWriteCoordinator writeCoordinator;
  final CalendarRepository calendarRepository;
  final RecipeRepository recipeRepository;
  final PantryRepository pantryRepository;
  final String householdId;
  final Clock clock;
  final ScheduledShoppingListPlanner planner;

  Future<void> reconcile({
    required ShoppingSchedule? schedule,
    required Iterable<ScheduledShoppingRange> ranges,
  }) async {
    if (schedule == null || !schedule.isActive) return;
    final occurrences = planner.occurrencesForRanges(
      schedule: schedule,
      ranges: ranges,
    );
    if (occurrences.isEmpty) return;

    final existingLists = await shoppingRepository
        .watchLists(householdId)
        .first;
    final snapshot = (lists: existingLists);
    for (final occurrence in occurrences) {
      await _reconcileOccurrence(
        schedule: schedule,
        occurrence: occurrence,
        snapshot: snapshot,
      );
    }
  }

  Future<void> _reconcileOccurrence({
    required ShoppingSchedule schedule,
    required DateTime occurrence,
    required _ReconciliationSnapshot snapshot,
  }) async {
    final start = planner.rangeStartForOccurrence(
      schedule: schedule,
      occurrence: occurrence,
    );
    final listId = ShoppingListRecord.weeklyOccurrenceListId(occurrence);
    final existing = _listById(snapshot.lists, listId);
    if (existing == null) {
      await writeCoordinator.allocate(
        intent: ScheduledShoppingAllocationIntent(
          householdId: householdId,
          startDate: start,
          endDate: occurrence,
          scheduleKey:
              '${schedule.cadence.name}-${schedule.isoWeekday}-'
              '${_date(schedule.effectiveFrom)}',
          occurrenceDate: occurrence,
        ),
      );
    }
  }

  ShoppingListRecord? _listById(Iterable<ShoppingListRecord> lists, String id) {
    for (final list in lists) {
      if (list.id == id) return list;
    }
    return null;
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
