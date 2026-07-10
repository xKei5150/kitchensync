// SIZE_OK: product loop emulator coverage intentionally stays end-to-end.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('emulator persists the recipe-to-waste product loop', (
    tester,
  ) async {
    await bootEmulatedApp();

    final authSession = await withTimeout(
      'create auth emulator session',
      _createAuthSession,
    );
    await withTimeout(
      'sign in app test user',
      () => FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authSession.email,
        password: authSession.password,
      ),
    );
    final uid = authSession.uid;
    final token = authSession.idToken;
    final householdId = 'itest-loop-$uid';
    final now = DateTime(2026, 7, 6, 9);
    final cookTime = DateTime(2026, 7, 6, 20);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await withTimeout(
      'seed admin household',
      () => _seedAdminHousehold(
        uid: uid,
        householdId: householdId,
        authToken: token,
        now: Timestamp.fromDate(now),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(now)),
        sharedPreferencesProvider.overrideWithValue(preferences),
        activeUserIdProvider.overrideWithValue(uid),
        idGeneratorProvider.overrideWithValue(
          FakeIdGenerator(const [
            'braise',
            'tomato-line',
            'bean-custom',
            'bean-line',
            'shop-now',
            'line-1',
            'line-2',
            'tomato-pantry',
            'tomato-purchase',
            'pepper-pantry',
            'pepper-purchase',
            'leftover-1',
            'waste-1',
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await withTimeout(
      'wait for active household context',
      () => _waitForActiveHousehold(container, householdId),
    );

    final recipe = await withTimeout(
      'create dictionary-linked recipe',
      () async {
        final recipes = await container
            .read(recipeImportControllerProvider)
            .importDrafts([
              const RecipeDraft(
                name: 'Tomato and bean braise',
                defaultServingSize: 2,
                timeTags: ['Dinner'],
                recipeTags: ['budget'],
                description: 'Manual recipe for integration coverage.',
                ingredients: [
                  RecipeIngredientDraft(
                    name: 'Emulator tomato',
                    quantity: 400,
                    unit: UnitId.g,
                  ),
                  RecipeIngredientDraft(
                    name: 'Emulator bean',
                    quantity: 2,
                    unit: UnitId.piece,
                  ),
                ],
                instructions: ['Simmer.'],
                visibility: RecipeVisibility.private,
              ),
            ]);
        return recipes.single;
      },
    );
    final tomatoIngredientId = recipe.ingredients
        .singleWhere((ingredient) => ingredient.unit == UnitId.g)
        .ingredientId;
    final beanIngredientId = recipe.ingredients
        .singleWhere((ingredient) => ingredient.unit == UnitId.piece)
        .ingredientId;
    expect(recipe.ingredients.map((ingredient) => ingredient.ingredientId), [
      tomatoIngredientId,
      beanIngredientId,
    ]);

    final meal = MealScheduleEntry(
      id: 'meal-1',
      recipeId: recipe.id,
      date: DateTime(2026, 7, 6),
      mealLabel: 'Dinner',
      servingSize: 2,
    );
    await withTimeout(
      'schedule meal',
      () => container
          .read(calendarRepositoryProvider)
          .upsertMeal(householdId: householdId, entry: meal),
    );

    await withTimeout(
      'seed partial pantry',
      () => container.read(addPantryItemProvider)(
        AddPantryItemParams(
          householdId: householdId,
          ingredientId: tomatoIngredientId,
          quantity: 100,
          unit: UnitId.g,
          section: PantrySection.food,
        ),
      ),
    );

    final shopping = container.read(shoppingPlanningControllerProvider);
    final list = await withTimeout(
      'generate shopping list',
      () => shopping.generateAdaptiveList(
        type: ShoppingListType.emergency,
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 6),
      ),
    );
    expect(list.items.map((item) => item.ingredientId).toSet(), {
      beanIngredientId,
      tomatoIngredientId,
    });

    final beanLine = list.items.singleWhere(
      (item) => item.ingredientId == beanIngredientId,
    );
    final tomatoLine = list.items.singleWhere(
      (item) => item.ingredientId == tomatoIngredientId,
    );

    await withTimeout('mark shopping rows', () async {
      await shopping.updateItemStatus(
        listId: list.id,
        itemId: beanLine.id,
        status: ShoppingListItemStatus.bought,
      );
      await shopping.updateItemStatus(
        listId: list.id,
        itemId: tomatoLine.id,
        status: ShoppingListItemStatus.substituted,
        substituteIngredientId: 'pepper',
        substituteQuantity: 300,
        substituteUnit: UnitId.g,
      );
    });
    final readyList = await withTimeout(
      'load updated shopping list',
      () => container
          .read(shoppingRepositoryProvider)
          .watchList(householdId: householdId, listId: list.id)
          .first,
    );
    await withTimeout(
      'complete shopping',
      () => shopping.completeList(readyList!),
    );

    final pantryRepository = container.read(pantryRepositoryProvider);
    final purchases = await withTimeout(
      'watch purchase history',
      () => container
          .read(purchaseHistoryRepositoryProvider)
          .watchByHousehold(householdId)
          .first,
    );
    expect(purchases.map((purchase) => purchase.ingredientId).toSet(), {
      beanIngredientId,
      'pepper',
    });
    expect(
      await pantryRepository.findByIngredientUnit(
        householdId: householdId,
        ingredientId: 'pepper',
        unit: UnitId.g,
        section: PantrySection.food,
      ),
      isNotNull,
    );

    final overriddenMeal = await withTimeout(
      'load meal with substitution override',
      () => container
          .read(calendarRepositoryProvider)
          .watchMealsInRange(
            householdId: householdId,
            startDate: DateTime(2026, 7, 6),
            endDate: DateTime(2026, 7, 6),
          )
          .first
          .then((meals) => meals.single),
    );
    expect(
      overriddenMeal.ingredientOverrides.single.substituteIngredientId,
      'pepper',
    );

    final cookingContainer = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(cookTime)),
        sharedPreferencesProvider.overrideWithValue(preferences),
        activeUserIdProvider.overrideWithValue(uid),
        idGeneratorProvider.overrideWithValue(
          FakeIdGenerator(const ['leftover-1', 'waste-1']),
        ),
      ],
    );
    addTearDown(cookingContainer.dispose);
    await withTimeout(
      'wait for cooking active household context',
      () => _waitForActiveHousehold(cookingContainer, householdId),
    );

    final cooking = cookingContainer.read(cookingLifecycleControllerProvider);
    await withTimeout('mark cooked', () => cooking.markCooked(overriddenMeal));
    final cookedMeal = await withTimeout(
      'load cooked meal',
      () => cookingContainer
          .read(calendarRepositoryProvider)
          .watchMealsInRange(
            householdId: householdId,
            startDate: DateTime(2026, 7, 6),
            endDate: DateTime(2026, 7, 6),
          )
          .first
          .then((meals) => meals.single),
    );
    expect(cookedMeal.state, ScheduledMealState.cooked);

    final leftover = await withTimeout(
      'save leftovers',
      () => cooking.saveLeftovers(meal: cookedMeal, servings: 1),
    );
    await withTimeout(
      'schedule leftover',
      () => cooking.scheduleLeftoverMeal(
        leftover: leftover,
        date: DateTime(2026, 7, 7),
        mealLabel: 'Lunch',
      ),
    );
    await withTimeout(
      'mark leftover spoiled',
      () => cooking.markLeftoverSpoiled(leftover),
    );

    final wasteEvents = await withTimeout(
      'watch waste events',
      () => cookingContainer
          .read(wasteRepositoryProvider)
          .watchByHousehold(householdId)
          .first,
    );
    expect(wasteEvents.single.id, 'waste-1');
    expect(wasteEvents.single.ingredientId, 'leftover-braise');

    final leftoverMeal = await withTimeout(
      'watch scheduled leftover meal',
      () => cookingContainer
          .read(calendarRepositoryProvider)
          .watchMealsInRange(
            householdId: householdId,
            startDate: DateTime(2026, 7, 7),
            endDate: DateTime(2026, 7, 7),
          )
          .first
          .then((meals) => meals.single),
    );
    expect(leftoverMeal.linkedLeftoverId, leftover.id);
    expect(leftoverMeal.state, ScheduledMealState.leftover);
  });
}

