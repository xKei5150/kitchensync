import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/settings/presentation/account_deletion_screen.dart';
import 'package:kitchensync/features/settings/presentation/controllers/account_deletion_controller.dart';
import 'package:mocktail/mocktail.dart';

const _preflightCommand = '123e4567-e89b-42d3-a456-426614174000';
const _requestCommand = '123e4567-e89b-42d3-a456-426614174001';
const _leaveCommand = '123e4567-e89b-42d3-a456-426614174002';
const _transferCommand = '123e4567-e89b-42d3-a456-426614174003';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

const _household = ActiveHouseholdContext(
  id: 'joint-household',
  name: 'Shared kitchen',
  role: HouseholdRole.admin,
  isJoint: true,
  hasPremium: true,
);

AccountDeletionController _controller({
  AccountLifecycleRemoteDataSource? source,
  FirebaseAuth? auth,
}) => AccountDeletionController(
  auth: auth,
  googleSignIn: null,
  providerAvailability: const AuthenticationProviderAvailability(
    google: false,
    apple: false,
  ),
  activeHousehold: _household,
  dataSource: source,
  idGenerator: FakeIdGenerator([
    _preflightCommand,
    _requestCommand,
    _leaveCommand,
    _transferCommand,
  ]),
);

Map<String, Object?> _preflightResponse({
  required bool canRequestDeletion,
  List<Map<String, Object?>> blockers = const [],
  List<Map<String, Object?>> households = const [],
  String? alreadyQueuedRequestId,
}) => {
  'commandId': _preflightCommand,
  'policyVersion': accountLifecyclePolicyVersion,
  'canRequestDeletion': canRequestDeletion,
  'blockers': blockers,
  'households': households,
  if (alreadyQueuedRequestId != null)
    'alreadyQueuedRequestId': alreadyQueuedRequestId,
};

Map<String, Object?> _householdResponse({
  required String householdId,
  required bool isJoint,
  required String? ownerUserId,
}) => {
  'householdId': householdId,
  'isJoint': isJoint,
  'ownerUserId': ownerUserId,
  'callerRole': ownerUserId == null ? 'member' : 'admin',
  'premiumOwnership': isJoint ? 'in_app_trial' : 'none',
};

