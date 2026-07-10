import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/recipes/data/datasources/recipe_remote_data_source.dart';
import 'package:kitchensync/features/recipes/data/dtos/recipe_dto.dart';
import 'package:kitchensync/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RecipeRepositoryImpl repo;

  const householdId = 'h1';
  final now = DateTime(2026, 7, 4, 12);
  late Recipe publicRecipe;
  late Recipe privateRecipe;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RecipeRepositoryImpl(RecipeRemoteDataSource(FirestoreRefs(db)));
    publicRecipe = Recipe(
      id: 'public-1',
      authorUserId: 'author-1',
      householdId: 'source-household',
      name: 'Fried Chicken',
      description: 'Crispy and simple',
      defaultServingSize: 4,
      mealTimeTags: const ['Lunch', 'Dinner'],
      recipeTags: const ['Chicken', 'Comfort Food'],
      priceEstimate: 250,
      location: 'Manila',
      youtubeEmbedUrl: Uri.parse('https://youtu.be/example'),
      visibility: RecipeVisibility.public,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      instructions: const ['Mix flour.', 'Fry until golden.'],
      ingredients: const [
        RecipeIngredient(
          id: 'ri-1',
          recipeId: 'public-1',
          ingredientId: 'chicken-thighs',
          quantity: 1,
          unit: UnitId.kg,
          description: 'bone-in',
        ),
      ],
    );
    privateRecipe = Recipe(
      id: 'private-1',
      authorUserId: 'user-1',
      householdId: householdId,
      name: 'Lentil Dal',
      description: 'Weeknight dal',
      defaultServingSize: 4,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Budget'],
      priceEstimate: 180,
      location: 'Home',
      visibility: RecipeVisibility.private,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      instructions: const ['Simmer lentils.'],
      ingredients: const [
        RecipeIngredient(
          id: 'ri-2',
          recipeId: 'private-1',
          ingredientId: 'lentils',
          quantity: 300,
          unit: UnitId.g,
        ),
      ],
    );
  });

  test('RecipeMapper stores design-doc field names', () {
    final map = RecipeMapper.toMap(publicRecipe);

    expect(map['authorUserId'], 'author-1');
    expect(map['householdId'], 'source-household');
    expect(map['name'], 'Fried Chicken');
    expect(map['description'], 'Crispy and simple');
    expect(map['defaultServingSize'], 4);
    expect(map['mealTimeTags'], ['Lunch', 'Dinner']);
    expect(map['recipeTags'], ['Chicken', 'Comfort Food']);
    expect(map['priceEstimate'], 250);
    expect(map['location'], 'Manila');
    expect(map['youtubeEmbedUrl'], 'https://youtu.be/example');
    expect(map['visibility'], 'public');
    expect(map['monetization'], 'free');
    expect(map['createdAt'], isA<Timestamp>());
    expect(map['updatedAt'], isA<Timestamp>());
  });

  test(
    'upsert writes ingredients and watchHouseholdRecipes hydrates them',
    () async {
      await repo.upsert(privateRecipe);
      await repo.upsert(publicRecipe);

      final recipes = await repo.watchHouseholdRecipes(householdId).first;

      expect(recipes, hasLength(1));
      expect(recipes.single.name, 'Lentil Dal');
      expect(recipes.single.ingredients.single.ingredientId, 'lentils');
      expect(recipes.single.instructions, ['Simmer lentils.']);
    },
  );

  test('upsert removes ingredient documents no longer on the recipe', () async {
    await repo.upsert(privateRecipe);

    await repo.upsert(
      Recipe(
        id: privateRecipe.id,
        authorUserId: privateRecipe.authorUserId,
        householdId: privateRecipe.householdId,
        name: privateRecipe.name,
        description: privateRecipe.description,
        defaultServingSize: privateRecipe.defaultServingSize,
        mealTimeTags: privateRecipe.mealTimeTags,
        recipeTags: privateRecipe.recipeTags,
        priceEstimate: privateRecipe.priceEstimate,
        location: privateRecipe.location,
        visibility: privateRecipe.visibility,
        monetization: privateRecipe.monetization,
        createdAt: privateRecipe.createdAt,
        updatedAt: privateRecipe.updatedAt.add(const Duration(minutes: 1)),
        instructions: privateRecipe.instructions,
        ingredients: const [
          RecipeIngredient(
            id: 'ri-3',
            recipeId: 'private-1',
            ingredientId: 'garlic',
            quantity: 2,
            unit: UnitId.piece,
          ),
        ],
      ),
    );

    final ingredients = await db
        .collection('recipes')
        .doc(privateRecipe.id)
        .collection('ingredients')
        .get();
    expect(ingredients.docs.map((doc) => doc.id), ['ri-3']);
    final recipe = await repo.watchById(privateRecipe.id).first;
    expect(recipe!.ingredients.single.ingredientId, 'garlic');
  });

  test(
    'searchPublicRecipes applies budget and target serving normalization',
    () async {
      await repo.upsert(publicRecipe);
      await repo.upsert(
        Recipe(
          id: 'expensive',
          authorUserId: 'author-2',
          householdId: 'source-household',
          name: 'Expensive Roast',
          description: '',
          defaultServingSize: 4,
          mealTimeTags: const ['Dinner'],
          recipeTags: const ['Roast'],
          priceEstimate: 600,
          location: 'Manila',
          visibility: RecipeVisibility.public,
          monetization: RecipeMonetization.free,
          createdAt: now,
          updatedAt: now,
          instructions: const ['Roast.'],
          ingredients: const [],
        ),
      );

      final results = await repo.searchPublicRecipes(
        budget: 500,
        targetServings: 8,
      );

      expect(results.map((recipe) => recipe.id), ['public-1']);
    },
  );

  test(
    'savePublicRecipeAsLocalCopy creates editable local copy and saved link',
    () async {
      await repo.upsert(publicRecipe);

      final saved = await repo.savePublicRecipeAsLocalCopy(
        sourceRecipeId: publicRecipe.id,
        userId: 'user-1',
        householdId: householdId,
        localRecipeId: 'local-copy',
        savedRecipeId: 'saved-1',
        now: now.add(const Duration(days: 1)),
      );

      expect(saved.sourceRecipeId, publicRecipe.id);
      expect(saved.localRecipeId, 'local-copy');

      final local = await repo.watchById('local-copy').first;
      expect(local, isNotNull);
      expect(local!.visibility, RecipeVisibility.private);
      expect(local.authorUserId, 'user-1');
      expect(local.householdId, householdId);
      expect(local.sourceRecipeId, publicRecipe.id);
      expect(local.ingredients.single.recipeId, 'local-copy');

      final savedSnap = await db
          .collection('households')
          .doc(householdId)
          .collection('savedRecipes')
          .doc('saved-1')
          .get();
      expect(savedSnap.data()!['sourceRecipeId'], publicRecipe.id);
      expect(savedSnap.data()!['localRecipeId'], 'local-copy');
    },
  );

  test('delete removes recipe and ingredient documents', () async {
    await repo.upsert(privateRecipe);

    await repo.delete(privateRecipe.id);

    final recipeSnap = await db
        .collection('recipes')
        .doc(privateRecipe.id)
        .get();
    final ingredientSnap = await db
        .collection('recipes')
        .doc(privateRecipe.id)
        .collection('ingredients')
        .get();
    expect(recipeSnap.exists, isFalse);
    expect(ingredientSnap.docs, isEmpty);
  });
}
