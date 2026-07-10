import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

void main() {
  test('PantryItem round-trips through JSON', () {
    final p = PantryItem(
      id: 'p1',
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 2.5,
      unit: UnitId.kg,
      section: PantrySection.food,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    expect(PantryItem.fromJson(p.toJson()), p);
  });
}
