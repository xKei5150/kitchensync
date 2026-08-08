import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/email_verification_screen.dart';

/// Firebase-backed wrapper for the presentation-only verification surface.
///
/// Firebase owns the identity and token refresh while the reusable screen owns
/// the visual states and action controls.
class EmailVerificationRouteScreen extends ConsumerStatefulWidget {
  const EmailVerificationRouteScreen({super.key});

  @override
  ConsumerState<EmailVerificationRouteScreen> createState() =>
      _EmailVerificationRouteScreenState();
}

class _EmailVerificationRouteScreenState
    extends ConsumerState<EmailVerificationRouteScreen> {
  bool _isRefreshing = false;
  bool _isResending = false;
  bool _isSigningOut = false;
  String? _errorMessage;

  Future<void> _refreshStatus() async {
    if (_isBusy) return;
    final controller = ref.read(authenticationControllerProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    try {
      await controller.reloadAndRefreshEmailVerification();
      container
        ..invalidate(activeFirebaseUserProvider)
        ..invalidate(activeHouseholdContextStreamProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = emailVerificationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_isBusy) return;
    final controller = ref.read(authenticationControllerProvider);
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    try {
      await controller.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = emailVerificationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    if (_isBusy) return;
    final controller = ref.read(authenticationControllerProvider);
    final operation = ref.read(
      authenticationOperationInProgressProvider.notifier,
    );
    setState(() {
      _isSigningOut = true;
      _errorMessage = null;
    });
    operation.state = true;
    try {
      await controller.signOut();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = emailVerificationErrorMessage(error));
      }
    } finally {
      operation.state = false;
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  bool get _isBusy => _isRefreshing || _isResending || _isSigningOut;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider)?.currentUser;
    if (user == null) return const SizedBox.shrink();
    return EmailVerificationScreen(
      accountEmail: user.email ?? 'your account email',
      onRefreshStatus: _refreshStatus,
      onResendVerification: _resendVerification,
      onSignOut: _signOut,
      isRefreshing: _isRefreshing,
      isResending: _isResending,
      isSigningOut: _isSigningOut,
      errorMessage: _errorMessage,
    );
  }
}
