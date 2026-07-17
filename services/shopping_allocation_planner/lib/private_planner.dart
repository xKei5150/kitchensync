import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

import 'package:shopping_allocation_planner/private_planner_input.dart';

part 'private_planner_support.dart';

/// The only planner implementation used by the private service. It delegates
/// directly to the app's canonical ShoppingEngine and UnitRegistry.
abstract interface class TrustedPlanningSource {
  Future<Map<String, Object?>> load(PlanningIntent intent);
}

final class PlanningIntent {
  const PlanningIntent({
    required this.householdId,
    required this.startDate,
    required this.endDate,
    this.kind = 'shop_now',
    this.scheduleKey,
    this.occurrenceDate,
    this.originId,
    this.emergencyDemands = const [],
  });

  final String householdId;
  final DateTime startDate;
  final DateTime endDate;

  final String kind;
  final String? scheduleKey;
  final DateTime? occurrenceDate;
  final String? originId;
  final List<EmergencyPlanningDemand> emergencyDemands;
}

final class EmergencyPlanningDemand {
  const EmergencyPlanningDemand({
    required this.ingredientId,
    required this.quantityNeeded,
    required this.unit,
  });

  final String ingredientId;
  final double quantityNeeded;
  final String unit;
}

/// Canonical planner adapter. Trusted state is loaded server-side, never from
/// an HTTP caller's item, recipe, meal, or pantry payload.
final class PrivateAllocationPlanner {
  const PrivateAllocationPlanner({
    required this.source,
    this.engine = const ShoppingEngine(),
  });

  final TrustedPlanningSource source;
  final ShoppingEngine engine;

  Future<Map<String, Object?>> plan(PlanningIntent intent) async {
    final planned = await _plan(intent);
    final createdAt = DateTime.now().toUtc();
    final expiresAt = createdAt.add(const Duration(minutes: 10));
    final payload = {
      'householdId': intent.householdId,
      'listId': _listId(intent),
      'intent': _intentJson(intent),
      'list': {
        'type': _listType(intent.kind).name == 'shopNow'
            ? 'shop_now'
            : intent.kind,
        'shoppingDate': _date(intent.occurrenceDate ?? intent.startDate),
        'generatedForRangeStart': _date(intent.startDate),
        'generatedForRangeEnd': _date(intent.endDate),
        'originId': intent.kind == 'suggested'
            ? intent.originId
            : intent.kind == 'scheduled'
            ? intent.scheduleKey
            : null,
        'items': [
          for (final item in planned.items)
            {
              'itemId': ShoppingListItemRecord.scheduledItemId(
                ingredientId: item.ingredientId,
                unit: item.unit,
              ),
              'ingredientId': item.ingredientId,
              'quantityNeeded': item.quantity,
              'unit': item.unit.value,
              'sourceMealLinks': [
                for (final link in item.sourceMealLinks)
                  {
                    'mealEntryId': link.mealEntryId,
                    'recipeId': link.recipeId,
                    'date': _date(link.date),
                    'quantity': link.quantity,
                  },
              ],
            },
        ],
      },
    };
    final contentHash = sha256
        .convert(utf8.encode(_canonicalJson(payload)))
        .toString();
    return {
      ...payload,
      'draftId': '${_listId(intent)}-${createdAt.microsecondsSinceEpoch}',
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'state': 'ready',
      'contentHash': contentHash,
    };
  }

  Future<_PlannedList> _plan(PlanningIntent intent) async {
    if (intent.kind == 'emergency') {
      return _PlannedList([
        for (final demand in intent.emergencyDemands)
          _PlannedItem(
            ingredientId: demand.ingredientId,
            quantity: demand.quantityNeeded,
            unit: UnitId(demand.unit),
            sourceMealLinks: const [],
          ),
      ]);
    }
    final request = await source.load(intent);
    final input = PlannerInput.fromJson(request);
    final plan = engine.generateList(
      id: _listId(intent),
      type: _listType(intent.kind),
      startDate: input.startDate,
      endDate: input.endDate,
      meals: input.meals,
      recipesById: {for (final recipe in input.recipes) recipe.id: recipe},
      pantryItems: input.pantryItems,
    );
    return _PlannedList([
      for (final item in plan.items)
        _PlannedItem(
          ingredientId: item.ingredientId,
          quantity: item.quantity,
          unit: item.unit,
          sourceMealLinks: item.sourceMealLinks,
        ),
    ]);
  }
}

String _listId(PlanningIntent intent) => switch (intent.kind) {
  'shop_now' => 'shop_now_${_date(intent.startDate)}_${_date(intent.endDate)}',
  'scheduled' => 'scheduled_weekly_${_date(intent.occurrenceDate!)}'.replaceAll(
    '-',
    '',
  ),
  'suggested' =>
    intent.originId == 'recovery:core:v1'
        ? 'suggested_recovery_'
              '${_date(intent.startDate).replaceAll('-', '')}_'
              '${_date(intent.endDate).replaceAll('-', '')}'
        : 'suggested_${intent.originId}_'
              '${_date(intent.startDate)}_${_date(intent.endDate)}',
  'emergency' =>
    'emergency_${_date(intent.startDate)}_${_date(intent.endDate)}',
  _ => throw const FormatException('Unsupported planning intent kind'),
};

ShoppingListType _listType(String kind) => switch (kind) {
  'shop_now' => ShoppingListType.shopNow,
  'scheduled' => ShoppingListType.scheduled,
  'suggested' => ShoppingListType.suggested,
  'emergency' => ShoppingListType.emergency,
  _ => throw const FormatException('Unsupported planning intent kind'),
};

Map<String, Object?> _intentJson(PlanningIntent intent) =>
    switch (intent.kind) {
      'shop_now' => {
        'kind': 'shop_now',
        'startDate': _date(intent.startDate),
        'endDate': _date(intent.endDate),
      },
      'scheduled' => {
        'kind': 'scheduled',
        'scheduleKey': intent.scheduleKey,
        'occurrenceDate': _date(intent.occurrenceDate!),
        'startDate': _date(intent.startDate),
        'endDate': _date(intent.endDate),
      },
      'suggested' => {
        'kind': 'suggested',
        'originId': intent.originId,
        'windowStart': _date(intent.startDate),
        'windowEnd': _date(intent.endDate),
        'startDate': _date(intent.startDate),
        'endDate': _date(intent.endDate),
      },
      'emergency' => {
        'kind': 'emergency',
        'startDate': _date(intent.startDate),
        'endDate': _date(intent.endDate),
        'demands': [
          for (final demand in intent.emergencyDemands)
            {
              'ingredientId': demand.ingredientId,
              'quantityNeeded': demand.quantityNeeded,
              'unit': demand.unit,
            },
        ],
      },
      _ => throw const FormatException('Unsupported planning intent kind'),
    };