void main() {
  test(
    'callable DTOs preserve opaque command IDs and policy acknowledgement',
    () async {
      final calls = <String, Map<String, Object?>>{};
      final source = AccountLifecycleRemoteDataSource.forTesting((
        name,
        data,
      ) async {
        calls[name] = data;
        return switch (name) {
          'accountDeletionPreflight' => _preflightResponse(
            canRequestDeletion: true,
            households: [
              _householdResponse(
                householdId: 'solo-household',
                isJoint: false,
                ownerUserId: 'user-1',
              ),
            ],
          ),
          'requestAccountDeletion' => {
            'commandId': _requestCommand,
            'requestId': _requestCommand,
            'policyVersion': accountLifecyclePolicyVersion,
            'status': 'queued',
            'alreadyQueued': false,
          },
          'leaveJointHousehold' => {
            'commandId': _leaveCommand,
            'householdId': 'joint-household',
            'policyVersion': accountLifecyclePolicyVersion,
            'alreadyApplied': false,
            'activeHouseholdId': null,
          },
          'transferJointHouseholdOwnership' => {
            'commandId': _transferCommand,
            'householdId': 'joint-household',
            'targetUserId': 'target-user',
            'policyVersion': accountLifecyclePolicyVersion,
            'alreadyApplied': false,
            'premiumOwnership': 'in_app_trial',
          },
          _ => throw StateError('Unexpected callable $name'),
        };
      });
      final controller = _controller(source: source);

      await controller.preflight();
      await controller.requestAccountDeletion();
      await controller.leaveJointHousehold(householdId: 'joint-household');
      await controller.transferOwnership(
        householdId: 'joint-household',
        targetUserId: 'target-user',
      );

      expect(calls['accountDeletionPreflight'], {
        'commandId': _preflightCommand,
        'policyVersion': accountLifecyclePolicyVersion,
      });
      expect(calls['requestAccountDeletion'], {
        'commandId': _requestCommand,
        'policyVersion': accountLifecyclePolicyVersion,
      });
      expect(calls['leaveJointHousehold'], {
        'commandId': _leaveCommand,
        'policyVersion': accountLifecyclePolicyVersion,
        'householdId': 'joint-household',
      });
      expect(calls['transferJointHouseholdOwnership'], {
        'commandId': _transferCommand,
        'policyVersion': accountLifecyclePolicyVersion,
        'householdId': 'joint-household',
        'targetUserId': 'target-user',
      });
    },
  );

  test(
    'maps eligible, pending, blocked, and schema-error preflight states',
    () {
      final controller = _controller();
      final eligible = controller.viewModelForPreflight(
        const AccountDeletionPreflightResult(
          commandId: _preflightCommand,
          canRequestDeletion: true,
          blockers: [],
          households: [
            AccountDeletionHouseholdSummary(
              householdId: 'solo-household',
              isJoint: false,
              ownerUserId: 'user-1',
              callerRole: 'admin',
              premiumOwnership: 'none',
            ),
          ],
        ),
      );
      expect(eligible, isA<AccountDeletionEligibleViewModel>());

      final pending = controller.viewModelForPreflight(
        const AccountDeletionPreflightResult(
          commandId: _preflightCommand,
          canRequestDeletion: false,
          blockers: [],
          households: [],
          alreadyQueuedRequestId: _requestCommand,
        ),
      );
      expect(pending, isA<AccountDeletionPendingStateViewModel>());

      final blocked = controller.viewModelForPreflight(
        const AccountDeletionPreflightResult(
          commandId: _preflightCommand,
          canRequestDeletion: false,
          blockers: [
            AccountDeletionBlocker(
              code: 'jointHouseholdOwnershipTransferRequired',
              householdId: 'joint-household',
              message: 'Transfer ownership before requesting account deletion',
              resolution: 'Choose another household member',
            ),
          ],
          households: [
            AccountDeletionHouseholdSummary(
              householdId: 'joint-household',
              isJoint: true,
              ownerUserId: null,
              callerRole: 'admin',
              premiumOwnership: 'in_app_trial',
            ),
          ],
        ),
      );
      expect(blocked, isA<AccountDeletionJointHouseholdViewModel>());
      final blockedState = blocked as AccountDeletionJointHouseholdViewModel;
      expect(blockedState.household.canTransferOwnership, isTrue);
      expect(blockedState.household.canLeaveHousehold, isFalse);

      final schemaError = controller.viewModelForPreflight(
        const AccountDeletionPreflightResult(
          commandId: _preflightCommand,
          canRequestDeletion: false,
          blockers: [
            AccountDeletionBlocker(
              code: 'schemaMigrationRequired',
              message: 'Profile is not ready',
              resolution: 'Complete the account migration',
            ),
          ],
          households: [],
        ),
      );
      expect(schemaError, isA<AccountDeletionErrorViewModel>());
    },
  );

  test('never guesses a transfer target or submits an empty target', () async {
    var invoked = false;
    final source = AccountLifecycleRemoteDataSource.forTesting((_, _) async {
      invoked = true;
      return <String, Object?>{};
    });
    final controller = _controller(source: source);

    expect(
      () => controller.transferOwnership(
        householdId: 'joint-household',
        targetUserId: '',
      ),
      throwsA(isA<AccountLifecycleProtocolException>()),
    );
    expect(invoked, isFalse);
  });

  test('offers only configured providers linked to the current user', () {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final google = _MockUserInfo();
    final password = _MockUserInfo();
    when(() => google.providerId).thenReturn('google.com');
    when(() => password.providerId).thenReturn('password');
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.providerData).thenReturn([google, password]);

    final controller = AccountDeletionController(
      auth: auth,
      googleSignIn: null,
      providerAvailability: const AuthenticationProviderAvailability(
        google: true,
        apple: true,
      ),
      activeHousehold: null,
      dataSource: null,
    );

    expect(controller.availableReauthenticationProviders, [
      AuthenticationProviderKind.google,
    ]);
    expect(controller.supportsEmailPasswordReauthentication, isTrue);
  });

  test('rejects unknown callable response fields fail closed', () async {
    final source = AccountLifecycleRemoteDataSource.forTesting((_, _) async {
      return {
        ..._preflightResponse(canRequestDeletion: true),
        'unexpected': true,
      };
    });
    await expectLater(
      source.preflight(commandId: _preflightCommand),
      throwsA(isA<AccountLifecycleProtocolException>()),
    );
  });
}
