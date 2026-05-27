import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/search_ingredients.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed dictionary then search for onion', (tester) async {
    await bootEmulatedApp();

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Seed the global dictionary.
    final seedResult = await container.read(seedGlobalDictionaryProvider)(
      const NoParams(),
    );
    expect(seedResult, isA<Success<int>>());

    // Search for 'onion'.
    final searchResult = await container.read(searchIngredientsProvider)(
      const SearchIngredientsParams(query: 'onion'),
    );
    expect(searchResult, isA<Success<List<Ingredient>>>());

    final items = (searchResult as Success<List<Ingredient>>).value;
    expect(items.any((i) => i.id == 'onion'), isTrue);
    expect(items.any((i) => i.parentIngredientId == 'onion'), isTrue);
  });
}
