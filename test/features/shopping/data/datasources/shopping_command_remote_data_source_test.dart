import 'package:cloud_functions/cloud_functions.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_command_remote_data_source.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var functionsInstance = 0;
  late _FakeFirebaseFunctionsPlatform platform;
  late ShoppingCommandRemoteDataSource dataSource;

  setUp(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _FakeFirebaseFunctionsPlatform();
    FirebaseFunctionsPlatform.instance = platform;
    dataSource = ShoppingCommandRemoteDataSource(
      FirebaseFunctions.instanceFor(region: 'test-${functionsInstance++}'),
    );
  });

  test(
    'legacy client list upsert is rejected before any callable payload is sent',
    () async {
      expect(
        () => dataSource.upsertList(_upsertCommand()),
        throwsUnsupportedError,
      );
      expect(platform.callableName, isNull);
      expect(platform.parameters, isNull);
    },
  );

  test('allocation flow submits one typed intent and receives a '
      'server-derived list only', () async {
    platform.response = const {
      'listId': 'server-derived-list-1',
      'status': 'pending',
      'revision': 0,
      'alreadyApplied': false,
    };

    final result = await dataSource.createAndConsumeAllocation(
      ConsumeShoppingAllocationIntent(
        commandId: 'command-1',
        intent: ShopNowShoppingAllocationIntent(
          householdId: 'household-1',
          startDate: DateTime(2026, 7, 5),
          endDate: DateTime(2026, 7, 11),
        ),
      ),
    );

    expect(platform.calls.map((call) => call.$1), ['planShoppingAllocation']);
    expect(platform.calls.single.$2, {
      'householdId': 'household-1',
      'commandId': 'command-1',
      'intent': {
        'kind': 'shop_now',
        'startDate': '2026-07-05',
        'endDate': '2026-07-11',
      },
    });
    expect(
      platform.calls.single.$2.toString(),
      isNot(contains('sourceMealLinks')),
    );
    expect(platform.calls.single.$2.toString(), isNot(contains('items')));
    expect(platform.calls.single.$2.toString(), isNot(contains('listId')));
    expect(platform.calls.single.$2.toString(), isNot(contains('draftId')));
    expect(result.revision, 0);
  });

  test(
    'mutateItem sends each exact mutation shape without source links',
    () async {
      platform.response = const {
        'listId': 'list-1',
        'status': 'cancelled',
        'revision': 5,
        'alreadyApplied': true,
      };
      const mutations = <ShoppingListItemMutation>[
        AddShoppingListItemMutation(
          ingredientId: 'ingredient-2',
          quantityNeeded: 3,
          purchasedQuantity: null,
          unit: UnitId.kg,
          status: ShoppingListItemStatus.unchecked,
          substituteIngredientId: null,
          substituteQuantity: null,
          substituteUnit: null,
        ),
        RemoveShoppingListItemMutation(),
        SetShoppingListItemNeededQuantityMutation(quantityNeeded: 4),
        SetShoppingListItemPurchasedQuantityMutation(purchasedQuantity: 2),
        SetShoppingListItemStatusMutation(
          status: ShoppingListItemStatus.substituted,
          purchasedQuantity: 1,
          substituteIngredientId: 'ingredient-3',
          substituteQuantity: 1,
          substituteUnit: UnitId.kg,
        ),
      ];
      final expected = <Map<String, Object?>>[
        {
          'kind': 'add',
          'ingredientId': 'ingredient-2',
          'quantityNeeded': 3.0,
          'purchasedQuantity': null,
          'unit': 'kg',
          'status': 'unchecked',
          'substituteIngredientId': null,
          'substituteQuantity': null,
          'substituteUnit': null,
        },
        {'kind': 'remove'},
        {'kind': 'setNeededQuantity', 'quantityNeeded': 4.0},
        {'kind': 'setPurchasedQuantity', 'purchasedQuantity': 2.0},
        {
          'kind': 'setStatus',
          'status': 'substituted',
          'purchasedQuantity': 1.0,
          'substituteIngredientId': 'ingredient-3',
          'substituteQuantity': 1.0,
          'substituteUnit': 'kg',
        },
      ];

      for (var index = 0; index < mutations.length; index++) {
        final result = await dataSource.mutateItem(
          ShoppingListItemMutationCommand(
            householdId: 'household-1',
            listId: 'list-1',
            itemId: 'item-1',
            commandId: 'command-${index + 1}',
            expectedRevision: 4,
            mutation: mutations[index],
          ),
        );

        expect(platform.callableName, 'mutateShoppingListItem');
        expect(platform.parameters, {
          'householdId': 'household-1',
          'listId': 'list-1',
          'itemId': 'item-1',
          'commandId': 'command-${index + 1}',
          'expectedRevision': 4,
          'mutation': expected[index],
        });
        expect(
          platform.parameters.toString(),
          isNot(contains('sourceMealLinks')),
        );
        expect(result.status, ShoppingCommandStatus.cancelled);
        expect(result.revision, 5);
        expect(result.alreadyApplied, isTrue);
      }
    },
  );

  test('cancelList invokes the trusted cancellation callable', () async {
    platform.response = const {
      'listId': 'list-1',
      'status': 'cancelled',
      'alreadyApplied': false,
    };

    final result = await dataSource.cancelList(
      const ShoppingCommandRequest(
        householdId: 'household-1',
        listId: 'list-1',
        commandId: 'cancel-command-1',
      ),
    );

    expect(platform.callableName, 'cancelShoppingList');
    expect(platform.parameters, {
      'householdId': 'household-1',
      'listId': 'list-1',
      'commandId': 'cancel-command-1',
    });
    expect(result.status, ShoppingCommandStatus.cancelled);
  });

  test(
    'emergency allocation sends demand-only intent without list payloads',
    () async {
      platform.response = const {
        'listId': 'emergency_2026-07-05_2026-07-05',
        'status': 'pending',
        'revision': 0,
        'alreadyApplied': false,
      };

      await dataSource.createAndConsumeAllocation(
        ConsumeShoppingAllocationIntent(
          commandId: 'emergency-command',
          intent: EmergencyShoppingAllocationIntent(
            householdId: 'household-1',
            startDate: DateTime(2026, 7, 5),
            endDate: DateTime(2026, 7, 5),
            demands: const [
              EmergencyShoppingDemand(
                ingredientId: 'tomato',
                quantityNeeded: 300,
                unit: UnitId.g,
              ),
            ],
          ),
        ),
      );

      expect(platform.parameters, {
        'householdId': 'household-1',
        'commandId': 'emergency-command',
        'intent': {
          'kind': 'emergency',
          'startDate': '2026-07-05',
          'endDate': '2026-07-05',
          'demands': [
            {'ingredientId': 'tomato', 'quantityNeeded': 300.0, 'unit': 'g'},
          ],
        },
      });
      expect(
        platform.parameters.toString(),
        isNot(contains('sourceMealLinks')),
      );
      expect(platform.parameters.toString(), isNot(contains('items')));
    },
  );

  test(
    'write response rejects extra, missing, mistyped, or non-map fields',
    () async {
      for (final response in <Object?>[
        null,
        'not-a-map',
        {
          'listId': 'list-1',
          'status': 'pending',
          'revision': 0,
          'alreadyApplied': false,
          'extra': true,
        },
        {'listId': 'list-1', 'status': 'pending', 'alreadyApplied': false},
        {
          'listId': 'list-1',
          'status': 'pending',
          'revision': 0.5,
          'alreadyApplied': false,
        },
      ]) {
        platform.response = response;

        expect(
          () => dataSource.upsertList(_upsertCommand()),
          throwsUnsupportedError,
        );
      }
    },
  );

  test('write response rejects the wrong list, status, and revision', () async {
    for (final response in <Object?>[
      {
        'listId': 'list-2',
        'status': 'pending',
        'revision': 0,
        'alreadyApplied': false,
      },
      {
        'listId': 'list-1',
        'status': 'completed',
        'revision': 0,
        'alreadyApplied': false,
      },
      {
        'listId': 'list-1',
        'status': 'pending',
        'revision': -1,
        'alreadyApplied': false,
      },
    ]) {
      platform.response = response;

      expect(
        () => dataSource.upsertList(_upsertCommand()),
        throwsUnsupportedError,
      );
    }
  });

  test('legacy commands preserve their exact response shapes', () async {
    platform.response = const {
      'listId': 'list-1',
      'status': 'completed',
      'alreadyApplied': false,
      'completionId': 'command-1',
    };

    final completed = await dataSource.completeList(_legacyCommand);

    expect(platform.parameters, const {
      'householdId': 'household-1',
      'listId': 'list-1',
      'commandId': 'command-1',
    });
    expect(completed.status, ShoppingCommandStatus.completed);
    expect(completed.completionId, 'command-1');
    expect(completed.revision, isNull);

    platform.response = const {
      'listId': 'list-1',
      'status': 'deleted',
      'alreadyApplied': true,
    };
    final deleted = await dataSource.deleteList(_legacyCommand);

    expect(deleted.status, ShoppingCommandStatus.deleted);
    expect(deleted.completionId, isNull);
  });

  test(
    'legacy response rejects extra fields and invalid completionId',
    () async {
      for (final response in <Object?>[
        {
          'listId': 'list-1',
          'status': 'deleted',
          'alreadyApplied': false,
          'completionId': 'not-allowed',
        },
        {
          'listId': 'list-1',
          'status': 'completed',
          'alreadyApplied': false,
          'completionId': 1,
        },
        {
          'listId': 'list-1',
          'status': 'completed',
          'alreadyApplied': false,
          'completionId': null,
        },
      ]) {
        platform.response = response;

        await expectLater(
          response is Map<Object?, Object?> && response['status'] == 'deleted'
              ? dataSource.deleteList(_legacyCommand)
              : dataSource.completeList(_legacyCommand),
          throwsFormatException,
        );
      }
    },
  );
}

