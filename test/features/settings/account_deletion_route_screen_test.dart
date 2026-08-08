import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/account_deletion_requested_screen.dart';
import 'package:kitchensync/features/settings/presentation/controllers/account_deletion_controller.dart';
import 'package:kitchensync/features/settings/presentation/screens/account_deletion_route_screen.dart';

class _FakeDeletionController extends AccountDeletionController {
  _FakeDeletionController({
    required this.result,
    required this.response,
    this.requestFailure,
  }) : super(
         auth: null,
         googleSignIn: null,
         providerAvailability: const AuthenticationProviderAvailability(
           google: false,
           apple: false,
         ),
         activeHousehold: null,
         dataSource: null,
       );

  final AccountDeletionPreflightResult result;
  final AccountDeletionResponse response;
  final Exception? requestFailure;
  int requestCalls = 0;

  @override
  Future<AccountDeletionPreflightResult> preflight() async => result;

  @override
  Future<AccountDeletionResponse> requestAccountDeletion() async {
    requestCalls++;
    final failure = requestFailure;
    if (failure != null) throw failure;
    return response;
  }
}

class _FakeAuthenticationController extends AuthenticationController {
  _FakeAuthenticationController() : super(auth: null, googleSignIn: null);

  int signOutCalls = 0;
  Completer<void>? signedOut;
  VoidCallback? onSignedOut;
  Exception? signOutFailure;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final failure = signOutFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> waitForSignedOut() async {
    final transition = signedOut;
    if (transition != null) await transition.future;
    onSignedOut?.call();
  }
}

Future<
  ({
    GoRouter router,
    _FakeDeletionController deletion,
    void Function({required bool value}) setConfirmationNavigationFailure,
  })
