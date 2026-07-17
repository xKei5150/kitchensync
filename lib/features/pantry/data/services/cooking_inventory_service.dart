import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/calendar/data/dtos/calendar_dto.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/dtos/consumption_event_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/pantry_item_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/services/cooking_deduction_planner.dart';

class CookingInventoryRequirement {
  const CookingInventoryRequirement({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });

  final String ingredientId;
  final double quantity;
  final UnitId unit;
}

class CookingInventoryService {
  const CookingInventoryService(this._refs);

  final FirestoreRefs _refs;

  Future<CookingDeductionPlan> inspect({
    required String householdId,
    required CookingInventoryRequirement requirement,
  }) async {
    final lots = await _loadEligibleLots(
      householdId: householdId,
      ingredientId: requirement.ingredientId,
    );
    return CookingDeductionPlanner.plan(
      lots: lots,
      requiredQuantity: requirement.quantity,
      requiredUnit: requirement.unit,
    );
  }

  Future<void> complete({
    required String householdId,
    required MealScheduleEntry meal,
    required List<CookingInventoryRequirement> requirements,
    required DateTime occurredAt,
  }) async {
    final initialLots = <List<PantryItem>>[];
    for (final requirement in requirements) {
      initialLots.add(
        await _loadEligibleLots(
          householdId: householdId,
          ingredientId: requirement.ingredientId,
        ),
      );
    }
    final db = _refs.pantryItems(householdId).firestore;
    await db.runTransaction((transaction) async {
      final mealRef = _refs.mealScheduleEntries(householdId).doc(meal.id);
      final mealSnapshot = await transaction.get(mealRef);
      if (mealSnapshot.data()?['state'] == ScheduledMealState.cooked.name) {
        return;
      }
      final deductions = <PantryDeduction>[];
      for (var index = 0; index < requirements.length; index++) {
        final requirement = requirements[index];
        final currentLots = <PantryItem>[];
        for (final initial in initialLots[index]) {
          final ref = _refs.pantryItems(householdId).doc(initial.id);
          final snapshot = await transaction.get(ref);
          if (snapshot.exists) {
            currentLots.add(
              PantryItemMapper.fromMap(snapshot.id, snapshot.data()!),
            );
          }
        }
        final currentPlan = CookingDeductionPlanner.plan(
          lots: currentLots,
          requiredQuantity: requirement.quantity,
          requiredUnit: requirement.unit,
        );
        if (!currentPlan.isComplete) {
          throw StateError('Pantry changed while cooking was being completed.');
        }
        deductions.addAll(currentPlan.deductions);
      }

      for (final deduction in deductions) {
        transaction
            .update(_refs.pantryItems(householdId).doc(deduction.item.id), {
              'quantity': deduction.remainingQuantity,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        final eventId = 'cook-${meal.id}-${deduction.item.id}';
        transaction.set(
          _refs.consumptionEvents(householdId).doc(eventId),
          ConsumptionEventMapper.toMap(
            ConsumptionEvent(
              id: eventId,
              householdId: householdId,
              pantryItemId: deduction.item.id,
              ingredientId: deduction.item.ingredientId,
              quantity: deduction.quantity,
              unit: deduction.item.unit,
              source: ConsumptionSource.cooking,
              sourceMealId: meal.id,
              date: occurredAt,
            ),
          ),
        );
      }
      transaction.set(
        mealRef,
        MealScheduleEntryMapper.toMap(
          householdId: householdId,
          entry: meal.copyWith(
            state: ScheduledMealState.cooked,
            marking: ScheduledMealMarking.none,
          ),
        ),
      );
    });
  }

  Future<void> consumeLeftover({
    required String householdId,
    required MealScheduleEntry meal,
    required String leftoverId,
    required DateTime occurredAt,
  }) async {
    final db = _refs.pantryItems(householdId).firestore;
    await db.runTransaction((transaction) async {
      final mealRef = _refs.mealScheduleEntries(householdId).doc(meal.id);
      final mealSnapshot = await transaction.get(mealRef);
      if (mealSnapshot.data()?['state'] == ScheduledMealState.cooked.name) {
        return;
      }
      final leftoverRef = _refs.pantryItems(householdId).doc(leftoverId);
      final leftoverSnapshot = await transaction.get(leftoverRef);
      if (!leftoverSnapshot.exists) {
        throw StateError('Cannot consume missing leftover $leftoverId.');
      }
      final leftover = PantryItemMapper.fromMap(
        leftoverSnapshot.id,
        leftoverSnapshot.data()!,
      );
      if (leftover.section != PantrySection.leftover) {
        throw StateError('$leftoverId is not a leftover pantry item.');
      }
      final used = meal.servingSize
          .toDouble()
          .clamp(0, leftover.quantity)
          .toDouble();
      if (used <= 0) {
        throw StateError('Leftover $leftoverId is already empty.');
      }
      final remaining = leftover.quantity - used;
      transaction.update(leftoverRef, {
        'quantity': remaining,
        'leftoverServings': remaining.round(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final eventId = 'leftover-${meal.id}-$leftoverId';
      transaction.set(
        _refs.consumptionEvents(householdId).doc(eventId),
        ConsumptionEventMapper.toMap(
          ConsumptionEvent(
            id: eventId,
            householdId: householdId,
            pantryItemId: leftoverId,
            ingredientId: leftover.ingredientId,
            quantity: used,
            unit: leftover.unit,
            source: ConsumptionSource.leftover,
            sourceMealId: meal.id,
            date: occurredAt,
          ),
        ),
      );
      transaction.set(
        mealRef,
        MealScheduleEntryMapper.toMap(
          householdId: householdId,
          entry: meal.copyWith(state: ScheduledMealState.cooked),
        ),
      );
    });
  }

  Future<List<PantryItem>> _loadEligibleLots({
    required String householdId,
    required String ingredientId,
  }) async {
    final snapshot = await _refs
        .pantryItems(householdId)
        .where('ingredientId', isEqualTo: ingredientId)
        .get();
    return snapshot.docs
        .map((doc) => PantryItemMapper.fromMap(doc.id, doc.data()))
        .where(
          (item) =>
              item.section == PantrySection.food ||
              item.section == PantrySection.bulk,
        )
        .toList(growable: false);
  }
}
