import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/get_ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/list_ingredient_variants.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/resolve_or_create_ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/search_ingredients.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/seed_global_dictionary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ingredient_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
FirestoreRefs firestoreRefs(Ref ref) =>
    FirestoreRefs(ref.watch(firestoreProvider));

@Riverpod(keepAlive: true)
IngredientRemoteDataSource ingredientRemoteDataSource(Ref ref) =>
    IngredientRemoteDataSource(ref.watch(firestoreRefsProvider));

@Riverpod(keepAlive: true)
IngredientSeedDataSource ingredientSeedDataSource(Ref ref) =>
    IngredientSeedDataSource();

@Riverpod(keepAlive: true)
IngredientRepository ingredientRepository(Ref ref) =>
    IngredientRepositoryImpl(ref.watch(ingredientRemoteDataSourceProvider));

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidV4IdGenerator();

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@riverpod
SearchIngredients searchIngredients(Ref ref) =>
    SearchIngredients(ref.watch(ingredientRepositoryProvider));

@riverpod
GetIngredient getIngredient(Ref ref) =>
    GetIngredient(ref.watch(ingredientRepositoryProvider));

@riverpod
ListIngredientVariants listIngredientVariants(Ref ref) =>
    ListIngredientVariants(ref.watch(ingredientRepositoryProvider));

@riverpod
CreateCustomIngredient createCustomIngredient(Ref ref) =>
    CreateCustomIngredient(
      ref.watch(ingredientRepositoryProvider),
      idGenerator: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );

final resolveOrCreateIngredientProvider = Provider<ResolveOrCreateIngredient>(
  (ref) => ResolveOrCreateIngredient(
    ref.watch(ingredientRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

@riverpod
SeedGlobalDictionary seedGlobalDictionary(Ref ref) => SeedGlobalDictionary(
  ref.watch(ingredientRepositoryProvider),
  loader: () => ref.read(ingredientSeedDataSourceProvider).load(),
);
