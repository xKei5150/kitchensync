import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/settings/presentation/account_deletion_screen.dart';
import 'package:kitchensync/features/settings/presentation/controllers/account_deletion_controller.dart';

/// Firebase/callable-backed wrapper for the accepted deletion presentation.
class AccountDeletionRouteScreen extends ConsumerStatefulWidget {
  const AccountDeletionRouteScreen({super.key});

  @override
  ConsumerState<AccountDeletionRouteScreen> createState() =>
      _AccountDeletionRouteScreenState();
}

class _AccountDeletionRouteScreenState
    extends ConsumerState<AccountDeletionRouteScreen> {
  AccountDeletionViewModel _viewModel =
      const AccountDeletionViewModel.loading();
  AccountDeletionPreflightResult? _preflight;
  AccountDeletionRequestStatus? _durableRequestStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreflight());
  }

  Future<void> _loadPreflight() async {
    if (!mounted) return;
    setState(
      () => _viewModel = const AccountDeletionViewModel.loading(
        actions: AccountDeletionActionState(
          isPreflightLoading: true,
          isRetrying: true,
        ),
      ),
    );
    final controller = ref.read(accountDeletionControllerProvider);
    try {
      final result = await controller.preflight();
      if (!mounted) return;
      setState(() {
        _preflight = result;
        _durableRequestStatus = result.alreadyQueuedRequestId == null
            ? null
            : AccountDeletionRequestStatus.pending;
        _viewModel = controller.viewModelForPreflight(result);
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _viewModel = AccountDeletionViewModel.error(
          kind: AccountDeletionErrorKind.preflight,
          message: _safeMessage(error),
        ),
      );
    }
  }

  Future<void> _leaveHousehold() async {
    final result = _preflight;
    final controller = ref.read(accountDeletionControllerProvider);
    final householdId = result == null
        ? null
        : controller.leaveHouseholdId(result);
    if (householdId == null) {
      _showActionError(
        const AccountLifecycleProtocolException(
          'The household target is unavailable. Review your household and '
          'try again.',
        ),
      );
      return;
    }
    _setActions(const AccountDeletionActionState(isLeavingHousehold: true));
    try {
      await controller.leaveJointHousehold(householdId: householdId);
      await _loadPreflight();
    } catch (error) {
      _showActionError(error);
    }
  }

  Future<void> _transferOwnership() async {
    final result = _preflight;
    final controller = ref.read(accountDeletionControllerProvider);
    final householdId = result == null
        ? null
        : controller.transferHouseholdId(result);
    if (householdId == null) {
      _showActionError(
        const AccountLifecycleProtocolException(
          'Choose a household member from the existing household flow before '
          'transferring ownership.',
        ),
      );
      return;
    }
    _setActions(
      const AccountDeletionActionState(isTransferringOwnership: true),
    );
    final router = GoRouter.of(context);
    await router.push(
      '/household?accountLifecycleTransfer='
      '${Uri.encodeQueryComponent(householdId)}',
    );
    if (mounted) await _loadPreflight();
  }

  Future<void> _acceptDeletion() async {
    if (_preflight == null) return;
    _setActions(const AccountDeletionActionState(isAcceptingDeletion: true));
    final router = GoRouter.of(context);
    final reauthenticated = await router.push<bool>('/auth/reauthentication');
    if (!mounted) return;
    if (reauthenticated != true) {
      _setActions(const AccountDeletionActionState());
      return;
    }
    try {
      final response = await ref
          .read(accountDeletionControllerProvider)
          .requestAccountDeletion();
      if (!mounted) return;
      switch (response.status) {
        case AccountLifecycleRequestStatus.queued:
        case AccountLifecycleRequestStatus.processing:
          _durableRequestStatus = AccountDeletionRequestStatus.accepted;
          await _signOutAndShowConfirmation();
        case AccountLifecycleRequestStatus.retryable:
          if (response.alreadyQueued) {
            _durableRequestStatus = AccountDeletionRequestStatus.accepted;
            await _signOutAndShowConfirmation();
          } else {
            _showUnacceptedResponse();
          }
        case AccountLifecycleRequestStatus.blocked:
          if (response.alreadyQueued) {
            _durableRequestStatus = AccountDeletionRequestStatus.blocked;
            _showBlockedReplay();
          } else {
            _showUnacceptedResponse();
          }
        case AccountLifecycleRequestStatus.completed:
        case AccountLifecycleRequestStatus.cancelled:
          setState(
            () => _viewModel = const AccountDeletionViewModel.pending(
              request: AccountDeletionPendingViewModel(
                status: AccountDeletionRequestStatus.pending,
                detail:
                    'The existing deletion request is no longer accepting '
                    'changes.',
              ),
            ),
          );
      }
    } on AccountDeletionTransitionException catch (error) {
      _showPostAcceptanceError(error);
    } catch (error) {
      _showActionError(error);
    }
  }

  void _showBlockedReplay() {
    if (!mounted) return;
    setState(
      () => _viewModel = const AccountDeletionViewModel.pending(
        request: AccountDeletionPendingViewModel(
          status: AccountDeletionRequestStatus.blocked,
          detail:
              'Your deletion request was accepted, but processing is currently '
              'blocked. The request remains saved, and account deletion will '
              'continue when processing resumes. Sign out to open the '
              'confirmation screen.',
        ),
      ),
    );
  }

  void _showUnacceptedResponse() {
    _showActionError(
      const AccountLifecycleCallableException(
        code: 'failed-precondition',
        message:
            'The account deletion request is not ready yet. Review the current '
            'account state and try again.',
      ),
    );
  }

  Future<void> _signOutAndShowConfirmation() async {
    _setActions(const AccountDeletionActionState(isSigningOut: true));
    final container = ProviderScope.containerOf(context, listen: false);
    final operation = ref.read(
      authenticationOperationInProgressProvider.notifier,
    )..state = true;
    final deletionSignOut = ref.read(
      accountDeletionSignOutInProgressProvider.notifier,
    )..state = true;
    try {
      final authentication = ref.read(authenticationControllerProvider);
      try {
        await authentication.signOut();
        await authentication.waitForSignedOut();
      } catch (error) {
        throw const AccountDeletionTransitionException(
          kind: AccountDeletionTransitionFailureKind.signOut,
          message:
              'Your deletion request was accepted and remains saved. Account '
              'deletion will continue. We could not sign you out yet. Try '
              'again.',
        );
      }
      container
        ..invalidate(activeFirebaseUserProvider)
        ..invalidate(activeHouseholdContextStreamProvider)
        ..invalidate(activeHouseholdContextProvider);
      await _navigateToConfirmation(container);
    } on AccountDeletionTransitionException catch (error) {
      _showPostAcceptanceError(error);
    } finally {
      deletionSignOut.state = false;
      operation.state = false;
    }
  }

  Future<void> _navigateToConfirmation(ProviderContainer container) async {
    try {
      final activeRouter = container.read(routerProvider);
      final delegate = activeRouter.routerDelegate;
      activeRouter.go('/auth/deletion-requested');
      await Future<void>.delayed(Duration.zero);
      if (delegate.currentConfiguration.uri.path !=
          '/auth/deletion-requested') {
        throw StateError('The confirmation route was redirected.');
      }
    } catch (error) {
      if (error is AccountDeletionTransitionException) rethrow;
      throw const AccountDeletionTransitionException(
        kind: AccountDeletionTransitionFailureKind.navigation,
        message:
            'Your deletion request was accepted and remains saved. Account '
            'deletion will continue. We could not open the signed-out '
            'confirmation screen yet. Try again.',
      );
    }
  }

  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final operation = ref.read(
      authenticationOperationInProgressProvider.notifier,
    );
    _setActions(const AccountDeletionActionState(isSigningOut: true));
    operation.state = true;
    try {
      await ref.read(authenticationControllerProvider).signOut();
      container
        ..invalidate(activeFirebaseUserProvider)
        ..invalidate(activeHouseholdContextStreamProvider)
        ..invalidate(activeHouseholdContextProvider);
      router.go('/onboarding');
    } catch (error) {
      _showActionError(error);
    } finally {
      operation.state = false;
    }
  }

  void _setActions(AccountDeletionActionState actions) {
    if (!mounted) return;
    setState(() => _viewModel = _withActions(_viewModel, actions));
  }

  void _showActionError(Object error) {
    if (!mounted) return;
    final mapped = error is AccountLifecycleCallableException
        ? error
        : mapAccountLifecycleError(error);
    setState(
      () => _viewModel = AccountDeletionViewModel.error(
        kind: mapped.requiresRecentAuthentication
            ? AccountDeletionErrorKind.recentAuthentication
            : AccountDeletionErrorKind.action,
        message: mapped.message,
      ),
    );
  }

  void _showPostAcceptanceError(AccountDeletionTransitionException error) {
    if (!mounted) return;
    final current = _viewModel;
    final currentRequest = current is AccountDeletionPendingStateViewModel
        ? current.request
        : null;
    final status =
        currentRequest?.status ??
        _durableRequestStatus ??
        AccountDeletionRequestStatus.accepted;
    final detail = status == AccountDeletionRequestStatus.blocked
        ? 'Your deletion request was accepted, but processing is currently '
              'blocked. The request remains saved, and account deletion will '
              'continue when processing resumes. ${error.message}'
        : error.message;
    setState(
      () => _viewModel = AccountDeletionViewModel.pending(
        request: AccountDeletionPendingViewModel(
          status: status,
          detail: detail,
          isTransitionRecovery: true,
        ),
      ),
    );
  }

  VoidCallback _signOutAction() {
    final current = _viewModel;
    if (current is AccountDeletionPendingStateViewModel) {
      return _signOutAndShowConfirmation;
    }
    return _signOut;
  }

  String _safeMessage(Object error) {
    final mapped = error is AccountLifecycleCallableException
        ? error
        : mapAccountLifecycleError(error);
    return mapped.message;
  }

  @override
  Widget build(BuildContext context) {
    return AccountDeletionScreen(
      viewModel: _viewModel,
      onRetryPreflight: _loadPreflight,
      onTransferOwnership: _transferOwnership,
      onLeaveHousehold: _leaveHousehold,
      onAcceptDeletion: _acceptDeletion,
      onRetryError: _loadPreflight,
      onCancel: () => GoRouter.of(context).pop(),
      onSignOut: _signOutAction(),
    );
  }
}

AccountDeletionViewModel _withActions(
  AccountDeletionViewModel viewModel,
  AccountDeletionActionState actions,
) => switch (viewModel) {
  AccountDeletionLoadingViewModel() => AccountDeletionViewModel.loading(
    actions: actions,
  ),
  AccountDeletionEmptyViewModel(:final message) =>
    AccountDeletionViewModel.empty(message: message, actions: actions),
  AccountDeletionJointHouseholdViewModel(:final household) =>
    AccountDeletionViewModel.blocked(household: household, actions: actions),
  AccountDeletionEligibleViewModel(:final eligibility) =>
    AccountDeletionViewModel.eligible(
      eligibility: eligibility,
      actions: actions,
    ),
  AccountDeletionErrorViewModel(:final kind, :final message) =>
    AccountDeletionViewModel.error(
      kind: kind,
      message: message,
      actions: actions,
    ),
  AccountDeletionPendingStateViewModel(:final request) =>
    AccountDeletionViewModel.pending(request: request, actions: actions),
};
