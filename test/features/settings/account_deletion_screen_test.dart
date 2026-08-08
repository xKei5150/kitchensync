import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/settings/presentation/account_deletion_screen.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(theme: theme ?? AppTheme.dark(), home: child);
}

void main() {
  testWidgets('renders eligible deletion with one direct destructive action', (
    tester,
  ) async {
    var accepted = 0;
    var cancelled = 0;
    var signedOut = 0;
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.eligible(
            eligibility: AccountDeletionEligibilityViewModel(
              soloHouseholdName: 'My kitchen',
            ),
          ),
          onAcceptDeletion: () => accepted++,
          onCancel: () => cancelled++,
          onSignOut: () => signedOut++,
        ),
      ),
    );

    expect(find.text('Delete account'), findsNWidgets(2));
    expect(
      find.textContaining(
        'My kitchen structured records are retained '
        'anonymously.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('no longer be connected to your account'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);
    expect(find.text('Transfer ownership'), findsNothing);
    expect(find.text('Leave household'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.tap(find.text('Cancel'));
    await tester.tap(find.text('Sign out'));

    expect(accepted, 1);
    expect(cancelled, 1);
    expect(signedOut, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders loading preflight with disabled recovery actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.loading(),
          onCancel: () {},
          onSignOut: () {},
        ),
      ),
    );

    expect(find.text('Checking deletion eligibility'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Sign out'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an empty preflight with retry and no delete action', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.empty(
            message: 'Household details have not loaded.',
          ),
          onRetryPreflight: () => retried++,
        ),
      ),
    );

    expect(find.text('Deletion details unavailable'), findsOneWidget);
    expect(find.text('Household details have not loaded.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete account'), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders owner blocker with transfer only', (tester) async {
    var transferred = 0;
    var left = 0;
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.blocked(
            household: AccountDeletionHouseholdViewModel(
              name: 'Shared kitchen',
              isOwner: true,
              canTransferOwnership: true,
              canLeaveHousehold: true,
            ),
          ),
          onTransferOwnership: () => transferred++,
          onLeaveHousehold: () => left++,
        ),
      ),
    );

    expect(find.text('Change household ownership first'), findsOneWidget);
    expect(find.textContaining('You own Shared kitchen'), findsOneWidget);
    expect(
      find.textContaining('Transfer ownership before deleting your account.'),
      findsOneWidget,
    );
    expect(find.text('Transfer ownership'), findsOneWidget);
    // A stale/over-permissive input flag must not expose an owner-leave path.
    expect(find.text('Leave household'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Delete account'), findsNothing);

    await tester.tap(find.text('Transfer ownership'));
    expect(transferred, 1);
    expect(left, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders member blocker without an unavailable transfer action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.blocked(
            household: AccountDeletionHouseholdViewModel(
              name: 'Shared kitchen',
              isOwner: false,
              canTransferOwnership: false,
              canLeaveHousehold: true,
            ),
          ),
          onLeaveHousehold: () {},
        ),
      ),
    );

    expect(find.text('Leave this joint household first'), findsOneWidget);
    expect(find.text('Transfer ownership'), findsNothing);
    expect(find.text('Leave household'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders recent-auth error as a live error with retry', (
    tester,
  ) async {
    var retries = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.error(
            kind: AccountDeletionErrorKind.recentAuthentication,
            message: 'Your recent sign-in has expired.',
          ),
          onRetryError: () => retries++,
        ),
      ),
    );

    expect(find.text('Recent sign-in required'), findsOneWidget);
    expect(find.text('Your recent sign-in has expired.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('renders action error and keeps account deletion uncommitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.error(
            kind: AccountDeletionErrorKind.action,
            message: 'The deletion request could not be saved.',
          ),
          onRetryError: () {},
        ),
      ),
    );

    expect(find.text('Deletion request was not accepted'), findsOneWidget);
    expect(
      find.textContaining('Your account has not been deleted.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Delete account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders durable accepted and pending states', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AccountDeletionScreen(
          viewModel: AccountDeletionViewModel.pending(
            request: AccountDeletionPendingViewModel(
              status: AccountDeletionRequestStatus.accepted,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Deletion request accepted'), findsOneWidget);
    expect(find.textContaining('Your request is saved.'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        const AccountDeletionScreen(
          viewModel: AccountDeletionViewModel.pending(
            request: AccountDeletionPendingViewModel(
              status: AccountDeletionRequestStatus.pending,
              detail: 'The request is waiting for processing.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Deletion request pending'), findsOneWidget);
    expect(find.text('The request is waiting for processing.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _wrap(
        const AccountDeletionScreen(
          viewModel: AccountDeletionViewModel.pending(
            request: AccountDeletionPendingViewModel(
              status: AccountDeletionRequestStatus.blocked,
              detail:
                  'The request was accepted but is currently blocked. Sign out '
                  'to continue.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Deletion request saved, but blocked'), findsOneWidget);
    expect(
      find.textContaining('The request was accepted but is currently blocked.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the flow accessible at narrow width and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: AccountDeletionScreen(
            viewModel: AccountDeletionViewModel.eligible(),
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('shows action loading and disables the destructive controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AccountDeletionScreen(
          viewModel: const AccountDeletionViewModel.eligible(
            actions: AccountDeletionActionState(isAcceptingDeletion: true),
          ),
          onAcceptDeletion: () {},
          onCancel: () {},
          onSignOut: () {},
        ),
      ),
    );

    expect(find.text('Submitting request...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submitting request...'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
