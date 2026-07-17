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
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add pantry item and verify it appears in section stream', (
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

    final items = await container
        .read(watchPantrySectionProvider)
        .watch(hid, PantrySection.food)
        .firstWhere(
          (items) => items.any((item) => item.ingredientId == 'onion'),
        );
    expect(items.any((i) => i.ingredientId == 'onion'), isTrue);
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
