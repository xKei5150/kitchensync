import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// The failure category a deletion presentation can explain without knowing
/// how the auth or callable layer recovered it.
enum AccountDeletionErrorKind { preflight, recentAuthentication, action }

/// The durable request state returned after the deletion action is accepted.
enum AccountDeletionRequestStatus { accepted, pending, blocked }

/// Progress owned by the integration lane and rendered by the presentation.
class AccountDeletionActionState {
  const AccountDeletionActionState({
    this.isPreflightLoading = false,
    this.isTransferringOwnership = false,
    this.isLeavingHousehold = false,
    this.isAcceptingDeletion = false,
    this.isRetrying = false,
    this.isSigningOut = false,
  });

  final bool isPreflightLoading;
  final bool isTransferringOwnership;
  final bool isLeavingHousehold;
  final bool isAcceptingDeletion;
  final bool isRetrying;
  final bool isSigningOut;

  bool get isBusy =>
      isPreflightLoading ||
      isTransferringOwnership ||
      isLeavingHousehold ||
      isAcceptingDeletion ||
      isRetrying ||
      isSigningOut;
}

/// The household facts needed to explain why deletion is currently blocked.
///
/// These are presentation facts only. The integration lane remains the
/// authority for whether each command is actually allowed.
class AccountDeletionHouseholdViewModel {
  const AccountDeletionHouseholdViewModel({
    required this.name,
    required this.isOwner,
    required this.canTransferOwnership,
    required this.canLeaveHousehold,
  });

  final String name;
  final bool isOwner;
  final bool canTransferOwnership;
  final bool canLeaveHousehold;
}

/// Optional context for the eligible confirmation state.
class AccountDeletionEligibilityViewModel {
  const AccountDeletionEligibilityViewModel({this.soloHouseholdName});

  final String? soloHouseholdName;
}

/// Durable state displayed after the deletion request has been accepted.
class AccountDeletionPendingViewModel {
  const AccountDeletionPendingViewModel({
    required this.status,
    this.detail,
    this.isTransitionRecovery = false,
  });

  final AccountDeletionRequestStatus status;
  final String? detail;

  /// True when the request is durable but the sign-out/confirmation
  /// transition needs another attempt.
  final bool isTransitionRecovery;
}

/// Presentation states for the account-deletion flow.
sealed class AccountDeletionViewModel {
  const AccountDeletionViewModel({
    this.actions = const AccountDeletionActionState(),
  });

  const factory AccountDeletionViewModel.loading({
    AccountDeletionActionState? actions,
  }) = AccountDeletionLoadingViewModel;

  const factory AccountDeletionViewModel.empty({
    String? message,
    AccountDeletionActionState? actions,
  }) = AccountDeletionEmptyViewModel;

  const factory AccountDeletionViewModel.blocked({
    required AccountDeletionHouseholdViewModel household,
    AccountDeletionActionState? actions,
  }) = AccountDeletionJointHouseholdViewModel;

  const factory AccountDeletionViewModel.eligible({
    AccountDeletionEligibilityViewModel? eligibility,
    AccountDeletionActionState? actions,
  }) = AccountDeletionEligibleViewModel;

  const factory AccountDeletionViewModel.error({
    required AccountDeletionErrorKind kind,
    required String message,
    AccountDeletionActionState? actions,
  }) = AccountDeletionErrorViewModel;

  const factory AccountDeletionViewModel.pending({
    required AccountDeletionPendingViewModel request,
    AccountDeletionActionState? actions,
  }) = AccountDeletionPendingStateViewModel;

  final AccountDeletionActionState actions;
}

final class AccountDeletionLoadingViewModel extends AccountDeletionViewModel {
  const AccountDeletionLoadingViewModel({AccountDeletionActionState? actions})
    : super(
        actions:
            actions ??
            const AccountDeletionActionState(isPreflightLoading: true),
      );
}

final class AccountDeletionEmptyViewModel extends AccountDeletionViewModel {
  const AccountDeletionEmptyViewModel({
    String? message,
    AccountDeletionActionState? actions,
  }) : message = message ?? 'No deletion details are available yet',
       super(actions: actions ?? const AccountDeletionActionState());

  final String message;
}

