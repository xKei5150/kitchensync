import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/repositories/consumption_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_command_remote_data_source.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_remote_data_source.dart';
import 'package:kitchensync/features/shopping/data/repositories/shopping_command_repository_impl.dart';
import 'package:kitchensync/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_recovery.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_reconciler.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_suggestion_reconciler.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';

part 'shopping_command_controller.dart';
part 'shopping_list_plan_factory.dart';
part 'shopping_list_plan_factory_bulk.dart';
part 'shopping_list_item_controller.dart';
part 'shopping_planning_controller.dart';
part 'shopping_planning_controller_recovery.dart';
part 'shopping_planning_controller_items.dart';

final shoppingRemoteDataSourceProvider = Provider<ShoppingRemoteDataSource>(
  (ref) => ShoppingRemoteDataSource(ref.watch(firestoreRefsProvider)),
);

final shoppingCommandDataSourceProvider = Provider<ShoppingCommandDataSource>(
  (ref) => ShoppingCommandRemoteDataSource(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  ),
);

final shoppingCommandRepositoryProvider = Provider<ShoppingCommandRepository>(
  (ref) => ShoppingCommandRepositoryImpl(
    ref.watch(shoppingCommandDataSourceProvider),
  ),
);

final shoppingAllocationCommandRepositoryProvider =
    Provider<ShoppingAllocationCommandRepository>(
      (ref) => ShoppingCommandRepositoryImpl(
        ref.watch(shoppingCommandDataSourceProvider),
      ),
    );

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepositoryImpl(ref.watch(shoppingRemoteDataSourceProvider)),
);

final activeShoppingListsProvider = StreamProvider<List<ShoppingListRecord>>((
  ref,
) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref.watch(shoppingRepositoryProvider).watchLists(householdId);
});

final activeShoppingListRecordProvider =
    StreamProvider.family<ShoppingListRecord?, String>((ref, listId) {
      final householdId = ref.watch(activeHouseholdIdProvider);
      return ref
          .watch(shoppingRepositoryProvider)
          .watchList(householdId: householdId, listId: listId);
    });

final completedShoppingMemberNameProvider =
    FutureProvider.family<String, String?>((ref, userId) async {
      if (userId == null || userId.isEmpty) return 'Household member';
      // Widget tests and unauthenticated surfaces have no Firebase app to read.
      if (ref.watch(firebaseAuthProvider) == null) return 'Household member';
      final householdId = ref.watch(activeHouseholdIdProvider);
      final member = await ref
          .watch(firestoreRefsProvider)
          .householdMember(householdId, userId)
          .get();
      final name = member.data()?['displayName'] as String?;
      return name == null || name.trim().isEmpty ? 'Household member' : name;
    });

final shoppingPlanningControllerProvider = Provider<ShoppingPlanningController>(
  (ref) {
    final householdId = ref.watch(activeHouseholdIdProvider);
    final idGenerator = ref.watch(idGeneratorProvider);
    // Ingredient metadata enriches conversions, but the controller must remain
    // usable in unauthenticated/widget-test contexts where Firebase is absent.
    final ingredientRepository = ref.watch(firebaseAuthProvider) == null
        ? null
        : ref.watch(ingredientRepositoryProvider);
    final writeCoordinator = ShoppingWriteCoordinator(
      repository: ref.watch(shoppingCommandRepositoryProvider),
      allocationRepository: ref.watch(
        shoppingAllocationCommandRepositoryProvider,
      ),
      householdId: householdId,
      idGenerator: idGenerator,
    );
    return ShoppingPlanningController(
      repository: ref.watch(shoppingRepositoryProvider),
      writeCoordinator: writeCoordinator,
      calendarRepository: ref.watch(calendarRepositoryProvider),
      pantryRepository: ref.watch(pantryRepositoryProvider),
      purchaseHistoryRepository: ref.watch(purchaseHistoryRepositoryProvider),
      consumptionHistoryRepository: ref.watch(
        consumptionHistoryRepositoryProvider,
      ),
      wasteRepository: ref.watch(wasteRepositoryProvider),
      recipeRepository: ref.watch(recipeRepositoryProvider),
      ingredientRepository: ingredientRepository,
      householdId: householdId,
      household: ref.watch(activeHouseholdContextProvider),
      idGenerator: idGenerator,
      clock: ref.watch(clockProvider),
      shoppingScheduleRepository: ref.watch(shoppingScheduleRepositoryProvider),
    );
  },
);

final shoppingCommandControllerProvider = Provider(
  (ref) => ShoppingCommandController(
    repository: ref.watch(shoppingCommandRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    household: ref.watch(activeHouseholdContextProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  ),
);
