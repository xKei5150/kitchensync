import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mark pantry item as waste and verify quantity + waste log', (
    tester,
  ) async {
    await bootEmulatedApp();

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Seed dictionary so the ingredient exists.
    await container.read(seedGlobalDictionaryProvider)(const NoParams());

    final hid = container.read(activeHouseholdIdProvider);

    // Add a pantry item for 'salt'.
    final addResult = await container.read(addPantryItemProvider)(
      AddPantryItemParams(
        householdId: hid,
        ingredientId: 'salt',
        quantity: 100,
        unit: Unit.g,
        section: PantrySection.food,
      ),
    );
    expect(addResult, isA<Success<PantryItem>>());
    final addedId = (addResult as Success<PantryItem>).value.id;

    // Mark 30g as waste.
    final wasteResult = await container.read(markAsWasteProvider)(
      MarkAsWasteParams(
        householdId: hid,
        pantryItemId: addedId,
        quantity: 30,
        reason: WasteReason.spoiled,
      ),
    );
    expect(wasteResult, isA<Success<void>>());

    // Verify pantry quantity was reduced to 70.
    final updatedItem = await container
        .read(pantryRepositoryProvider)
        .watchById(hid, addedId)
        .first;
    expect(updatedItem, isNotNull);
    expect(updatedItem!.quantity, 70.0);

    // Verify waste log contains the event.
    final wasteEvents = await container
        .read(wasteRepositoryProvider)
        .watchByHousehold(hid)
        .first;
    expect(wasteEvents.any((e) => e.pantryItemId == addedId), isTrue);
  });
}
