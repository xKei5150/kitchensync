import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// A presentation-only gate for accounts that still need email verification.
///
/// The owning logic supplies the request callbacks and their current states.
/// This keeps the screen usable from Firebase, Riverpod, or another auth
/// adapter without embedding a verification workflow here.
class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({
    required this.accountEmail,
    this.onRefreshStatus,
    this.onResendVerification,
    this.onSignOut,
    this.isRefreshing = false,
    this.isResending = false,
    this.isSigningOut = false,
    this.errorMessage,
    super.key,
  });

  final String accountEmail;
  final VoidCallback? onRefreshStatus;
  final VoidCallback? onResendVerification;
  final VoidCallback? onSignOut;
  final bool isRefreshing;
  final bool isResending;
  final bool isSigningOut;
  final String? errorMessage;

  bool get _isBusy => isRefreshing || isResending || isSigningOut;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            22,
            KsTokens.space24,
            22,
            KsTokens.space16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VerificationMark(color: ks.brandPrimary),
                  const SizedBox(height: KsTokens.space20),
                  Semantics(
                    header: true,
                    child: Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: KsTokens.displayMedium.copyWith(
                        color: ks.textPrimary,
                        fontSize: 28,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: KsTokens.space8),
                  Text(
                    'Open the verification link sent to',
                    textAlign: TextAlign.center,
                    style: KsTokens.bodyMedium.copyWith(
                      color: ks.textSecondary,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space4),
                  Semantics(
                    label: 'Account email: $accountEmail',
                    child: Text(
                      accountEmail,
                      textAlign: TextAlign.center,
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: KsTokens.space20),
                  _VerificationStatus(isRefreshing: isRefreshing),
                  if (errorMessage case final message?) ...[
                    const SizedBox(height: KsTokens.space12),
                    Semantics(
                      liveRegion: true,
                      child: KsErrorAlert(message: message),
                    ),
                  ],
                  const SizedBox(height: KsTokens.space20),
                  FilledButton.icon(
                    onPressed: _isBusy ? null : onRefreshStatus,
                    icon: _ActionIcon(
                      loading: isRefreshing,
                      icon: Icons.refresh_rounded,
                    ),
                    label: Text(isRefreshing ? 'Checking...' : 'Try again'),
                  ),
                  const SizedBox(height: KsTokens.space10),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : onResendVerification,
                    icon: _ActionIcon(
                      loading: isResending,
                      icon: Icons.mark_email_unread_outlined,
                    ),
                    label: Text(
                      isResending ? 'Sending...' : 'Resend verification email',
                    ),
                  ),
                  const SizedBox(height: KsTokens.space8),
                  TextButton.icon(
                    onPressed: _isBusy ? null : onSignOut,
                    icon: _ActionIcon(
                      loading: isSigningOut,
                      icon: Icons.logout_rounded,
                    ),
                    label: Text(isSigningOut ? 'Signing out...' : 'Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationMark extends StatelessWidget {
  const _VerificationMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Align(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(KsTokens.radius16),
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Icon(
          Icons.mark_email_read_outlined,
          size: 28,
          color: ks.brandPrimary,
        ),
      ),
    );
  }
}

class _VerificationStatus extends StatelessWidget {
  const _VerificationStatus({required this.isRefreshing});

  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
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
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ks.neutralSubtle,
              borderRadius: BorderRadius.circular(KsTokens.radius10),
            ),
            child: isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ks.brandPrimary,
                    ),
                  )
                : Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: ks.textSecondary,
                  ),
          ),
          const SizedBox(width: KsTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRefreshing
                      ? 'Checking verification status'
                      : 'Awaiting verification',
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  isRefreshing
                      ? 'We are checking your account now.'
                      : 'Return here after opening the link.',
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
        color: context.ksColors.textSecondary,
      ),
    );
  }
}
