import 'package:cloud_functions/cloud_functions.dart';

typedef HouseholdInviteCallableInvoker =
    Future<Object?> Function(String name, Map<String, Object?> data);

enum HouseholdInviteRole { member, shopper, cook }

class HouseholdInviteIssueResult {
  const HouseholdInviteIssueResult({
    required this.requestId,
    required this.householdId,
    required this.role,
    required this.inviteId,
    required this.alreadyIssued,
    required this.inviteToken,
  });

  final String requestId;
  final String householdId;
  final HouseholdInviteRole role;
  final String inviteId;
  final bool alreadyIssued;

  /// Present only for a fresh issue response. Keep this in transient UI state.
  final String? inviteToken;
}

class HouseholdInviteRedemptionResult {
  const HouseholdInviteRedemptionResult({
    required this.requestId,
    required this.householdId,
    required this.role,
    required this.alreadyApplied,
  });

  final String requestId;
  final String householdId;
  final HouseholdInviteRole role;
  final bool alreadyApplied;
}

abstract interface class HouseholdInviteDataSource {
  Future<HouseholdInviteIssueResult> issue({
    required String householdId,
    required HouseholdInviteRole role,
    required String commandId,
  });

  Future<HouseholdInviteRedemptionResult> redeem({
    required String inviteToken,
    required String commandId,
  });
}

/// Narrow client boundary for the trusted invite callable contract.
///
/// It only exchanges command payloads and response DTOs. It never reads or
/// writes invite Firestore records and deliberately has no persistence API for
/// a bearer invite token.
class HouseholdInviteRemoteDataSource implements HouseholdInviteDataSource {
  HouseholdInviteRemoteDataSource(FirebaseFunctions functions)
    : _invoke = _firebaseInvoker(functions);

  HouseholdInviteRemoteDataSource.forTesting(
    HouseholdInviteCallableInvoker invoke,
  )
    : _invoke = invoke;

  final HouseholdInviteCallableInvoker _invoke;

  static HouseholdInviteCallableInvoker _firebaseInvoker(
    FirebaseFunctions functions,
  ) =>
      (name, data) async =>
          (await functions.httpsCallable(name).call<Object?>(data)).data;

  @override
  Future<HouseholdInviteIssueResult> issue({
    required String householdId,
    required HouseholdInviteRole role,
    required String commandId,
  }) async {
    final response = await _invoke('issueHouseholdInvite', {
      'householdId': householdId,
      'role': role.name,
      'commandId': commandId,
    });
    return _parseIssue(response, expectedHouseholdId: householdId);
  }

  @override
  Future<HouseholdInviteRedemptionResult> redeem({
    required String inviteToken,
    required String commandId,
  }) async {
    final response = await _invoke('redeemHouseholdInvite', {
      'inviteToken': inviteToken,
      'commandId': commandId,
    });
    return _parseRedemption(response);
  }
}

HouseholdInviteIssueResult _parseIssue(
  Object? response, {
  required String expectedHouseholdId,
}) {
  final data = _strictMap(
    response,
    allowedKeys: const {
      'requestId',
      'householdId',
      'role',
      'inviteId',
      'alreadyIssued',
      'inviteToken',
    },
  );
  final requestId = _requiredString(data, 'requestId');
  final householdId = _requiredString(data, 'householdId');
  final role = _role(data['role']);
  final inviteId = _requiredString(data, 'inviteId');
  final alreadyIssued = data['alreadyIssued'];
  if (householdId != expectedHouseholdId ||
      alreadyIssued is! bool ||
      !_opaqueInviteId.hasMatch(inviteId)) {
    throw _invalidResponse();
  }

  final inviteToken = data['inviteToken'];
  if (alreadyIssued) {
    if (inviteToken != null) throw _invalidResponse();
    return HouseholdInviteIssueResult(
      requestId: requestId,
      householdId: householdId,
      role: role,
      inviteId: inviteId,
      alreadyIssued: true,
      inviteToken: null,
    );
  }
  if (inviteToken is! String || !_opaqueInviteToken.hasMatch(inviteToken)) {
    throw _invalidResponse();
  }
  return HouseholdInviteIssueResult(
    requestId: requestId,
    householdId: householdId,
    role: role,
    inviteId: inviteId,
    alreadyIssued: false,
    inviteToken: inviteToken,
  );
}

HouseholdInviteRedemptionResult _parseRedemption(Object? response) {
  final data = _strictMap(
    response,
    allowedKeys: const {'requestId', 'householdId', 'role', 'alreadyApplied'},
  );
  final requestId = _requiredString(data, 'requestId');
  final householdId = _requiredString(data, 'householdId');
  final role = _role(data['role']);
  final alreadyApplied = data['alreadyApplied'];
  if (alreadyApplied is! bool) throw _invalidResponse();
  return HouseholdInviteRedemptionResult(
    requestId: requestId,
    householdId: householdId,
    role: role,
    alreadyApplied: alreadyApplied,
  );
}

Map<String, Object?> _strictMap(
  Object? response, {
  required Set<String> allowedKeys,
}) {
  if (response is! Map<Object?, Object?> ||
      response.keys.any(
        (key) => key is! String || !allowedKeys.contains(key),
      )) {
    throw _invalidResponse();
  }
  return Map<String, Object?>.from(response);
}

String _requiredString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidResponse();
  return value;
}

HouseholdInviteRole _role(Object? value) => switch (value) {
  'member' => HouseholdInviteRole.member,
  'shopper' => HouseholdInviteRole.shopper,
  'cook' => HouseholdInviteRole.cook,
  _ => throw _invalidResponse(),
};

StateError _invalidResponse() =>
    StateError('Invite service returned an invalid response.');

final _opaqueInviteId = RegExp(r'^[A-Za-z0-9_-]{22}$');
final _opaqueInviteToken = RegExp(r'^[A-Za-z0-9_-]{43}$');
