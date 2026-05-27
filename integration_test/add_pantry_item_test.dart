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
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add pantry item and verify it appears in section stream', (
    tester,
  ) async {
    await bootEmulatedApp();

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Seed dictionary so the ingredient exists.
    await container.read(seedGlobalDictionaryProvider)(const NoParams());

    final hid = container.read(activeHouseholdIdProvider);

    final addResult = await container.read(addPantryItemProvider)(
      AddPantryItemParams(
        householdId: hid,
        ingredientId: 'onion',
        quantity: 3,
        unit: Unit.piece,
        section: PantrySection.food,
      ),
    );
    expect(addResult, isA<Success<PantryItem>>());

    final items = await container
        .read(watchPantrySectionProvider)
        .watch(hid, PantrySection.food)
        .first;
    expect(items.any((i) => i.ingredientId == 'onion'), isTrue);
  });
}
