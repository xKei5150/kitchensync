import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/settings/presentation/account_deletion_screen.dart'
    as deletion_view;

const accountLifecyclePolicyVersion = 'account-lifecycle-v1';

typedef AccountLifecycleCallableInvoker =
    Future<Object?> Function(String name, Map<String, Object?> data);

class AccountLifecycleProtocolException implements Exception {
  const AccountLifecycleProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountLifecycleCallableException implements Exception {
  const AccountLifecycleCallableException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  bool get requiresRecentAuthentication => code == 'unauthenticated';

  @override
  String toString() => message;
}

enum AccountDeletionTransitionFailureKind { signOut, navigation }

/// Raised only after the server has accepted a deletion request.
///
/// This keeps a client-side sign-out or navigation problem from being shown as
/// a callable rejection. The request is already durable when this exception is
/// used.
class AccountDeletionTransitionException implements Exception {
  const AccountDeletionTransitionException({
    required this.kind,
    required this.message,
  });

  final AccountDeletionTransitionFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class AccountDeletionBlocker {
  const AccountDeletionBlocker({
    required this.code,
    required this.message,
    required this.resolution,
    this.householdId,
  });

  final String code;
  final String? householdId;
  final String message;
  final String resolution;
}

class AccountDeletionHouseholdSummary {
  const AccountDeletionHouseholdSummary({
    required this.householdId,
    required this.isJoint,
    required this.ownerUserId,
    required this.callerRole,
    required this.premiumOwnership,
  });

  final String householdId;
  final bool isJoint;
  final String? ownerUserId;
  final String? callerRole;
  final String premiumOwnership;
}

class AccountDeletionPreflightResult {
  const AccountDeletionPreflightResult({
    required this.commandId,
    required this.canRequestDeletion,
    required this.blockers,
    required this.households,
    this.alreadyQueuedRequestId,
  });

  final String commandId;
  final bool canRequestDeletion;
  final List<AccountDeletionBlocker> blockers;
  final List<AccountDeletionHouseholdSummary> households;
  final String? alreadyQueuedRequestId;
}

enum AccountLifecycleRequestStatus {
  queued,
  processing,
  blocked,
  retryable,
  completed,
  cancelled,
}

class AccountDeletionResponse {
  const AccountDeletionResponse({
    required this.commandId,
    required this.requestId,
    required this.status,
    required this.alreadyQueued,
  });

  final String commandId;
  final String requestId;
  final AccountLifecycleRequestStatus status;
  final bool alreadyQueued;
}

class LeaveJointHouseholdResponse {
  const LeaveJointHouseholdResponse({
    required this.commandId,
    required this.householdId,
    required this.alreadyApplied,
    required this.activeHouseholdId,
  });

  final String commandId;
  final String householdId;
  final bool alreadyApplied;
  final String? activeHouseholdId;
}

class TransferJointHouseholdOwnershipResponse {
  const TransferJointHouseholdOwnershipResponse({
    required this.commandId,
    required this.householdId,
    required this.targetUserId,
    required this.alreadyApplied,
  });

  final String commandId;
  final String householdId;
  final String targetUserId;
  final bool alreadyApplied;
}

/// Narrow client boundary for the versioned account-lifecycle callables.
class AccountLifecycleRemoteDataSource {
  AccountLifecycleRemoteDataSource(FirebaseFunctions functions)
    : _invoke = _firebaseInvoker(functions);

  @visibleForTesting
  AccountLifecycleRemoteDataSource.forTesting(
    AccountLifecycleCallableInvoker invoke,
  ) : _invoke = invoke;

  final AccountLifecycleCallableInvoker _invoke;

  Future<AccountDeletionPreflightResult> preflight({
    required String commandId,
  }) async {
    final response = await _invoke('accountDeletionPreflight', {
      'commandId': commandId,
      'policyVersion': accountLifecyclePolicyVersion,
    });
    return _parsePreflight(response, expectedCommandId: commandId);
  }

  Future<AccountDeletionResponse> requestAccountDeletion({
    required String commandId,
  }) async {
    final response = await _invoke('requestAccountDeletion', {
      'commandId': commandId,
      'policyVersion': accountLifecyclePolicyVersion,
    });
    return _parseDeletionResponse(response, expectedCommandId: commandId);
  }

