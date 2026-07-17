import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/menu_sets/data/datasources/menu_set_remote_data_source.dart';
import 'package:kitchensync/features/menu_sets/data/repositories/menu_set_repository_impl.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_apply_persistence_controller.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_editor_controller.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

export 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_apply_persistence_controller.dart';
export 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_editor_controller.dart';

final menuSetRemoteDataSourceProvider = Provider<MenuSetRemoteDataSource>(
  (ref) => MenuSetRemoteDataSource(ref.watch(firestoreRefsProvider)),
);

final menuSetRepositoryProvider = Provider<MenuSetRepository>(
  (ref) => MenuSetRepositoryImpl(ref.watch(menuSetRemoteDataSourceProvider)),
);

final activeHouseholdMenuSetsProvider = StreamProvider<List<MenuSet>>((ref) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(menuSetRepositoryProvider)
      .watchHouseholdMenuSets(householdId);
});

final activeMenuSetProvider = StreamProvider.family<MenuSet?, String>((
  ref,
  menuSetId,
) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(menuSetRepositoryProvider)
      .watchById(householdId: householdId, menuSetId: menuSetId);
});

final menuSetApplyPersistenceControllerProvider =
    Provider<MenuSetApplyPersistenceController>((ref) {
      final householdId = ref.watch(activeHouseholdIdProvider);
      final idGenerator = ref.watch(idGeneratorProvider);
      final shoppingRepository = ref.watch(shoppingRepositoryProvider);
      final writeCoordinator = ShoppingWriteCoordinator(
        repository: ref.watch(shoppingCommandRepositoryProvider),
        householdId: householdId,
        idGenerator: idGenerator,
      );
      return MenuSetApplyPersistenceController(
        calendarRepository: ref.watch(calendarRepositoryProvider),
        shoppingRepository: shoppingRepository,
        writeCoordinator: writeCoordinator,
        recipeRepository: ref.watch(recipeRepositoryProvider),
        pantryRepository: ref.watch(pantryRepositoryProvider),
        shoppingScheduleRepository: ref.watch(
          shoppingScheduleRepositoryProvider,
        ),
        householdId: householdId,
        household: ref.watch(activeHouseholdContextProvider),
        idGenerator: idGenerator,
        clock: ref.watch(clockProvider),
      );
    });

final menuSetEditorControllerProvider = Provider<MenuSetEditorController>((
  ref,
) {
  return MenuSetEditorController(
    calendarRepository: ref.watch(calendarRepositoryProvider),
    menuSetRepository: ref.watch(menuSetRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    household: ref.watch(activeHouseholdContextProvider),
    userId: ref.watch(activeUserIdProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});
