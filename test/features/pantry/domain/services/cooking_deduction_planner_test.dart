import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/services/cooking_deduction_planner.dart';

PantryItem lot({
  required String id,
  required double quantity,
  required UnitId unit,
  required DateTime createdAt,
  DateTime? expiryDate,
  DateTime? lastPurchaseDate,
  PantrySection section = PantrySection.food,
}) => PantryItem(
  id: id,
  householdId: 'household',
  ingredientId: 'flour',
  quantity: quantity,
  unit: unit,
  section: section,
  expiryDate: expiryDate,
  lastPurchaseDate: lastPurchaseDate,
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  test('consumes multiple lots by expiry then creation date', () {
    final plan = CookingDeductionPlanner.plan(
      lots: [
        lot(
          id: 'newer',
          quantity: 300,
          unit: UnitId.g,
          createdAt: DateTime(2026, 2),
          expiryDate: DateTime(2026, 8),
        ),
        lot(
          id: 'expiring',
          quantity: 200,
          unit: UnitId.g,
          createdAt: DateTime(2026, 3),
          expiryDate: DateTime(2026, 7),
        ),
        lot(
          id: 'oldest-no-expiry',
          quantity: 400,
          unit: UnitId.g,
          createdAt: DateTime(2026),
        ),
      ],
      requiredQuantity: 450,
      requiredUnit: UnitId.g,
    );

    expect(plan.isComplete, isTrue);
    expect(plan.deductions.map((d) => d.item.id), ['expiring', 'newer']);
    expect(plan.deductions.map((d) => d.quantity), [200, 250]);
    expect(plan.deductions.last.remainingQuantity, 50);
  });

  test('normalizes compatible formal units and includes bulk stock', () {
    final plan = CookingDeductionPlanner.plan(
      lots: [
        lot(
          id: 'bulk-flour',
          quantity: 1,
          unit: UnitId.kg,
          section: PantrySection.bulk,
          createdAt: DateTime(2026),
        ),
      ],
      requiredQuantity: 250,
      requiredUnit: UnitId.g,
    );

    expect(plan.isComplete, isTrue);
    expect(plan.deductions.single.quantity, closeTo(.25, 1e-9));
    expect(plan.deductions.single.remainingQuantity, closeTo(.75, 1e-9));
  });

  test('uses purchase date before creation date when expiry is equal', () {
    final plan = CookingDeductionPlanner.plan(
      lots: [
        lot(
          id: 'created-first-bought-later',
          quantity: 100,
          unit: UnitId.g,
          createdAt: DateTime(2026),
          lastPurchaseDate: DateTime(2026, 6),
        ),
        lot(
          id: 'created-later-bought-first',
          quantity: 100,
          unit: UnitId.g,
          createdAt: DateTime(2026, 2),
          lastPurchaseDate: DateTime(2026, 5),
        ),
      ],
      requiredQuantity: 50,
      requiredUnit: UnitId.g,
    );

    expect(plan.deductions.single.item.id, 'created-later-bought-first');
  });

  test('deducts using an ingredient-local convertible unit', () {
    final sack = UnitDefinition.mass(
      id: UnitId('sack'),
      label: 'sack',
      pluralLabel: 'sacks',
      family: UnitSystemFamily.local,
      gramsPerUnit: 5000,
    );
    final plan = CookingDeductionPlanner.plan(
      lots: [
        lot(
          id: 'rice-sack',
          quantity: 1,
          unit: sack.id,
          section: PantrySection.bulk,
          createdAt: DateTime(2026),
        ),
      ],
      requiredQuantity: 2,
      requiredUnit: UnitId.kg,
      localUnitDefinitions: [sack],
    );

    expect(plan.isComplete, isTrue);
    expect(plan.deductions.single.quantity, closeTo(0.4, 1e-9));
    expect(plan.deductions.single.remainingQuantity, closeTo(0.6, 1e-9));
  });
}