  Future<LeaveJointHouseholdResponse> leaveJointHousehold({
    required String commandId,
    required String householdId,
  }) async {
    final response = await _invoke('leaveJointHousehold', {
      'commandId': commandId,
      'policyVersion': accountLifecyclePolicyVersion,
      'householdId': householdId,
    });
    return _parseLeaveResponse(
      response,
      expectedCommandId: commandId,
      expectedHouseholdId: householdId,
    );
  }

  Future<TransferJointHouseholdOwnershipResponse> transferOwnership({
    required String commandId,
    required String householdId,
    required String targetUserId,
  }) async {
    final response = await _invoke('transferJointHouseholdOwnership', {
      'commandId': commandId,
      'policyVersion': accountLifecyclePolicyVersion,
      'householdId': householdId,
      'targetUserId': targetUserId,
    });
    return _parseTransferResponse(
      response,
      expectedCommandId: commandId,
      expectedHouseholdId: householdId,
      expectedTargetUserId: targetUserId,
    );
  }

  static AccountLifecycleCallableInvoker _firebaseInvoker(
    FirebaseFunctions functions,
  ) =>
      (name, data) async =>
          (await functions.httpsCallable(name).call<Object?>(data)).data;
}

final accountDeletionControllerProvider = Provider<AccountDeletionController>((
  ref,
) {
  final auth = ref.watch(firebaseAuthProvider);
  final functions = auth == null
      ? null
      : FirebaseFunctions.instanceFor(region: 'us-central1');
  return AccountDeletionController(
    auth: auth,
    googleSignIn: ref.watch(googleSignInProvider),
    providerAvailability: ref.watch(authenticationProviderAvailabilityProvider),
    activeHousehold: ref.watch(activeHouseholdContextProvider),
    dataSource: functions == null
        ? null
        : AccountLifecycleRemoteDataSource(functions),
    idGenerator: ref.watch(idGeneratorProvider),
  );
});

class AccountDeletionController {
  AccountDeletionController({
    required this.auth,
    required this.googleSignIn,
    required this.providerAvailability,
    required this.activeHousehold,
    required this.dataSource,
    this.idGenerator = const UuidV4IdGenerator(),
  });

  final FirebaseAuth? auth;
  final GoogleSignIn? googleSignIn;
  final AuthenticationProviderAvailability providerAvailability;
  final ActiveHouseholdContext? activeHousehold;
  final AccountLifecycleRemoteDataSource? dataSource;
  final IdGenerator idGenerator;

  final Map<String, String> _commandIds = {};
  final Set<String> _inFlight = {};

  Future<AccountDeletionPreflightResult> preflight() async {
    final source = _requireDataSource();
    final commandId = idGenerator.newId();
    try {
      return await source.preflight(commandId: commandId);
    } catch (error) {
      throw mapAccountLifecycleError(error);
    }
  }

  Future<AccountDeletionResponse> requestAccountDeletion() async {
    final source = _requireDataSource();
    final commandId = _commandIds['request'] ??= idGenerator.newId();
    return _runCommand('request', () async {
      try {
        return await source.requestAccountDeletion(commandId: commandId);
      } catch (error) {
        throw mapAccountLifecycleError(error);
      }
    });
  }

  Future<LeaveJointHouseholdResponse> leaveJointHousehold({
    required String householdId,
  }) async {
    final source = _requireDataSource();
    final key = 'leave:$householdId';
    final commandId = _commandIds[key] ??= idGenerator.newId();
    return _runCommand(key, () async {
      try {
        return await source.leaveJointHousehold(
          commandId: commandId,
          householdId: householdId,
        );
      } catch (error) {
        throw mapAccountLifecycleError(error);
      }
    });
  }

  Future<TransferJointHouseholdOwnershipResponse> transferOwnership({
    required String householdId,
    required String targetUserId,
  }) async {
    final source = _requireDataSource();
    if (targetUserId.isEmpty || targetUserId == auth?.currentUser?.uid) {
      throw const AccountLifecycleProtocolException(
        'Choose another household member before transferring ownership.',
      );
    }
    final key = 'transfer:$householdId:$targetUserId';
    final commandId = _commandIds[key] ??= idGenerator.newId();
    return _runCommand(key, () async {
      try {
        return await source.transferOwnership(
          commandId: commandId,
          householdId: householdId,
          targetUserId: targetUserId,
        );
      } catch (error) {
        throw mapAccountLifecycleError(error);
      }
    });
  }

