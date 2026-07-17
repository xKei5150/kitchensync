import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_allocation_planner/oidc_verifier.dart';
import 'package:shopping_allocation_planner/private_planner.dart';
import 'package:shopping_allocation_planner/trusted_planning_source.dart';

void main() {
  test(
    'uses the canonical engine and registry for a normalized pantry deficit',
    () async {
      final result =
          await PrivateAllocationPlanner(source: _FakeTrustedSource()).plan(
            PlanningIntent(
              householdId: 'household-1',
              startDate: DateTime(2026, 7, 13),
              endDate: DateTime(2026, 7, 13),
            ),
          );
      final list = result['list']! as Map<String, Object?>;
      expect(list['items'], [
        {
          'itemId': 'rice__g',
          'ingredientId': 'rice',
          'quantityNeeded': 750.0,
          'unit': 'g',
          'sourceMealLinks': [
            {
              'mealEntryId': 'meal-1',
              'recipeId': 'recipe-1',
              'date': '2026-07-13',
              'quantity': 750.0,
            },
          ],
        },
      ]);
    },
  );

  test('keeps scheduled occurrence metadata server-owned', () async {
    final result = await PrivateAllocationPlanner(source: _FakeTrustedSource())
        .plan(
          PlanningIntent(
            householdId: 'household-1',
            startDate: DateTime(2026, 7, 7),
            endDate: DateTime(2026, 7, 13),
            kind: 'scheduled',
            scheduleKey: 'weekly-1-2026-07-07',
            occurrenceDate: DateTime(2026, 7, 13),
          ),
        );

    expect((result['list']! as Map<String, Object?>)['type'], 'scheduled');
    expect(
      (result['list']! as Map<String, Object?>)['originId'],
      'weekly-1-2026-07-07',
    );
  });

  test('keeps suggested recovery origin and window server-owned', () async {
    final result = await PrivateAllocationPlanner(source: _FakeTrustedSource())
        .plan(
          PlanningIntent(
            householdId: 'household-1',
            startDate: DateTime(2026, 7, 13),
            endDate: DateTime(2026, 7, 19),
            kind: 'suggested',
            originId: 'recovery:core:v1',
          ),
        );

    final list = result['list']! as Map<String, Object?>;
    expect(list['type'], 'suggested');
    expect(list['originId'], 'recovery:core:v1');
    expect(
      (result['intent']! as Map<String, Object?>)['windowEnd'],
      '2026-07-19',
    );
    expect(result['listId'], 'suggested_recovery_20260713_20260719');
  });

  test(
    'derives an emergency list from typed demand without source links',
    () async {
      final result =
          await PrivateAllocationPlanner(source: _FakeTrustedSource()).plan(
            PlanningIntent(
              householdId: 'household-1',
              startDate: DateTime(2026, 7, 13),
              endDate: DateTime(2026, 7, 13),
              kind: 'emergency',
              emergencyDemands: const [
                EmergencyPlanningDemand(
                  ingredientId: 'tomato',
                  quantityNeeded: 300,
                  unit: 'g',
                ),
              ],
            ),
          );

      expect((result['list']! as Map<String, Object?>)['type'], 'emergency');
      expect((result['list']! as Map<String, Object?>)['items'], [
        {
          'itemId': 'tomato__g',
          'ingredientId': 'tomato',
          'quantityNeeded': 300.0,
          'unit': 'g',
          'sourceMealLinks': <Object?>[],
        },
      ]);
    },
  );

  test(
    'fails closed when the Firestore workload identity configuration is absent',
    () {
      expect(
        () => FirestoreTrustedPlanningSource.fromEnvironment(const {}),
        throwsStateError,
      );
    },
  );

  test('rejects local trusted state without the Functions emulator', () {
    expect(
      () => LocalIntegrationTrustedPlanningSource.fromEnvironment(const {
        'LOCAL_PLANNER_INTEGRATION_TEST': 'true',
      }),
      throwsStateError,
    );
  });

  test('rejects the local static token without the Functions emulator', () {
    expect(
      () => LocalIntegrationOidcVerifier.fromEnvironment(const {
        'LOCAL_PLANNER_INTEGRATION_TEST': 'true',
        'LOCAL_PLANNER_OIDC_TOKEN': 'token',
      }),
      throwsStateError,
    );
  });

  test('accepts only the configured Cloud Run caller identity', () async {
    final verifier = GoogleOidcVerifier(
      audience: 'https://planner.example.internal',
      callerServiceAccount: 'functions@example.iam.gserviceaccount.com',
      client: MockClient(
        (_) async => http.Response(
          '{"aud":"https://planner.example.internal",'
          '"iss":"https://accounts.google.com",'
          '"email":"functions@example.iam.gserviceaccount.com",'
          '"email_verified":"true"}',
          200,
        ),
      ),
    );

    await verifier.verify('Bearer signed-token');
  });

  test('rejects an ID token for a different Cloud Run audience', () async {
    final verifier = GoogleOidcVerifier(
      audience: 'https://planner.example.internal',
      callerServiceAccount: 'functions@example.iam.gserviceaccount.com',
      client: MockClient(
        (_) async => http.Response(
          '{"aud":"https://other.example.internal",'
          '"iss":"https://accounts.google.com",'
          '"email":"functions@example.iam.gserviceaccount.com",'
          '"email_verified":"true"}',
          200,
        ),
      ),
    );

    expect(
      () => verifier.verify('Bearer signed-token'),
      throwsA(isA<OidcVerificationException>()),
    );
  });
}

final class _FakeTrustedSource implements TrustedPlanningSource {
  @override
  Future<Map<String, Object?>> load(PlanningIntent intent) async => {
    'householdId': 'household-1',
    'listId': 'shop-now-1',
    'now': '2026-07-13',
    'startDate': '2026-07-13',
    'endDate': '2026-07-13',
    'meals': [
      {
        'id': 'meal-1',
        'recipeId': 'recipe-1',
        'date': '2026-07-13',
        'servingSize': 2,
      },
    ],
    'recipes': [
      {
        'id': 'recipe-1',
        'defaultServingSize': 2,
        'ingredients': [
          {'ingredientId': 'rice', 'quantity': 1, 'unit': 'kg'},
        ],
      },
    ],
    'pantryItems': [
      {'id': 'pantry-1', 'ingredientId': 'rice', 'quantity': 250, 'unit': 'g'},
    ],
  };
}
