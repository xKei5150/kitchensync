import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shopping_allocation_planner/private_planner.dart';

final class FirestoreTrustedPlanningSource implements TrustedPlanningSource {
  FirestoreTrustedPlanningSource({
    required this.projectId,
    required this._clientFactory,
  });

  factory FirestoreTrustedPlanningSource.fromEnvironment(
    Map<String, String> environment,
  ) {
    final projectId = environment['PLANNER_FIRESTORE_PROJECT_ID'];
    if (projectId == null || projectId.isEmpty) {
      throw StateError('PLANNER_FIRESTORE_PROJECT_ID is required');
    }
    return FirestoreTrustedPlanningSource(
      projectId: projectId,
      clientFactory: () => clientViaApplicationDefaultCredentials(
        scopes: const ['https://www.googleapis.com/auth/datastore'],
      ),
    );
  }

  final String projectId;
  final Future<http.Client> Function() _clientFactory;

  @override
  Future<Map<String, Object?>> load(PlanningIntent intent) async {
    final client = await _clientFactory();
    try {
      final meals = await _collection(
        client,
        'households/${intent.householdId}/mealScheduleEntries',
      );
      final pantryItems = await _collection(
        client,
        'households/${intent.householdId}/pantryItems',
      );
      final recipes = await _householdRecipes(client, intent.householdId);
      return {
        'householdId': intent.householdId,
        'now': _date(DateTime.now().toUtc()),
        'startDate': _date(intent.startDate),
        'endDate': _date(intent.endDate),
        'meals': meals.where((meal) => _inRange(meal['date'], intent)).toList(),
        'recipes': recipes,
        'pantryItems': pantryItems,
      };
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, Object?>>> _collection(
    http.Client client,
    String path,
  ) async {
    final response = await client.get(_uri('documents/$path?pageSize=1000'));
    if (response.statusCode != 200) throw StateError('Firestore read failed');
    final payload = _object(jsonDecode(response.body));
    final documents = payload['documents'];
    if (documents is! List) return const [];
    return documents.map(_document).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> _householdRecipes(
    http.Client client,
    String householdId,
  ) async {
    final response = await client.post(
      _uri('documents:runQuery'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': 'recipes'},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'householdId'},
              'op': 'EQUAL',
              'value': {'stringValue': householdId},
            },
          },
        },
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Firestore recipe read failed');
    }
    final rows = jsonDecode(response.body);
    if (rows is! List) {
      throw const FormatException('Invalid Firestore query response');
    }
    final recipes = <Map<String, Object?>>[];
    for (final row in rows) {
      final document = _object(row)['document'];
      if (document is! Map) continue;
      final recipe = _document(document);
      final id = recipe['id'];
      if (id is! String) {
        throw const FormatException('Firestore recipe id is missing');
      }
      recipes.add({
        'id': id,
        'defaultServingSize': recipe['defaultServingSize'],
        'ingredients': await _collection(client, 'recipes/$id/ingredients'),
      });
    }
    return recipes;
  }

  Uri _uri(String path) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/$path',
  );
}

final class LocalIntegrationTrustedPlanningSource
    implements TrustedPlanningSource {
  const LocalIntegrationTrustedPlanningSource();

  factory LocalIntegrationTrustedPlanningSource.fromEnvironment(
    Map<String, String> environment,
  ) {
    if (environment['LOCAL_PLANNER_INTEGRATION_TEST'] != 'true' ||
        environment['FUNCTIONS_EMULATOR'] != 'true') {
      throw StateError('Local planner integration source is disabled');
    }
    return const LocalIntegrationTrustedPlanningSource();
  }

  @override
  Future<Map<String, Object?>> load(PlanningIntent intent) async => {
    'householdId': intent.householdId,
    'now': '2026-07-13',
    'startDate': _date(intent.startDate),
    'endDate': _date(intent.endDate),
    'meals': [
      {
        'id': 'trusted-meal-${_date(intent.startDate).replaceAll('-', '')}',
        'recipeId': 'trusted-recipe',
        'date': _date(intent.startDate),
        'servingSize': 2,
      },
    ],
    'recipes': [
      {
        'id': 'trusted-recipe',
        'defaultServingSize': 2,
        'ingredients': [
          {'ingredientId': 'rice', 'quantity': 1, 'unit': 'kg'},
        ],
      },
    ],
    'pantryItems': [
      {
        'id': 'trusted-pantry',
        'ingredientId': 'rice',
        'quantity': 250,
        'unit': 'g',
      },
    ],
  };
}

Map<String, Object?> _document(Object? raw) {
  final document = _object(raw);
  final name = document['name'];
  if (name is! String) {
    throw const FormatException('Firestore document name is missing');
  }
  return {'id': name.split('/').last, ..._fields(document['fields'])};
}

Map<String, Object?> _fields(Object? raw) =>
    _object(raw).map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? raw) {
  final value = _object(raw);
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('integerValue')) {
    return int.parse(value['integerValue']! as String);
  }
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('mapValue')) {
    return _fields(_object(value['mapValue'])['fields']);
  }
  if (value.containsKey('arrayValue')) {
    final values = _object(value['arrayValue'])['values'];
    return values is List
        ? values.map(_value).toList(growable: false)
        : const [];
  }
  throw const FormatException('Unsupported Firestore value');
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected Firestore object');
  return Map<String, Object?>.from(value);
}

bool _inRange(Object? value, PlanningIntent intent) {
  if (value is! String) throw const FormatException('Meal date is missing');
  return value.compareTo(_date(intent.startDate)) >= 0 &&
      value.compareTo(_date(intent.endDate)) <= 0;
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