  List<AuthenticationProviderKind> get availableReauthenticationProviders {
    final user = auth?.currentUser;
    final linkedProviderIds =
        user?.providerData.map((provider) => provider.providerId).toSet() ??
        const <String>{};
    final providers = <AuthenticationProviderKind>[];
    if (providerAvailability.google &&
        linkedProviderIds.contains('google.com')) {
      providers.add(AuthenticationProviderKind.google);
    }
    if (providerAvailability.apple && linkedProviderIds.contains('apple.com')) {
      providers.add(AuthenticationProviderKind.apple);
    }
    return providers;
  }

  bool get supportsEmailPasswordReauthentication =>
      auth?.currentUser?.providerData.any(
        (provider) => provider.providerId == 'password',
      ) ??
      false;

  deletion_view.AccountDeletionViewModel viewModelForPreflight(
    AccountDeletionPreflightResult result, {
    deletion_view.AccountDeletionActionState actions =
        const deletion_view.AccountDeletionActionState(),
  }) {
    if (result.alreadyQueuedRequestId != null) {
      return deletion_view.AccountDeletionViewModel.pending(
        request: const deletion_view.AccountDeletionPendingViewModel(
          status: deletion_view.AccountDeletionRequestStatus.pending,
          detail: 'An account deletion request is already being processed.',
        ),
        actions: actions,
      );
    }

    final jointBlocker = result.blockers
        .cast<AccountDeletionBlocker?>()
        .firstWhere(
          (blocker) =>
              blocker?.code == 'jointHouseholdOwnershipTransferRequired' ||
              blocker?.code == 'jointHouseholdMembershipLeaveRequired',
          orElse: () => null,
        );
    if (jointBlocker != null) {
      final summary = _summaryFor(result, jointBlocker.householdId);
      final isOwner =
          jointBlocker.code == 'jointHouseholdOwnershipTransferRequired' ||
          summary?.ownerUserId == auth?.currentUser?.uid;
      final hasKnownJointHousehold =
          jointBlocker.householdId != null && (summary?.isJoint ?? false);
      if (!hasKnownJointHousehold) {
        return deletion_view.AccountDeletionViewModel.error(
          kind: deletion_view.AccountDeletionErrorKind.preflight,
          message: '${jointBlocker.message}. ${jointBlocker.resolution}',
          actions: actions,
        );
      }
      return deletion_view.AccountDeletionViewModel.blocked(
        household: deletion_view.AccountDeletionHouseholdViewModel(
          name: _householdName(summary),
          isOwner: isOwner,
          canTransferOwnership: isOwner,
          canLeaveHousehold:
              !isOwner &&
              result.blockers.any(
                (blocker) =>
                    blocker.code == 'jointHouseholdMembershipLeaveRequired' &&
                    blocker.householdId == jointBlocker.householdId,
              ),
        ),
        actions: actions,
      );
    }

    if (result.canRequestDeletion) {
      return deletion_view.AccountDeletionViewModel.eligible(
        eligibility: deletion_view.AccountDeletionEligibilityViewModel(
          soloHouseholdName: _soloHouseholdName(result),
        ),
        actions: actions,
      );
    }

    final blocker = result.blockers.firstOrNull;
    if (blocker != null) {
      return deletion_view.AccountDeletionViewModel.error(
        kind: deletion_view.AccountDeletionErrorKind.preflight,
        message: '${blocker.message}. ${blocker.resolution}',
        actions: actions,
      );
    }
    return deletion_view.AccountDeletionViewModel.empty(
      message: 'No safe deletion details are available yet.',
      actions: actions,
    );
  }

  String? transferHouseholdId(AccountDeletionPreflightResult result) {
    final blocker = result.blockers.firstWhereOrNull(
      (value) => value.code == 'jointHouseholdOwnershipTransferRequired',
    );
    final summary = _summaryFor(result, blocker?.householdId);
    return blocker?.householdId != null && (summary?.isJoint ?? false)
        ? blocker!.householdId
        : null;
  }

  String? leaveHouseholdId(AccountDeletionPreflightResult result) {
    final blocker = result.blockers.firstWhereOrNull(
      (value) => value.code == 'jointHouseholdMembershipLeaveRequired',
    );
    final summary = _summaryFor(result, blocker?.householdId);
    return blocker?.householdId != null && (summary?.isJoint ?? false)
        ? blocker!.householdId
        : null;
  }