>
_pumpFlow(
  WidgetTester tester, {
  required _FakeAuthenticationController authentication,
  AccountDeletionResponse response = const AccountDeletionResponse(
    commandId: 'request-command',
    requestId: 'request-command',
    status: AccountLifecycleRequestStatus.queued,
    alreadyQueued: false,
  ),
  String? preflightAlreadyQueuedRequestId,
  Exception? requestFailure,
  bool failConfirmationNavigation = false,
}) async {
  final deletion = _FakeDeletionController(
    result: AccountDeletionPreflightResult(
      commandId: 'preflight-command',
      canRequestDeletion: true,
      blockers: [],
      households: [],
      alreadyQueuedRequestId: preflightAlreadyQueuedRequestId,
    ),
    response: response,
    requestFailure: requestFailure,
  );
  var session = const AppSessionState(phase: AppSessionPhase.ready);
  var shouldFailConfirmationNavigation = failConfirmationNavigation;
  void setConfirmationNavigationFailure({required bool value}) {
    shouldFailConfirmationNavigation = value;
  }

  late GoRouter router;
  authentication.onSignedOut = () {
    if (!shouldFailConfirmationNavigation) {
      session = const AppSessionState.signedOut();
    }
    router.refresh();
  };
  router = GoRouter(
    initialLocation: '/settings/account-deletion',
    redirect: (context, state) {
      if (shouldFailConfirmationNavigation &&
          state.uri.path == '/auth/deletion-requested') {
        return '/settings/account-deletion';
      }
      return appSessionRedirect(
        session: session,
        authenticationOperationInProgress: false,
        path: state.uri.path,
      );
    },
    routes: [
      GoRoute(
        path: '/settings/account-deletion',
        builder: (_, _) => const AccountDeletionRouteScreen(),
      ),
      GoRoute(
        path: '/auth/reauthentication',
        builder: (context, state) => Scaffold(
          body: FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Complete reauthentication'),
          ),
        ),
      ),
      GoRoute(
        path: '/auth/deletion-requested',
        builder: (context, state) => AccountDeletionRequestedScreen(
          onContinue: () => context.go('/onboarding'),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const Scaffold(body: Text('Onboarding')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        accountDeletionControllerProvider.overrideWithValue(deletion),
        authenticationControllerProvider.overrideWithValue(authentication),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (
    router: router,
    deletion: deletion,
    setConfirmationNavigationFailure: setConfirmationNavigationFailure,
  );
}

void main() {
  testWidgets('accepted deletion signs out and routes to confirmation', (
    tester,
  ) async {
    final authentication = _FakeAuthenticationController()
      ..signedOut = Completer<void>();
    final flow = await _pumpFlow(tester, authentication: authentication);
    final deletion = flow.deletion;
    final router = flow.router;

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Complete reauthentication'), findsOneWidget);

    await tester.tap(find.text('Complete reauthentication'));
    await tester.pump();

    expect(authentication.signOutCalls, 1);
    expect(authentication.signedOut, isNotNull);
    expect(find.text('Deletion request accepted'), findsNothing);

    authentication.signedOut!.complete();
    await tester.pumpAndSettle();

    expect(deletion.requestCalls, 1);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/auth/deletion-requested',
    );
    expect(find.text('Deletion request accepted'), findsOneWidget);
  });

  testWidgets(
    'accepted deletion keeps durable recovery after sign-out failure',
    (tester) async {
      final authentication = _FakeAuthenticationController()
        ..signOutFailure = Exception('Firebase sign-out failed');
      final flow = await _pumpFlow(tester, authentication: authentication);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete reauthentication'));
      await tester.pumpAndSettle();

      expect(flow.deletion.requestCalls, 1);
      expect(find.text('Deletion request accepted'), findsOneWidget);
      expect(
        find.textContaining('remains saved. Account deletion will continue.'),
        findsOneWidget,
      );
      expect(find.text('Deletion request was not accepted'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Retry sign out'), findsOneWidget);

      authentication.signOutFailure = null;
      await tester.tap(find.text('Retry sign out'));
      await tester.pumpAndSettle();

      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/auth/deletion-requested',
      );
      expect(find.text('Deletion request accepted'), findsOneWidget);
    },
  );

  testWidgets(
    'accepted deletion keeps durable recovery after confirmation navigation '
    'failure',
    (tester) async {
      final authentication = _FakeAuthenticationController();
      final flow = await _pumpFlow(
        tester,
        authentication: authentication,
        failConfirmationNavigation: true,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete reauthentication'));
      await tester.pumpAndSettle();

      expect(flow.deletion.requestCalls, 1);
      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/settings/account-deletion',
      );
      expect(find.text('Deletion request accepted'), findsOneWidget);
      expect(find.textContaining('confirmation screen yet'), findsOneWidget);
      expect(find.text('Deletion request was not accepted'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Retry sign out'), findsOneWidget);

      flow.setConfirmationNavigationFailure(value: false);
      await tester.tap(find.text('Retry sign out'));
      await tester.pumpAndSettle();

      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/auth/deletion-requested',
      );
      expect(find.text('Deletion request accepted'), findsOneWidget);
    },
  );

  testWidgets(
    'blocked durable recovery keeps saved truth after sign-out failure',
    (tester) async {
      final authentication = _FakeAuthenticationController()
        ..signOutFailure = Exception('Firebase sign-out failed');
      final flow = await _pumpFlow(
        tester,
        authentication: authentication,
        response: const AccountDeletionResponse(
          commandId: 'request-command',
          requestId: 'request-command',
          status: AccountLifecycleRequestStatus.blocked,
          alreadyQueued: true,
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete reauthentication'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(authentication.signOutCalls, 1);
      expect(find.text('Deletion request saved, but blocked'), findsOneWidget);
      expect(
        find.textContaining('remains saved. Account deletion will continue.'),
        findsOneWidget,
      );
      expect(find.text('Signing out...'), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Retry sign out'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Deletion request was not accepted'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/settings/account-deletion',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending recovery catches sign-out and retry navigation failures',
    (tester) async {
      final authentication = _FakeAuthenticationController()
        ..signOutFailure = Exception('Firebase sign-out failed');
      final flow = await _pumpFlow(
        tester,
        authentication: authentication,
        preflightAlreadyQueuedRequestId: 'existing-request',
      );

      expect(find.text('Deletion request pending'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(authentication.signOutCalls, 1);
      expect(find.text('Deletion request pending'), findsOneWidget);
      expect(
        find.textContaining('remains saved. Account deletion will continue.'),
        findsOneWidget,
      );
      expect(find.text('Signing out...'), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Retry sign out'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Deletion request was not accepted'), findsNothing);
      expect(find.text('Cancel'), findsNothing);

      authentication.signOutFailure = null;
      flow.setConfirmationNavigationFailure(value: true);
      await tester.tap(find.text('Retry sign out'));
      await tester.pumpAndSettle();

      expect(authentication.signOutCalls, 2);
      expect(find.text('Deletion request pending'), findsOneWidget);
      expect(find.text('Signing out...'), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Retry sign out'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/settings/account-deletion',
      );
      expect(tester.takeException(), isNull);

      flow.setConfirmationNavigationFailure(value: false);
      await tester.tap(find.text('Retry sign out'));
      await tester.pumpAndSettle();

      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/auth/deletion-requested',
      );
      expect(find.text('Deletion request accepted'), findsOneWidget);
    },
  );

  testWidgets('queued durable replay signs out and routes to confirmation', (
    tester,
  ) async {
    final authentication = _FakeAuthenticationController();
    final flow = await _pumpFlow(
      tester,
      authentication: authentication,
      response: const AccountDeletionResponse(
        commandId: 'request-command',
        requestId: 'request-command',
        status: AccountLifecycleRequestStatus.queued,
        alreadyQueued: true,
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete reauthentication'));
    await tester.pumpAndSettle();

    expect(authentication.signOutCalls, 1);
    expect(find.text('Deletion request was not accepted'), findsNothing);
    expect(
      flow.router.routerDelegate.currentConfiguration.uri.path,
      '/auth/deletion-requested',
    );
    expect(find.text('Deletion request accepted'), findsOneWidget);
  });

  testWidgets('processing replay signs out and routes to confirmation', (
    tester,
  ) async {
    final authentication = _FakeAuthenticationController();
    final flow = await _pumpFlow(
      tester,
      authentication: authentication,
      response: const AccountDeletionResponse(
        commandId: 'request-command',
        requestId: 'request-command',
        status: AccountLifecycleRequestStatus.processing,
        alreadyQueued: true,
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete reauthentication'));
    await tester.pumpAndSettle();

    expect(authentication.signOutCalls, 1);
    expect(
      flow.router.routerDelegate.currentConfiguration.uri.path,
      '/auth/deletion-requested',
    );
    expect(find.text('Deletion request accepted'), findsOneWidget);
  });

  testWidgets('retryable durable replay signs out and routes to confirmation', (
    tester,
  ) async {
    final authentication = _FakeAuthenticationController();
    final flow = await _pumpFlow(
      tester,
      authentication: authentication,
      response: const AccountDeletionResponse(
        commandId: 'request-command',
        requestId: 'request-command',
        status: AccountLifecycleRequestStatus.retryable,
        alreadyQueued: true,
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete reauthentication'));
    await tester.pumpAndSettle();

    expect(authentication.signOutCalls, 1);
    expect(find.text('Deletion request was not accepted'), findsNothing);
    expect(
      flow.router.routerDelegate.currentConfiguration.uri.path,
      '/auth/deletion-requested',
    );
    expect(find.text('Deletion request accepted'), findsOneWidget);
  });

  testWidgets(
    'blocked durable replay is explicit and can continue to confirmation',
    (tester) async {
      final authentication = _FakeAuthenticationController();
      final flow = await _pumpFlow(
        tester,
        authentication: authentication,
        response: const AccountDeletionResponse(
          commandId: 'request-command',
          requestId: 'request-command',
          status: AccountLifecycleRequestStatus.blocked,
          alreadyQueued: true,
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete reauthentication'));
      await tester.pumpAndSettle();

      expect(authentication.signOutCalls, 0);
      expect(find.text('Deletion request saved, but blocked'), findsOneWidget);
      expect(
        find.textContaining(
          'Your deletion request was accepted, but processing is '
          'currently blocked.',
        ),
        findsOneWidget,
      );
      expect(find.text('Deletion request was not accepted'), findsNothing);
      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/settings/account-deletion',
      );

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(authentication.signOutCalls, 1);
      expect(
        flow.router.routerDelegate.currentConfiguration.uri.path,
        '/auth/deletion-requested',
      );
      expect(find.text('Deletion request accepted'), findsOneWidget);
    },
  );

  testWidgets('genuine callable rejection remains unaccepted and signed in', (
    tester,
  ) async {
    final authentication = _FakeAuthenticationController();
    final flow = await _pumpFlow(
      tester,
      authentication: authentication,
      requestFailure: const AccountLifecycleCallableException(
        code: 'failed-precondition',
        message: 'The request could not be accepted.',
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete reauthentication'));
    await tester.pumpAndSettle();

    expect(authentication.signOutCalls, 0);
    expect(find.text('Deletion request was not accepted'), findsOneWidget);
    expect(find.text('The request could not be accepted.'), findsOneWidget);
    expect(find.text('Deletion request accepted'), findsNothing);
    expect(
      flow.router.routerDelegate.currentConfiguration.uri.path,
      '/settings/account-deletion',
    );
  });
}
