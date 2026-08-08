import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/household/data/datasources/household_invite_remote_data_source.dart';

void main() {
  const token = 'YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE';

  test('issue sends only the callable contract and returns a fresh token',
      () async {
    final calls = <(String, Map<String, Object?>)>[];
    final dataSource = HouseholdInviteRemoteDataSource.forTesting(
      (name, data) async {
        calls.add((name, data));
        return {
          'requestId': 'request-1',
          'householdId': 'household-1',
          'role': 'member',
          'inviteId': 'MTIzNDU2Nzg5MDEyMzQ1Ng',
          'alreadyIssued': false,
          'inviteToken': token,
        };
      },
    );

    final result = await dataSource.issue(
      householdId: 'household-1',
      role: HouseholdInviteRole.member,
      commandId: 'issue-command-1',
    );

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'issueHouseholdInvite');
    expect(calls.single.$2, <String, Object?>{
      'householdId': 'household-1',
      'role': 'member',
      'commandId': 'issue-command-1',
    });
    expect(result.requestId, 'request-1');
    expect(result.inviteId, 'MTIzNDU2Nzg5MDEyMzQ1Ng');
    expect(result.inviteToken, token);
    expect(result.alreadyIssued, isFalse);
    expect(calls.single.$2.toString(), isNot(contains(token)));
  });

  test('issue accepts a token-free exact replay but rejects malformed '
      'token data',
      () async {
    final replayDataSource = HouseholdInviteRemoteDataSource.forTesting(
      (_, _) async => {
        'requestId': 'request-1',
        'householdId': 'household-1',
        'role': 'member',
        'inviteId': 'MTIzNDU2Nzg5MDEyMzQ1Ng',
        'alreadyIssued': true,
      },
    );

    final replay = await replayDataSource.issue(
      householdId: 'household-1',
      role: HouseholdInviteRole.member,
      commandId: 'issue-command-1',
    );
    expect(replay.alreadyIssued, isTrue);
    expect(replay.inviteToken, isNull);

    final malformedDataSource = HouseholdInviteRemoteDataSource.forTesting(
      (_, _) async => {
        'requestId': 'request-1',
        'householdId': 'household-1',
        'role': 'member',
        'inviteId': 'MTIzNDU2Nzg5MDEyMzQ1Ng',
        'alreadyIssued': false,
        'inviteToken': 'KS-HOUSEH',
      },
    );
    await expectLater(
      malformedDataSource.issue(
        householdId: 'household-1',
        role: HouseholdInviteRole.member,
        commandId: 'issue-command-1',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('redeem sends only the raw token and command ID then parses context',
      () async {
    final calls = <(String, Map<String, Object?>)>[];
    final dataSource = HouseholdInviteRemoteDataSource.forTesting(
      (name, data) async {
        calls.add((name, data));
        return {
          'requestId': 'request-2',
          'householdId': 'household-1',
          'role': 'shopper',
          'alreadyApplied': false,
        };
      },
    );

    final result = await dataSource.redeem(
      inviteToken: token,
      commandId: 'redeem-command-1',
    );

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'redeemHouseholdInvite');
    expect(calls.single.$2, <String, Object?>{
      'inviteToken': token,
      'commandId': 'redeem-command-1',
    });
    expect(result.requestId, 'request-2');
    expect(result.householdId, 'household-1');
    expect(result.role, HouseholdInviteRole.shopper);
    expect(result.alreadyApplied, isFalse);
  });
}
