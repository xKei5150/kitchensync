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
import 'package:kitchensync/features/pantry/domain/usecases/delete_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/update_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// FD-PANTRY-INV-01 residual: verify the edit and remove pantry mutations round
/// trip through Firestore against the dev emulator, complementing the already
/// verified add path (`add_pantry_item_test.dart`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit then remove a pantry item persists through Firestore', (
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

    // Arrange: add a food item.
    final addResult = await container.read(addPantryItemProvider)(
      AddPantryItemParams(
        householdId: hid,
        ingredientId: 'onion',
        quantity: 3,
        unit: UnitId.piece,
        section: PantrySection.food,
      ),
    );
    expect(addResult, isA<Success<PantryItem>>());
    final added = (addResult as Success<PantryItem>).value;

    // Act 1: edit metadata + quantity through the real update use case.
    final editResult = await withTimeout(
      'update pantry item',
      () => container.read(updatePantryItemProvider)(
        UpdatePantryItemParams(
          item: added.copyWith(quantity: 5, note: 'edited note'),
        ),
      ),
    );
    expect(editResult, isA<Success<PantryItem>>());

    // Assert 1: the edit is observable through the item stream (server read).
    final edited = await withTimeout(
      'observe edited item',
      () => container
          .read(pantryRepositoryProvider)
          .watchById(hid, added.id)
          .firstWhere(
            (item) =>
                item != null &&
                item.quantity == 5 &&
                item.note == 'edited note',
          ),
    );
    expect(edited!.quantity, 5);
    expect(edited.note, 'edited note');

    // Independent owner-REST corroboration of the persisted edit.
    final existsAfterEdit = await firestoreDocumentExistsThroughEmulatorAdmin(
      'households/$hid/pantryItems/${added.id}',
    );
    expect(existsAfterEdit, isTrue);

    // Act 2: remove. Quantity > 0 requires an explicit force confirmation.
    final unconfirmed = await container.read(deletePantryItemProvider)(
      DeletePantryItemParams(householdId: hid, itemId: added.id),
    );
    expect(
      unconfirmed,
      isA<ResultFailure<void>>(),
      reason: 'deleting a non-empty item without force must be rejected',
    );

    final removed = await withTimeout(
      'delete pantry item',
      () => container.read(deletePantryItemProvider)(
        DeletePantryItemParams(householdId: hid, itemId: added.id, force: true),
      ),
    );
    expect(removed, isA<Success<void>>());

    // Assert 2: the item is gone from the stream and from Firestore.
    final gone = await withTimeout(
      'observe removed item',
      () => container
          .read(pantryRepositoryProvider)
          .watchById(hid, added.id)
          .firstWhere((item) => item == null),
    );
    expect(gone, isNull);

    final existsAfterDelete = await firestoreDocumentExistsThroughEmulatorAdmin(
      'households/$hid/pantryItems/${added.id}',
    );
    expect(existsAfterDelete, isFalse);
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