  AccountLifecycleRemoteDataSource _requireDataSource() {
    final source = dataSource;
    if (source == null) {
      throw const AccountLifecycleProtocolException(
        'Account lifecycle actions are unavailable until Firebase is '
        'configured.',
      );
    }
    return source;
  }

  Future<T> _runCommand<T>(String key, Future<T> Function() action) async {
    if (!_inFlight.add(key)) {
      throw const AccountLifecycleProtocolException(
        'That account action is already in progress.',
      );
    }
    try {
      return await action();
    } finally {
      _inFlight.remove(key);
    }
  }

  AccountDeletionHouseholdSummary? _summaryFor(
    AccountDeletionPreflightResult result,
    String? householdId,
  ) {
    if (householdId == null) return null;
    return result.households.firstWhereOrNull(
      (summary) => summary.householdId == householdId,
    );
  }

  String _householdName(AccountDeletionHouseholdSummary? summary) {
    if (summary != null && activeHousehold?.id == summary.householdId) {
      return activeHousehold!.name;
    }
    return 'this joint household';
  }

  String? _soloHouseholdName(AccountDeletionPreflightResult result) {
    final solo = result.households.firstWhereOrNull(
      (summary) => !summary.isJoint,
    );
    if (solo != null && activeHousehold?.id == solo.householdId) {
      return activeHousehold!.name;
    }
    return null;
  }
}

AccountLifecycleCallableException mapAccountLifecycleError(Object error) {
  if (error is AccountLifecycleCallableException) return error;
  if (error is AccountLifecycleProtocolException) {
    return AccountLifecycleCallableException(
      code: 'protocol',
      message: error.message,
    );
  }
  if (error is FirebaseFunctionsException) {
    final message = switch (error.code) {
      'unauthenticated' => 'Your session expired. Sign in again.',
      'permission-denied' =>
        'You are not allowed to perform this account action.',
      'failed-precondition' =>
        error.message ?? 'The account state changed. Review it and try again.',
      'invalid-argument' => 'The account action could not be verified.',
      'unavailable' ||
      'aborted' => 'Account services are temporarily unavailable. Try again.',
      _ => error.message ?? 'Could not complete the account action. Try again.',
    };
    return AccountLifecycleCallableException(
      code: error.code,
      message: message,
    );
  }
  return const AccountLifecycleCallableException(
    code: 'unknown',
    message: 'Could not complete the account action. Try again.',
  );
}

Map<String, Object?> _strictMap(
  Object? value, {
  required Set<String> allowedKeys,
}) {
  if (value is! Map) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String || !allowedKeys.contains(entry.key)) {
      throw const AccountLifecycleProtocolException(
        'Invalid callable response.',
      );
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _requiredString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return value;
}

String? _nullableString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return value;
}

bool _requiredBool(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! bool) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return value;
}

void _checkCommandAndPolicy(
  Map<String, Object?> data, {
  required String expectedCommandId,
}) {
  if (_requiredString(data, 'commandId') != expectedCommandId ||
      _requiredString(data, 'policyVersion') != accountLifecyclePolicyVersion) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
}

AccountDeletionPreflightResult _parsePreflight(
  Object? response, {
  required String expectedCommandId,
}) {
  final data = _strictMap(
    response,
    allowedKeys: const {
      'commandId',
      'policyVersion',
      'canRequestDeletion',
      'blockers',
      'households',
      'alreadyQueuedRequestId',
    },
  );
  _checkCommandAndPolicy(data, expectedCommandId: expectedCommandId);
  final blockers = data['blockers'];
  final households = data['households'];
  if (blockers is! List || households is! List) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return AccountDeletionPreflightResult(
    commandId: expectedCommandId,
    canRequestDeletion: _requiredBool(data, 'canRequestDeletion'),
    blockers: blockers.map(_parseBlocker).toList(growable: false),
    households: households.map(_parseHousehold).toList(growable: false),
    alreadyQueuedRequestId: _nullableString(data, 'alreadyQueuedRequestId'),
  );
}

