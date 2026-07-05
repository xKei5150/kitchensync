import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_image_storage.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_remote_data_source.dart';
import 'package:kitchensync/features/pantry/data/datasources/purchase_history_remote_data_source.dart';
import 'package:kitchensync/features/pantry/data/datasources/waste_remote_data_source.dart';
import 'package:kitchensync/features/pantry/data/repositories/pantry_repository_impl.dart';
import 'package:kitchensync/features/pantry/data/repositories/purchase_history_repository_impl.dart';
import 'package:kitchensync/features/pantry/data/repositories/waste_repository_impl.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item_photo.dart';
import 'package:kitchensync/features/pantry/domain/usecases/adjust_pantry_quantity.dart';
import 'package:kitchensync/features/pantry/domain/usecases/delete_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_leftover.dart';
import 'package:kitchensync/features/pantry/domain/usecases/update_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/watch_pantry_section.dart';
import 'package:kitchensync/features/pantry/domain/usecases/watch_waste_history.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pantry_providers.g.dart';

// ── Infrastructure ──────────────────────────────────────

@Riverpod(keepAlive: true)
FirebaseStorage firebaseStorage(Ref ref) => FirebaseStorage.instance;

@Riverpod(keepAlive: true)
PantryRemoteDataSource pantryRemoteDataSource(Ref ref) =>
    PantryRemoteDataSource(ref.watch(firestoreRefsProvider));

@Riverpod(keepAlive: true)
PantryImageStorage pantryImageStorage(Ref ref) =>
    PantryImageStorage(ref.watch(firebaseStorageProvider));

@Riverpod(keepAlive: true)
WasteRemoteDataSource wasteRemoteDataSource(Ref ref) =>
    WasteRemoteDataSource(ref.watch(firestoreRefsProvider));

@Riverpod(keepAlive: true)
PurchaseHistoryRemoteDataSource purchaseHistoryRemoteDataSource(Ref ref) =>
    PurchaseHistoryRemoteDataSource(ref.watch(firestoreRefsProvider));

// ── Repositories ─────────────────────────────────────────

@Riverpod(keepAlive: true)
PantryRepository pantryRepository(Ref ref) => PantryRepositoryImpl(
  ref.watch(pantryRemoteDataSourceProvider),
  ref.watch(pantryImageStorageProvider),
);

@Riverpod(keepAlive: true)
WasteRepository wasteRepository(Ref ref) =>
    WasteRepositoryImpl(ref.watch(wasteRemoteDataSourceProvider));

@Riverpod(keepAlive: true)
PurchaseHistoryRepository purchaseHistoryRepository(Ref ref) =>
    PurchaseHistoryRepositoryImpl(
      ref.watch(purchaseHistoryRemoteDataSourceProvider),
    );

// ── Use cases ─────────────────────────────────────────────

@riverpod
AddPantryItem addPantryItem(Ref ref) => AddPantryItem(
  ref.watch(pantryRepositoryProvider),
  ref.watch(ingredientRepositoryProvider),
  idGenerator: ref.watch(idGeneratorProvider),
  clock: ref.watch(clockProvider),
);

@riverpod
AdjustPantryQuantity adjustPantryQuantity(Ref ref) =>
    AdjustPantryQuantity(ref.watch(pantryRepositoryProvider));

@riverpod
MarkAsWaste markAsWaste(Ref ref) => MarkAsWaste(
  ref.watch(pantryRepositoryProvider),
  idGenerator: ref.watch(idGeneratorProvider),
  clock: ref.watch(clockProvider),
);

@riverpod
AddPantryItemPhoto addPantryItemPhoto(Ref ref) =>
    AddPantryItemPhoto(ref.watch(pantryRepositoryProvider));

@riverpod
RecordLeftover recordLeftover(Ref ref) => RecordLeftover(
  ref.watch(pantryRepositoryProvider),
  idGenerator: ref.watch(idGeneratorProvider),
  clock: ref.watch(clockProvider),
);

