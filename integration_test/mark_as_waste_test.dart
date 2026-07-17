import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mark pantry item as waste and verify quantity + waste log', (
    tester,
  ) async {
    await bootEmulatedApp();

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await seedGlobalDictionaryThroughEmulatorAdmin();

    final hid = await withTimeout(
      'wait for bootstrapped household',
      () => _waitForActiveHouseholdId(container),
    );

    // Add a pantry item for 'salt'.
    final addResult = await container.read(addPantryItemProvider)(
      AddPantryItemParams(
        householdId: hid,
        ingredientId: 'salt',
        quantity: 100,
        unit: UnitId.g,
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
        .firstWhere((item) => item?.quantity == 70);
    expect(updatedItem, isNotNull);
    expect(updatedItem!.quantity, 70.0);

    // Verify waste log contains the event.
    final wasteEvents = await container
        .read(wasteRepositoryProvider)
        .watchByHousehold(hid)
        .firstWhere(
          (events) => events.any((event) => event.pantryItemId == addedId),
        );
    expect(wasteEvents.any((e) => e.pantryItemId == addedId), isTrue);
  });
}

Future<String> _waitForActiveHouseholdId(ProviderContainer container) async {
  while (true) {
    final context = container.read(activeHouseholdContextProvider);
    if (context != null && context.id != previewHouseholdContext.id) {
      return context.id;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