AccountDeletionBlocker _parseBlocker(Object? value) {
  final data = _strictMap(
    value,
    allowedKeys: const {'code', 'householdId', 'message', 'resolution'},
  );
  final code = _requiredString(data, 'code');
  const codes = {
    'accountDeletionAlreadyQueued',
    'jointHouseholdMembershipLeaveRequired',
    'jointHouseholdOwnershipTransferRequired',
    'schemaMigrationRequired',
  };
  if (!codes.contains(code)) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return AccountDeletionBlocker(
    code: code,
    householdId: _nullableString(data, 'householdId'),
    message: _requiredString(data, 'message'),
    resolution: _requiredString(data, 'resolution'),
  );
}

AccountDeletionHouseholdSummary _parseHousehold(Object? value) {
  final data = _strictMap(
    value,
    allowedKeys: const {
      'householdId',
      'isJoint',
      'ownerUserId',
      'callerRole',
      'premiumOwnership',
    },
  );
  final premiumOwnership = _requiredString(data, 'premiumOwnership');
  if (!{'none', 'in_app_trial', 'paid', 'unknown'}.contains(premiumOwnership)) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return AccountDeletionHouseholdSummary(
    householdId: _requiredString(data, 'householdId'),
    isJoint: _requiredBool(data, 'isJoint'),
    ownerUserId: _nullableString(data, 'ownerUserId'),
    callerRole: _nullableString(data, 'callerRole'),
    premiumOwnership: premiumOwnership,
  );
}

AccountLifecycleRequestStatus _parseRequestStatus(Object? value) {
  if (value is! String) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return switch (value) {
    'queued' => AccountLifecycleRequestStatus.queued,
    'processing' => AccountLifecycleRequestStatus.processing,
    'blocked' => AccountLifecycleRequestStatus.blocked,
    'retryable' => AccountLifecycleRequestStatus.retryable,
    'completed' => AccountLifecycleRequestStatus.completed,
    'cancelled' => AccountLifecycleRequestStatus.cancelled,
    _ => throw const AccountLifecycleProtocolException(
      'Invalid callable response.',
    ),
  };
}

AccountDeletionResponse _parseDeletionResponse(
  Object? response, {
  required String expectedCommandId,
}) {
  final data = _strictMap(
    response,
    allowedKeys: const {
      'commandId',
      'requestId',
      'policyVersion',
      'status',
      'alreadyQueued',
    },
  );
  _checkCommandAndPolicy(data, expectedCommandId: expectedCommandId);
  final requestId = _requiredString(data, 'requestId');
  if (requestId != expectedCommandId) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return AccountDeletionResponse(
    commandId: expectedCommandId,
    requestId: requestId,
    status: _parseRequestStatus(data['status']),
    alreadyQueued: _requiredBool(data, 'alreadyQueued'),
  );
}

LeaveJointHouseholdResponse _parseLeaveResponse(
  Object? response, {
  required String expectedCommandId,
  required String expectedHouseholdId,
}) {
  final data = _strictMap(
    response,
    allowedKeys: const {
      'commandId',
      'householdId',
      'policyVersion',
      'alreadyApplied',
      'activeHouseholdId',
    },
  );
  _checkCommandAndPolicy(data, expectedCommandId: expectedCommandId);
  if (_requiredString(data, 'householdId') != expectedHouseholdId) {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return LeaveJointHouseholdResponse(
    commandId: expectedCommandId,
    householdId: expectedHouseholdId,
    alreadyApplied: _requiredBool(data, 'alreadyApplied'),
    activeHouseholdId: _nullableString(data, 'activeHouseholdId'),
  );
}

TransferJointHouseholdOwnershipResponse _parseTransferResponse(
  Object? response, {
  required String expectedCommandId,
  required String expectedHouseholdId,
  required String expectedTargetUserId,
}) {
  final data = _strictMap(
    response,
    allowedKeys: const {
      'commandId',
      'householdId',
      'targetUserId',
      'policyVersion',
      'alreadyApplied',
      'premiumOwnership',
    },
  );
  _checkCommandAndPolicy(data, expectedCommandId: expectedCommandId);
  if (_requiredString(data, 'householdId') != expectedHouseholdId ||
      _requiredString(data, 'targetUserId') != expectedTargetUserId ||
      _requiredString(data, 'premiumOwnership') != 'in_app_trial') {
    throw const AccountLifecycleProtocolException('Invalid callable response.');
  }
  return TransferJointHouseholdOwnershipResponse(
    commandId: expectedCommandId,
    householdId: expectedHouseholdId,
    targetUserId: expectedTargetUserId,
    alreadyApplied: _requiredBool(data, 'alreadyApplied'),
  );
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
