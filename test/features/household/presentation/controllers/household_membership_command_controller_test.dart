import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/household/presentation/controllers/household_membership_command_controller.dart';

void main() {
  test('retry reuses the same removal command id', () async {
    final calls = <(String, Map<String, Object?>)>[];
    var attempts = 0;
    final controller = HouseholdMembershipCommandController(
      idGenerator: FakeIdGenerator(['remove-command-1']),
      invoke: (name, data) async {
        calls.add((name, data));
        attempts += 1;
        if (attempts == 1) throw StateError('temporarily unavailable');
      },
    );

    await expectLater(
      controller.removeMember(
        householdId: 'household-1',
        targetUserId: 'member-1',
      ),
      throwsStateError,
    );
    expect(
      await controller.removeMember(
        householdId: 'household-1',
        targetUserId: 'member-1',
      ),
      isTrue,
    );

    expect(calls, hasLength(2));
    expect(calls.map((call) => call.$1), everyElement('removeHouseholdMember'));
    expect(calls.map((call) => call.$2['commandId']), [
      'remove-command-1',
      'remove-command-1',
    ]);
  });

  test('duplicate in-flight transfer is suppressed', () async {
    final gate = Completer<void>();
    final calls = <Map<String, Object?>>[];
    final controller = HouseholdMembershipCommandController(
      idGenerator: FakeIdGenerator(['transfer-command-1']),
      invoke: (_, data) async {
        calls.add(data);
        await gate.future;
      },
    );

    final first = controller.transferAdmin(
      householdId: 'household-1',
      targetUserId: 'member-1',
    );
    expect(
      await controller.transferAdmin(
        householdId: 'household-1',
        targetUserId: 'member-1',
      ),
      isFalse,
    );
    gate.complete();
    expect(await first, isTrue);

    expect(calls, hasLength(1));
    expect(calls.single['commandId'], 'transfer-command-1');
  });

  test('removal and transfer use independent command ids', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final controller = HouseholdMembershipCommandController(
      idGenerator: FakeIdGenerator(['remove-command-1', 'transfer-command-1']),
      invoke: (name, data) async => calls.add((name, data)),
    );

    await controller.removeMember(
      householdId: 'household-1',
      targetUserId: 'member-1',
    );
    await controller.transferAdmin(
      householdId: 'household-1',
      targetUserId: 'member-1',
    );

    expect(calls[0].$2['commandId'], 'remove-command-1');
    expect(calls[1].$2['commandId'], 'transfer-command-1');
  });
}