final class AccountDeletionJointHouseholdViewModel
    extends AccountDeletionViewModel {
  const AccountDeletionJointHouseholdViewModel({
    required this.household,
    AccountDeletionActionState? actions,
  }) : super(actions: actions ?? const AccountDeletionActionState());

  final AccountDeletionHouseholdViewModel household;
}

final class AccountDeletionEligibleViewModel extends AccountDeletionViewModel {
  const AccountDeletionEligibleViewModel({
    AccountDeletionEligibilityViewModel? eligibility,
    AccountDeletionActionState? actions,
  }) : eligibility = eligibility ?? const AccountDeletionEligibilityViewModel(),
       super(actions: actions ?? const AccountDeletionActionState());

  final AccountDeletionEligibilityViewModel eligibility;
}

final class AccountDeletionErrorViewModel extends AccountDeletionViewModel {
  const AccountDeletionErrorViewModel({
    required this.kind,
    required this.message,
    AccountDeletionActionState? actions,
  }) : super(actions: actions ?? const AccountDeletionActionState());

  final AccountDeletionErrorKind kind;
  final String message;
}

final class AccountDeletionPendingStateViewModel
    extends AccountDeletionViewModel {
  const AccountDeletionPendingStateViewModel({
    required this.request,
    AccountDeletionActionState? actions,
  }) : super(actions: actions ?? const AccountDeletionActionState());

  final AccountDeletionPendingViewModel request;
}

/// Presentation-only account deletion flow.
///
/// The integration lane owns all side effects. Callbacks may be null while a
/// command is unavailable; the corresponding Material control then remains
/// visible but disabled.
class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({
    required this.viewModel,
    this.onRetryPreflight,
    this.onTransferOwnership,
    this.onLeaveHousehold,
    this.onAcceptDeletion,
    this.onRetryError,
    this.onCancel,
    this.onSignOut,
    super.key,
  });

  final AccountDeletionViewModel viewModel;
  final VoidCallback? onRetryPreflight;
  final VoidCallback? onTransferOwnership;
  final VoidCallback? onLeaveHousehold;
  final VoidCallback? onAcceptDeletion;
  final VoidCallback? onRetryError;
  final VoidCallback? onCancel;
  final VoidCallback? onSignOut;

  bool get _isBusy => viewModel.actions.isBusy;

  VoidCallback? _enabled(VoidCallback? callback) => _isBusy ? null : callback;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDurable = viewModel is AccountDeletionPendingStateViewModel;
    final pending = viewModel is AccountDeletionPendingStateViewModel
        ? (viewModel as AccountDeletionPendingStateViewModel).request
        : null;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            22,
            KsTokens.space20,
            22,
            KsTokens.space16,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AccountDeletionHeader(color: ks.danger),
                    const SizedBox(height: KsTokens.space20),
                    _buildState(context),
                    const SizedBox(height: KsTokens.space24),
                    const Divider(),
                    const SizedBox(height: KsTokens.space8),
                    _FooterActions(
                      cancelEnabled: isDurable ? null : _enabled(onCancel),
                      showCancel: !isDurable,
                      signOutEnabled: _enabled(onSignOut),
                      signingOut: viewModel.actions.isSigningOut,
                      signOutLabel: pending?.isTransitionRecovery ?? false
                          ? 'Retry sign out'
                          : 'Sign out',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildState(BuildContext context) => switch (viewModel) {
    AccountDeletionLoadingViewModel(:final actions) => _LoadingState(
      actions: actions,
    ),
    AccountDeletionEmptyViewModel(:final message, :final actions) =>
      _EmptyState(
        message: message,
        onRetry: _enabled(onRetryPreflight),
        retrying: actions.isRetrying,
      ),
    AccountDeletionJointHouseholdViewModel(:final household, :final actions) =>
      _BlockedState(
        household: household,
        actions: actions,
        onTransferOwnership: _enabled(onTransferOwnership),
        onLeaveHousehold: _enabled(onLeaveHousehold),
      ),
    AccountDeletionEligibleViewModel(:final eligibility, :final actions) =>
      _EligibleState(
        eligibility: eligibility,
        accepting: actions.isAcceptingDeletion,
        onAccept: _enabled(onAcceptDeletion),
      ),
    AccountDeletionErrorViewModel(
      :final kind,
      :final message,
      :final actions,
    ) =>
      _ErrorState(
        kind: kind,
        message: message,
        retrying: actions.isRetrying,
        onRetry: _enabled(onRetryError),
      ),
    AccountDeletionPendingStateViewModel(:final request) => _PendingState(
      request: request,
    ),
  };
}

