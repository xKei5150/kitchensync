import 'dart:convert';
import 'dart:io';
import 'package:shopping_allocation_planner/oidc_verifier.dart';
import 'package:shopping_allocation_planner/private_planner.dart';
import 'package:shopping_allocation_planner/trusted_planning_source.dart';

Future<void> main() async {
  final environment = Platform.environment;
  final localIntegration = _localIntegrationEnabled(environment);
  final server = await HttpServer.bind(
    localIntegration ? InternetAddress.loopbackIPv4 : InternetAddress.anyIPv4,
    int.parse(Platform.environment['PORT'] ?? '8080'),
  );
  final planner = PrivateAllocationPlanner(
    source: localIntegration
        ? LocalIntegrationTrustedPlanningSource.fromEnvironment(environment)
        : FirestoreTrustedPlanningSource.fromEnvironment(environment),
  );
  final verifier = localIntegration
      ? LocalIntegrationOidcVerifier.fromEnvironment(environment)
      : GoogleOidcVerifier.fromEnvironment(environment);
  await for (final request in server) {
    if (request.method != 'POST' ||
        request.uri.path != '/internal/allocation-drafts') {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      continue;
    }
    try {
      await verifier.verify(request.headers.value('authorization') ?? '');
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('Expected request object');
      }
      final intent = _intent(Map<String, Object?>.from(decoded));
      final plan = await planner.plan(intent);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(plan));
    } on OidcVerificationException {
      request.response.statusCode = HttpStatus.unauthorized;
    } on FormatException {
      request.response.statusCode = HttpStatus.badRequest;
    } on StateError {
      request.response.statusCode = HttpStatus.serviceUnavailable;
    }
    await request.response.close();
  }
}

PlanningIntent _intent(Map<String, Object?> body) {
  const allowed = {'householdId', 'intent'};
  if (body.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Only planning intent is accepted');
  }
  String value(String key) => body[key] is String
      ? body[key]! as String
      : throw FormatException('Missing $key');
  final rawIntent = body['intent'];
  if (rawIntent is! Map) throw const FormatException('Missing intent');
  final intent = Map<String, Object?>.from(rawIntent);
  final kind = valueFrom(intent, 'kind');
  final allowedIntentKeys = switch (kind) {
    'shop_now' => {'kind', 'startDate', 'endDate'},
    'scheduled' => {
      'kind',
      'scheduleKey',
      'occurrenceDate',
      'startDate',
      'endDate',
    },
    'suggested' => {
      'kind',
      'originId',
      'windowStart',
      'windowEnd',
      'startDate',
      'endDate',
    },
    'emergency' => {'kind', 'startDate', 'endDate', 'demands'},
    _ => throw const FormatException('Unsupported planning intent kind'),
  };
  if (intent.keys.any((key) => !allowedIntentKeys.contains(key))) {
    throw const FormatException(
      'Only typed planning intent fields are accepted',
    );
  }
  final startDate = DateTime.parse(valueFrom(intent, 'startDate'));
  final endDate = DateTime.parse(valueFrom(intent, 'endDate'));
  final occurrenceDate = kind == 'scheduled'
      ? DateTime.parse(valueFrom(intent, 'occurrenceDate'))
      : null;
  return PlanningIntent(
    householdId: value('householdId'),
    startDate: startDate,
    endDate: endDate,
    kind: kind,
    scheduleKey: kind == 'scheduled' ? valueFrom(intent, 'scheduleKey') : null,
    occurrenceDate: occurrenceDate,
    originId: kind == 'suggested' ? valueFrom(intent, 'originId') : null,
    emergencyDemands: kind == 'emergency'
        ? _emergencyDemands(intent['demands'])
        : const [],
  );
}

List<EmergencyPlanningDemand> _emergencyDemands(Object? value) {
  if (value is! List || value.isEmpty) {
    throw const FormatException('Emergency demands are required');
  }
  return value
      .map((raw) {
        if (raw is! Map)
          throw const FormatException('Invalid emergency demand');
        final demand = Map<String, Object?>.from(raw);
        const allowed = {'ingredientId', 'quantityNeeded', 'unit'};
        if (demand.keys.any((key) => !allowed.contains(key))) {
          throw const FormatException(
            'Only emergency demand fields are accepted',
          );
        }
        final quantity = demand['quantityNeeded'];
        if (quantity is! num || !quantity.isFinite || quantity <= 0) {
          throw const FormatException('Emergency demand quantity is invalid');
        }
        return EmergencyPlanningDemand(
          ingredientId: valueFrom(demand, 'ingredientId'),
          quantityNeeded: quantity.toDouble(),
          unit: valueFrom(demand, 'unit'),
        );
      })
      .toList(growable: false);
}

bool _localIntegrationEnabled(Map<String, String> environment) =>
    environment['LOCAL_PLANNER_INTEGRATION_TEST'] == 'true' &&
    environment['FUNCTIONS_EMULATOR'] == 'true';

String valueFrom(Map<String, Object?> body, String key) => body[key] is String
    ? body[key]! as String
    : throw FormatException('Missing $key');