const _legacyCommand = ShoppingCommandRequest(
  householdId: 'household-1',
  listId: 'list-1',
  commandId: 'command-1',
);

ShoppingListUpsertCommand _upsertCommand() => ShoppingListUpsertCommand(
  householdId: 'household-1',
  listId: 'list-1',
  commandId: 'command-1',
  expectedRevision: null,
  list: ShoppingListRecord(
    id: 'list-1',
    householdId: 'household-1',
    type: ShoppingListType.shopNow,
    shoppingDate: DateTime(2026, 7, 11),
    generatedForRangeStart: DateTime(2026, 7, 5),
    generatedForRangeEnd: DateTime(2026, 7, 11),
    status: ShoppingListStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    items: [
      ShoppingListItemRecord(
        id: 'item-1',
        shoppingListId: 'list-1',
        ingredientId: 'ingredient-1',
        quantityNeeded: 2.5,
        unit: UnitId.kg,
        status: ShoppingListItemStatus.unchecked,
        sourceMealLinks: [
          MealSourceLink(
            mealEntryId: 'meal-1',
            recipeId: 'recipe-1',
            date: DateTime(2026, 7, 10),
            quantity: 1.25,
          ),
        ],
      ),
    ],
  ),
);

final class _FakeFirebaseFunctionsPlatform extends FirebaseFunctionsPlatform {
  _FakeFirebaseFunctionsPlatform() : super(null, 'us-central1');

  String? callableName;
  Object? parameters;
  Object? response;
  final responses = <Object?>[];
  final calls = <(String, Object?)>[];

  @override
  FirebaseFunctionsPlatform delegateFor({
    FirebaseApp? app,
    required String region,
  }) => this;

  @override
  HttpsCallablePlatform httpsCallable(
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) {
    callableName = name;
    return _FakeHttpsCallablePlatform(this, origin, name, options);
  }
}

final class _FakeHttpsCallablePlatform extends HttpsCallablePlatform {
  _FakeHttpsCallablePlatform(
    this._functions,
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) : super(_functions, origin, name, options, null);

  final _FakeFirebaseFunctionsPlatform _functions;

  @override
  Future<Object?> call([Object? parameters]) async {
    _functions.parameters = parameters;
    _functions.calls.add((name ?? '', parameters));
    if (_functions.responses.isNotEmpty) {
      return _functions.responses.removeAt(0);
    }
    return _functions.response;
  }
}