class _AccountDeletionHeader extends StatelessWidget {
  const _AccountDeletionHeader({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(KsTokens.radius16),
            border: Border.all(color: color.withValues(alpha: 0.36)),
          ),
          child: Icon(Icons.delete_forever_outlined, size: 28, color: color),
        ),
        const SizedBox(height: KsTokens.space12),
        Semantics(
          header: true,
          child: Text(
            'Delete account',
            textAlign: TextAlign.center,
            style: KsTokens.displayMedium.copyWith(
              color: ks.textPrimary,
              fontSize: 28,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(height: KsTokens.space6),
        Text(
          'Review your household status before you continue.',
          textAlign: TextAlign.center,
          style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.actions});

  final AccountDeletionActionState actions;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: actions.isPreflightLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(Icons.fact_check_outlined, color: context.ksColors.info),
      title: 'Checking deletion eligibility',
      message: 'Reviewing your household access.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.onRetry,
    required this.retrying,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatePanel(
          icon: Icon(
            Icons.inbox_outlined,
            color: context.ksColors.textSecondary,
          ),
          title: 'Deletion details unavailable',
          message: message,
        ),
        const SizedBox(height: KsTokens.space12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: _ActionIcon(loading: retrying, icon: Icons.refresh_rounded),
          label: Text(retrying ? 'Trying again...' : 'Try again'),
        ),
      ],
    );
  }
}

class _BlockedState extends StatelessWidget {
  const _BlockedState({
    required this.household,
    required this.actions,
    required this.onTransferOwnership,
    required this.onLeaveHousehold,
  });

  final AccountDeletionHouseholdViewModel household;
  final AccountDeletionActionState actions;
  final VoidCallback? onTransferOwnership;
  final VoidCallback? onLeaveHousehold;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final canLeave = !household.isOwner && household.canLeaveHousehold;
    final title = household.isOwner
        ? 'Change household ownership first'
        : 'Leave this joint household first';
    final message = household.isOwner
        ? 'You own ${household.name}. Transfer ownership before deleting '
              'your account.'
        : 'You are still a member of ${household.name}. Leave this joint '
              'household before deleting your account.';
    final hasAction = household.canTransferOwnership || canLeave;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatePanel(
          icon: Icon(Icons.groups_outlined, color: ks.warning),
          title: title,
          message: message,
        ),
        const SizedBox(height: KsTokens.space12),
        if (household.canTransferOwnership)
          OutlinedButton.icon(
            onPressed: onTransferOwnership,
            icon: _ActionIcon(
              loading: actions.isTransferringOwnership,
              icon: Icons.swap_horiz_rounded,
            ),
            label: Text(
              actions.isTransferringOwnership
                  ? 'Transferring...'
                  : 'Transfer ownership',
            ),
          ),
        if (household.canTransferOwnership && canLeave)
          const SizedBox(height: KsTokens.space10),
        if (canLeave)
          OutlinedButton.icon(
            onPressed: onLeaveHousehold,
            icon: _ActionIcon(
              loading: actions.isLeavingHousehold,
              icon: Icons.logout_rounded,
            ),
            label: Text(
              actions.isLeavingHousehold ? 'Leaving...' : 'Leave household',
            ),
          ),
        if (!hasAction) ...[
          const SizedBox(height: KsTokens.space4),
          const _InlineNotice(
            icon: Icons.info_outline_rounded,
            message:
                'No household action is available right now. Try again '
                'or cancel.',
          ),
        ],
      ],
    );
  }
}

class _EligibleState extends StatelessWidget {
  const _EligibleState({
    required this.eligibility,
    required this.accepting,
    required this.onAccept,
  });