class _AuthSession {
  const _AuthSession({
    required this.uid,
    required this.email,
    required this.password,
    required this.idToken,
  });

  final String uid;
  final String email;
  final String password;
  final String idToken;
}

Future<_AuthSession> _createAuthSession() async {
  const authHost = String.fromEnvironment(
    'AUTH_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  const authPort = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'loop-$stamp@example.test';
  const password = 'Integration-password-123';
  final uri = Uri.http(
    '$authHost:$authPort',
    '/identitytoolkit.googleapis.com/v1/accounts:signUp',
    {'key': 'emulator-api-key'},
  );
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Auth emulator signup failed ${response.statusCode}: $body',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return _AuthSession(
      uid: json['localId'] as String,
      email: email,
      password: password,
      idToken: json['idToken'] as String,
    );
  } finally {
    client.close(force: true);
  }
}

Future<void> _seedAdminHousehold({
  required String uid,
  required String householdId,
  required String authToken,
  required Timestamp now,
}) async {
  await withTimeout(
    'seed user active household',
    () => _patchDocument(
      'users/$uid',
      authToken: authToken,
      fields: {
        'activeHouseholdId': _stringValue(householdId),
        'isPremium': _booleanValue(true),
        'updatedAt': _timestampValue(now),
      },
    ),
  );
  await withTimeout(
    'seed household',
    () => _patchDocument(
      'households/$householdId',
      authToken: authToken,
      fields: {
        'name': _stringValue('Integration kitchen'),
        'creatorUserId': _stringValue(uid),
        'isJoint': _booleanValue(true),
        'hasPremium': _booleanValue(true),
        'maxMembers': _integerValue(6),
        'createdAt': _timestampValue(now),
        'updatedAt': _timestampValue(now),
      },
    ),
  );
  await withTimeout(
    'seed admin member',
    () => _patchDocument(
      'households/$householdId/members/$uid',
      authToken: authToken,
      fields: {
        'role': _stringValue('admin'),
        'joinedAt': _timestampValue(now),
        'updatedAt': _timestampValue(now),
      },
    ),
  );
}

Future<void> _patchDocument(
  String path, {
  required String authToken,
  required Map<String, Map<String, Object?>> fields,
}) async {
  const host = String.fromEnvironment(
    'FIRESTORE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  const port = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );
  final uri = Uri.http(
    '$host:$port',
    '/v1/projects/kitchensync-dev-da503/databases/(default)/documents/$path',
  );
  final client = HttpClient();
  try {
    final request = await client.patchUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode({'fields': fields}));
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Firestore REST seed failed ${response.statusCode}: $body',
      );
    }
  } finally {
    client.close(force: true);
  }
}

Map<String, Object?> _stringValue(String value) => {'stringValue': value};

Map<String, Object?> _booleanValue(bool value) => {'booleanValue': value};

Map<String, Object?> _integerValue(int value) => {'integerValue': '$value'};

Map<String, Object?> _timestampValue(Timestamp value) => {
  'timestampValue': value.toDate().toUtc().toIso8601String(),
};

Future<ActiveHouseholdContext> _waitForActiveHousehold(
  ProviderContainer container,
  String householdId,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 10)) {
    final context = container.read(activeHouseholdContextProvider);
    if (context?.id == householdId) {
      return context!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Active household context did not resolve to $householdId.');
}
