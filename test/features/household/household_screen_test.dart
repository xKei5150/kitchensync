import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/presentation/controllers/household_membership_command_controller.dart';
import 'package:kitchensync/features/household/presentation/screens/household_screen.dart';

const _adminHousehold = ActiveHouseholdContext(
  id: 'joint-household',
  name: 'Joint kitchen',
  role: HouseholdRole.admin,
  isJoint: true,
  hasPremium: true,
);

const _members = [
  HouseholdMemberSummary(
    userId: 'admin-1',
    name: 'Ana',
    handle: 'you',
    role: HouseholdRole.admin,
    seat: 0,
    isCurrentUser: true,
  ),
  HouseholdMemberSummary(
    userId: 'cook-1',
    name: 'Ben',
    handle: 'ben@home',
    role: HouseholdRole.cook,
    seat: 1,
  ),
];

Widget _wrap({
  required ThemeData theme,
  ActiveHouseholdContext household = _adminHousehold,
  Stream<HouseholdDetails>? details,
  HouseholdMembershipCommandController? commands,
}) {
  return ProviderScope(
    overrides: [
      activeHouseholdContextProvider.overrideWithValue(household),
      householdDetailsProvider.overrideWith(
        (ref) =>
            details ??
            Stream.value(
              const HouseholdDetails(
                id: 'joint-household',
                name: 'Joint kitchen',
                isJoint: true,
                maxMembers: 6,
                inviteCode: 'SAGE-417',
                members: _members,
              ),
            ),
      ),
      if (commands != null)
        householdMembershipCommandControllerProvider.overrideWithValue(
          commands,
        ),
    ],
    child: MaterialApp(theme: theme, home: const HouseholdScreen()),
  );
}

void main() {
  testWidgets('HouseholdScreen lists members and the invite code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(theme: AppTheme.light()));
    await tester.pumpAndSettle();

    expect(find.text("Who's in the kitchen"), findsOneWidget);
    expect(find.byType(KsMemberRow), findsNWidgets(2));
    expect(find.byType(KsInviteCode), findsOneWidget);
    expect(find.text('SAGE-417'), findsOneWidget);
  });

  testWidgets('tapping a non-admin member opens the role sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(theme: AppTheme.light()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();

    expect(find.text("Ben's role"), findsOneWidget);
    expect(find.text('Save role'), findsOneWidget);
    expect(find.text('Transfer Admin'), findsOneWidget);
    expect(find.text('Remove member'), findsOneWidget);

    // Selecting a different role updates the radio without throwing.
    await tester.tap(find.text('Shopper'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin confirms member removal through the trusted command', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <(String, Map<String, Object?>)>[];
    final commands = HouseholdMembershipCommandController(
      idGenerator: FakeIdGenerator(['remove-command-1']),
      invoke: (name, data) async => calls.add((name, data)),
    );

    await tester.pumpWidget(_wrap(theme: AppTheme.light(), commands: commands));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();

    expect(find.text('Remove member?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'removeHouseholdMember');
    expect(calls.single.$2, {
      'householdId': 'joint-household',
      'targetUserId': 'cook-1',
      'commandId': 'remove-command-1',
    });
    expect(find.text("Ben's role"), findsNothing);
  });

  testWidgets('Admin confirms transfer and sees the Premium warning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <(String, Map<String, Object?>)>[];
    final commands = HouseholdMembershipCommandController(
      idGenerator: FakeIdGenerator(['transfer-command-1']),
      invoke: (name, data) async => calls.add((name, data)),
    );

    await tester.pumpWidget(_wrap(theme: AppTheme.light(), commands: commands));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer Admin?'), findsOneWidget);
    expect(find.textContaining('must have Premium'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'transferHouseholdAdmin');
    expect(calls.single.$2['targetUserId'], 'cook-1');
    expect(find.text("Ben's role"), findsNothing);
  });

  testWidgets('failed removal remains retryable with the same command id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <Map<String, Object?>>[];
    var attempts = 0;
    final commands = HouseholdMembershipCommandController(
      idGenerator: FakeIdGenerator(['remove-command-1']),
      invoke: (_, data) async {
        calls.add(data);
        attempts += 1;
        if (attempts == 1) throw StateError('temporarily unavailable');
      },
    );

    await tester.pumpWidget(_wrap(theme: AppTheme.light(), commands: commands));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not remove member'), findsOneWidget);
    expect(find.text("Ben's role"), findsOneWidget);
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(2));
    expect(calls.map((call) => call['commandId']), [
      'remove-command-1',
      'remove-command-1',
    ]);
    expect(find.text("Ben's role"), findsNothing);
  });

  testWidgets('non-admin sees live members without management controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        theme: AppTheme.light(),
        household: const ActiveHouseholdContext(
          id: 'joint-household',
          name: 'Joint kitchen',
          role: HouseholdRole.member,
          isJoint: true,
          hasPremium: true,
        ),
        details: Stream.value(
          const HouseholdDetails(
            id: 'joint-household',
            name: 'Joint kitchen',
            isJoint: true,
            maxMembers: 6,
            inviteCode: 'SAGE-417',
            members: [
              HouseholdMemberSummary(
                userId: 'member-1',
                name: 'Ana',
                handle: 'you',
                role: HouseholdRole.member,
                seat: 0,
                isCurrentUser: true,
              ),
              HouseholdMemberSummary(
                userId: 'cook-1',
                name: 'Ben',
                handle: 'ben@home',
                role: HouseholdRole.cook,
                seat: 1,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KsMemberRow), findsNWidgets(2));
    expect(find.byType(KsInviteCode), findsNothing);
    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    expect(find.text("Ben's role"), findsNothing);
  });

  testWidgets('load errors stay honest instead of showing preview members', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        theme: AppTheme.light(),
        details: Stream.error(StateError('membership unavailable')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KsMemberRow), findsNothing);
    expect(find.byType(KsInviteCode), findsNothing);
    expect(find.textContaining('membership unavailable'), findsOneWidget);
  });

  testWidgets('HouseholdScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(theme: AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
