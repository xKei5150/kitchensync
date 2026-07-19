import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

enum HouseholdMembershipCommand { removeMember, transferAdmin }

typedef HouseholdCallableInvoker =
    Future<void> Function(String name, Map<String, Object?> data);

final householdMembershipCommandControllerProvider =
    Provider<HouseholdMembershipCommandController>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      final functions = auth == null
          ? null
          : FirebaseFunctions.instanceFor(region: 'us-central1');
      return HouseholdMembershipCommandController(
        idGenerator: ref.watch(idGeneratorProvider),
        invoke: (name, data) async {
          if (functions == null) {
            throw StateError(
              'Household management is unavailable until Firebase is '
              'configured.',
            );
          }
          await functions.httpsCallable(name).call<Object?>(data);
        },
      );
    });

class HouseholdMembershipCommandController {
  HouseholdMembershipCommandController({
    required this.idGenerator,
    required this.invoke,
  });

  final IdGenerator idGenerator;
  final HouseholdCallableInvoker invoke;
  final Map<(HouseholdMembershipCommand, String, String), String> _commandIds =
      {};
  final Set<(HouseholdMembershipCommand, String, String)> _inFlight = {};

  Future<bool> removeMember({
    required String householdId,
    required String targetUserId,
  }) => _run(
    command: HouseholdMembershipCommand.removeMember,
    callableName: 'removeHouseholdMember',
    householdId: householdId,
    targetUserId: targetUserId,
  );

  Future<bool> transferAdmin({
    required String householdId,
    required String targetUserId,
  }) => _run(
    command: HouseholdMembershipCommand.transferAdmin,
    callableName: 'transferHouseholdAdmin',
    householdId: householdId,
    targetUserId: targetUserId,
  );

  String? commandIdFor({
    required HouseholdMembershipCommand command,
    required String householdId,
    required String targetUserId,
  }) => _commandIds[(command, householdId, targetUserId)];

  Future<bool> _run({
    required HouseholdMembershipCommand command,
    required String callableName,
    required String householdId,
    required String targetUserId,
  }) async {
    final key = (command, householdId, targetUserId);
    if (!_inFlight.add(key)) return false;
    final commandId = _commandIds[key] ??= idGenerator.newId();
    try {
      await invoke(callableName, {
        'householdId': householdId,
        'targetUserId': targetUserId,
        'commandId': commandId,
      });
      return true;
    } on FirebaseFunctionsException catch (error) {
      throw StateError(_messageFor(error));
    } finally {
      _inFlight.remove(key);
    }
  }

  String _messageFor(FirebaseFunctionsException error) => switch (error.code) {
    'permission-denied' =>
      'Only the current household Admin can perform this action.',
    'failed-precondition' => error.message ?? 'The household changed. Retry.',
    'not-found' => 'That person is no longer a household member.',
    'unavailable' ||
    'aborted' => 'Household management is temporarily unavailable. Retry.',
    _ => error.message ?? 'Could not update household membership.',
  };
}
