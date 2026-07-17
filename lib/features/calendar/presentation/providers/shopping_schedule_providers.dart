import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/calendar/data/datasources/shopping_schedule_remote_data_source.dart';
import 'package:kitchensync/features/calendar/data/repositories/shopping_schedule_repository_impl.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_controller.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

final shoppingScheduleRemoteDataSourceProvider =
    Provider<ShoppingScheduleRemoteDataSource>(
      (ref) =>
          ShoppingScheduleRemoteDataSource(ref.watch(firestoreRefsProvider)),
    );

final shoppingScheduleRepositoryProvider = Provider<ShoppingScheduleRepository>(
  (ref) => ShoppingScheduleRepositoryImpl(
    ref.watch(shoppingScheduleRemoteDataSourceProvider),
  ),
);

final activeShoppingScheduleProvider = StreamProvider<ShoppingSchedule?>((ref) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref.watch(shoppingScheduleRepositoryProvider).watch(householdId);
});

final shoppingScheduleControllerProvider = Provider<ShoppingScheduleController>(
  (ref) {
    final household = ref.watch(activeHouseholdContextProvider);
    if (household == null) throw StateError('No active household selected.');
    return ShoppingScheduleController(
      repository: ref.watch(shoppingScheduleRepositoryProvider),
      householdId: household.id,
      userId: ref.watch(activeUserIdProvider),
      role: household.role,
      isSoloHousehold: household.isSolo,
      clock: ref.watch(clockProvider),
    );
  },
);