  final AccountDeletionEligibilityViewModel eligibility;
  final bool accepting;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(KsTokens.space12),
          decoration: BoxDecoration(
            color: ks.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.danger.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: ks.danger, size: 20),
              const SizedBox(width: KsTokens.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This permanently deletes your account',
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                      ),
                    ),
                    const SizedBox(height: KsTokens.space4),
                    Text(
                      'You will be signed out after the request is accepted.',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KsTokens.space12),
        _RetentionNotice(householdName: eligibility.soloHouseholdName),
        const SizedBox(height: KsTokens.space16),
        FilledButton.icon(
          onPressed: onAccept,
          style: KsButtonStyles.destructive(context),
          icon: _ActionIcon(loading: accepting, icon: Icons.delete_forever),
          label: Text(accepting ? 'Submitting request...' : 'Delete account'),
        ),
      ],
    );
  }
}

class _RetentionNotice extends StatelessWidget {
  const _RetentionNotice({this.householdName});

  final String? householdName;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final householdLabel = householdName?.trim().isNotEmpty ?? false
        ? householdName!.trim()
        : 'your solo household';
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, color: ks.info, size: 20),
          const SizedBox(width: KsTokens.space8),
          Expanded(
            child: Text(
              '$householdLabel structured records are retained anonymously. '
              'They will no longer be connected to your account.',
              style: KsTokens.bodySmall.copyWith(
                color: ks.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.kind,
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final AccountDeletionErrorKind kind;
  final String message;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      AccountDeletionErrorKind.preflight => 'Could not check eligibility',
      AccountDeletionErrorKind.recentAuthentication =>
        'Recent sign-in required',
      AccountDeletionErrorKind.action => 'Deletion request was not accepted',
    };
    final supportingText = switch (kind) {
      AccountDeletionErrorKind.preflight =>
        'Your account has not been changed.',
      AccountDeletionErrorKind.recentAuthentication =>
        'For your security, confirm your identity again, then retry.',
      AccountDeletionErrorKind.action =>
        'Your account has not been deleted. You can retry or cancel.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatePanel(
          icon: Icon(
            Icons.error_outline_rounded,
            color: context.ksColors.danger,
          ),
          title: title,
          message: supportingText,
        ),
        const SizedBox(height: KsTokens.space12),
        Semantics(liveRegion: true, child: KsErrorAlert(message: message)),
        const SizedBox(height: KsTokens.space12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: _ActionIcon(loading: retrying, icon: Icons.refresh_rounded),
          label: Text(retrying ? 'Trying again...' : 'Try again'),
        ),
      ],
    );
  }
}

class _PendingState extends StatelessWidget {
  const _PendingState({required this.request});

  final AccountDeletionPendingViewModel request;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final accepted = request.status == AccountDeletionRequestStatus.accepted;
    final blocked = request.status == AccountDeletionRequestStatus.blocked;
    return _StatePanel(
      icon: Icon(
        accepted
            ? Icons.task_alt_rounded
            : blocked
            ? Icons.block_outlined
            : Icons.schedule_rounded,
        color: blocked ? ks.warning : ks.success,
      ),
      title: accepted
          ? 'Deletion request accepted'
          : blocked
          ? 'Deletion request saved, but blocked'
          : 'Deletion request pending',
      message:
          request.detail ??
          'Your request is saved. You can close this screen while it '
              'continues.',
      tone: blocked ? ks.warning : ks.success,
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.tone,
  });

  final Widget icon;
  final String title;
  final String message;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: tone?.withValues(alpha: 0.38) ?? ks.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: icon)),
          const SizedBox(width: KsTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
                const SizedBox(height: KsTokens.space4),
                Text(
                  message,
                  style: KsTokens.bodySmall.copyWith(
                    color: ks.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.neutralSubtle,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ks.textSecondary),
          const SizedBox(width: KsTokens.space8),
          Expanded(
            child: Text(
              message,
              style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.cancelEnabled,
    required this.showCancel,
    required this.signOutEnabled,
    required this.signingOut,
    required this.signOutLabel,
  });

  final VoidCallback? cancelEnabled;
  final bool showCancel;
  final VoidCallback? signOutEnabled;
  final bool signingOut;
  final String signOutLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCancel)
          TextButton.icon(
            onPressed: cancelEnabled,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel'),
          ),
        TextButton.icon(
          onPressed: signOutEnabled,
          icon: _ActionIcon(loading: signingOut, icon: Icons.logout_rounded),
          label: Text(signingOut ? 'Signing out...' : signOutLabel),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.loading, required this.icon});

  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!loading) return Icon(icon);
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.ksColors.disabledText,
      ),
    );
  }
}