@riverpod
DeletePantryItem deletePantryItem(Ref ref) =>
    DeletePantryItem(ref.watch(pantryRepositoryProvider));

@riverpod
UpdatePantryItem updatePantryItem(Ref ref) => UpdatePantryItem(
  ref.watch(pantryRepositoryProvider),
  ref.watch(ingredientRepositoryProvider),
);

@riverpod
WatchPantrySection watchPantrySection(Ref ref) =>
    WatchPantrySection(ref.watch(pantryRepositoryProvider));

@riverpod
WatchWasteHistory watchWasteHistory(Ref ref) =>
    WatchWasteHistory(ref.watch(wasteRepositoryProvider));

// ── Tab controller ───────────────────────────────────────

@riverpod
class PantryTabController extends _$PantryTabController {
  @override
  PantrySection build() => PantrySection.food;

  // ignore: use_setters_to_change_properties
  void select(PantrySection section) => state = section;
}

// ── Derived streams ──────────────────────────────────────

@riverpod
Stream<List<PantryItem>> pantrySectionStream(Ref ref) {
  final section = ref.watch(pantryTabControllerProvider);
  final hid = ref.watch(activeHouseholdIdProvider);
  return ref.watch(watchPantrySectionProvider).watch(hid, section);
}

@riverpod
Stream<List<WasteEvent>> wasteHistoryStream(Ref ref) {
  final hid = ref.watch(activeHouseholdIdProvider);
  return ref.watch(watchWasteHistoryProvider).watch(hid);
}

@riverpod
Stream<List<PurchaseRecord>> purchaseHistoryStream(Ref ref) {
  final hid = ref.watch(activeHouseholdIdProvider);
  return ref.watch(purchaseHistoryRepositoryProvider).watchByHousehold(hid);
}

/// Every pantry item across all four sections, combined into one live list.
///
/// The repository only exposes a per-section watch, so this fans out across
/// [PantrySection.values] and emits the latest union whenever any section
/// changes — the read the Insights surface (Screen 30) needs to measure the
/// whole pantry's freshness and section balance at once.
@riverpod
Stream<List<PantryItem>> pantryAllItemsStream(Ref ref) {
  final hid = ref.watch(activeHouseholdIdProvider);
  final watch = ref.watch(watchPantrySectionProvider);

  final latest = <PantrySection, List<PantryItem>>{};
  final controller = StreamController<List<PantryItem>>();
  final subs = <StreamSubscription<List<PantryItem>>>[];

  List<PantryItem> union() => [
    for (final section in PantrySection.values) ...?latest[section],
  ];

  for (final section in PantrySection.values) {
    subs.add(
      watch
          .watch(hid, section)
          .listen(
            (items) {
              latest[section] = items;
              if (!controller.isClosed) controller.add(union());
            },
            onError: (Object error, StackTrace stack) {
              if (!controller.isClosed) controller.addError(error, stack);
            },
          ),
    );
  }

  ref.onDispose(() {
    for (final sub in subs) {
      unawaited(sub.cancel());
    }
    unawaited(controller.close());
  });

  return controller.stream;
}

@riverpod
List<BulkPantryStatus> bulkPantryStatuses(Ref ref) {
  final items =
      ref.watch(pantryAllItemsStreamProvider).asData?.value ??
      const <PantryItem>[];
  final waste =
      ref.watch(wasteHistoryStreamProvider).asData?.value ??
      const <WasteEvent>[];
  final purchases =
      ref.watch(purchaseHistoryStreamProvider).asData?.value ??
      const <PurchaseRecord>[];
  return const BulkPredictionEngine().predict(
    pantryItems: items,
    usageEvents: waste,
    purchaseHistory: purchases,
    now: DateTime.now(),
  );
}

@riverpod
Stream<PantryItem?> pantryItemStream(
  Ref ref,
  String householdId,
  String itemId,
) => ref.watch(pantryRepositoryProvider).watchById(householdId, itemId);

@riverpod
Future<Result<Ingredient>> pantryIngredient(Ref ref, String ingredientId) =>
    ref.watch(getIngredientProvider)(ingredientId);
