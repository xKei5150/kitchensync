import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Presentation-only confirmation shown after an account deletion request has
/// been accepted and the account has been signed out.
///
/// The route owner supplies [onContinue] so this screen stays independent of
/// routing, session state, and the deletion workflow itself.
class AccountDeletionRequestedScreen extends StatelessWidget {
  const AccountDeletionRequestedScreen({required this.onContinue, super.key});

  /// Continue to the sign-in surface after the account has been signed out.
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22,
                KsTokens.space24,
                22,
                KsTokens.space16 + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AcceptedMark(color: ks.success),
                          const SizedBox(height: KsTokens.space20),
                          Semantics(
                            header: true,
                            child: Text(
                              'Deletion request accepted',
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
                            'Your request was accepted. You are signed out '
                            'while processing continues.',
                            textAlign: TextAlign.center,
                            style: KsTokens.bodyMedium.copyWith(
                              color: ks.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: KsTokens.space20),
                          const _SignedOutPanel(),
                          const SizedBox(height: KsTokens.space24),
                          FilledButton.icon(
                            onPressed: onContinue,
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Return to sign in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AcceptedMark extends StatelessWidget {
  const _AcceptedMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ExcludeSemantics(
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(KsTokens.radius16),
            border: Border.all(color: color.withValues(alpha: 0.36)),
          ),
          child: Icon(Icons.task_alt_rounded, size: 28, color: color),
        ),
      ),
    );
  }
}

class _SignedOutPanel extends StatelessWidget {
  const _SignedOutPanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Semantics(
      liveRegion: true,
      container: true,
      label:
          'Signed out. The deletion request will continue processing after '
          'sign-out.',
      child: Container(
        padding: const EdgeInsets.all(KsTokens.space12),
        decoration: BoxDecoration(
          color: ks.surfaceRaised,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          border: Border.all(color: ks.success.withValues(alpha: 0.38)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ks.neutralSubtle,
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: ks.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: KsTokens.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're signed out",
                    style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                  ),
                  const SizedBox(height: KsTokens.space4),
                  Text(
                    'The deletion request continues processing after you '
                    'leave this screen.',
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
    );
  }
}
