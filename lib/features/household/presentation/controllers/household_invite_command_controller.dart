import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/household/data/datasources/household_invite_remote_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

final householdInviteCommandControllerProvider =
    Provider<HouseholdInviteCommandController>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      return HouseholdInviteCommandController(
        dataSource: auth == null
            ? null
            : HouseholdInviteRemoteDataSource(
                FirebaseFunctions.instanceFor(region: 'us-central1'),
              ),
        idGenerator: ref.watch(idGeneratorProvider),
      );
    });

/// Client command coordinator for the trusted invite callables.
///
/// It retains only opaque idempotency command IDs for a retry. Bearer invite
/// tokens are passed straight through to the callable and are never cached.
class HouseholdInviteCommandController {
  HouseholdInviteCommandController({
    required this.dataSource,
    required this.idGenerator,
  });

  final HouseholdInviteDataSource? dataSource;
  final IdGenerator idGenerator;
  final Map<String, String> _issuanceCommandIds = {};
  final Set<String> _issuingHouseholds = {};

  Future<HouseholdInviteIssueResult> issueMemberInvite({
    required String householdId,
  }) async {
    final source = _requireDataSource();
    if (!_issuingHouseholds.add(householdId)) {
      throw StateError('An invite request is already in progress.');
    }
    final commandId = _issuanceCommandIds[householdId] ??= idGenerator.newId();
    try {
      final result = await source.issue(
        householdId: householdId,
        role: HouseholdInviteRole.member,
        commandId: commandId,
      );
      // A completed response (including a token-free exact replay) cannot be
      // safely retried as the same issuance command.
      _issuanceCommandIds.remove(householdId);
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw StateError(_messageFor(error));
    } finally {
      _issuingHouseholds.remove(householdId);
    }
  }

  Future<HouseholdInviteRedemptionResult> redeem({
    required String inviteToken,
    required String commandId,
  }) async {
    try {
      return await _requireDataSource().redeem(
        inviteToken: inviteToken,
        commandId: commandId,
      );
    } on FirebaseFunctionsException catch (error) {
      throw StateError(_messageFor(error));
    }
  }

  HouseholdInviteDataSource _requireDataSource() {
    final source = dataSource;
    if (source == null) {
      throw StateError('Secure household invites are unavailable right now.');
    }
    return source;
  }

  String _messageFor(FirebaseFunctionsException error) => switch (error.code) {
    'failed-precondition' || 'permission-denied' || 'not-found' =>
      'This invite cannot be used. Ask the household Admin for a new invite.',
    'resource-exhausted' => 'Too many invite attempts. Try again later.',
    'unavailable' ||
    'aborted' => 'Household invites are temporarily unavailable. Try again.',
    _ => 'Could not complete the invite request. Try again.',
  };
}
