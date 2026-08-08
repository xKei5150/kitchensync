import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/settings/presentation/reauthentication_screen.dart';

/// Firebase-backed wrapper for the accepted reauthentication presentation.
class ReauthenticationRouteScreen extends ConsumerStatefulWidget {
  const ReauthenticationRouteScreen({super.key});

  @override
  ConsumerState<ReauthenticationRouteScreen> createState() =>
      _ReauthenticationRouteScreenState();
}

class _ReauthenticationRouteScreenState
    extends ConsumerState<ReauthenticationRouteScreen> {
  bool _isEmailSubmitting = false;
  ReauthenticationProvider? _activeProvider;
  String? _passwordError;
  String? _errorMessage;

  Future<void> _reauthenticateWithPassword(String password) async {
    if (_isBusy) return;
    final authentication = ref.read(authenticationControllerProvider);
    setState(() {
      _isEmailSubmitting = true;
      _passwordError = null;
      _errorMessage = null;
    });
    try {
      await authentication.reauthenticateWithEmailPassword(password: password);
      if (mounted) GoRouter.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = reauthenticationErrorMessage(error);
      setState(() {
        _passwordError = message == 'That password was not accepted.'
            ? message
            : null;
        _errorMessage = _passwordError == null && message.isNotEmpty
            ? message
            : null;
      });
    } finally {
      if (mounted) setState(() => _isEmailSubmitting = false);
    }
  }

  Future<void> _reauthenticateWithProvider(
    ReauthenticationProvider provider,
  ) async {
    if (_isBusy) return;
    final authentication = ref.read(authenticationControllerProvider);
    setState(() {
      _activeProvider = provider;
      _passwordError = null;
      _errorMessage = null;
    });
    try {
      switch (provider) {
        case ReauthenticationProvider.google:
          await authentication.reauthenticateWithGoogle();
        case ReauthenticationProvider.apple:
          await authentication.reauthenticateWithApple();
      }
      if (mounted) GoRouter.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = reauthenticationErrorMessage(error);
      if (message.isNotEmpty) setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _activeProvider = null);
    }
  }

  bool get _isBusy => _isEmailSubmitting || _activeProvider != null;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseAuthProvider);
    final user = auth?.currentUser;
    if (user == null) return const SizedBox.shrink();

    final availability = ref.watch(authenticationProviderAvailabilityProvider);
    final linkedProviderIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    final providers = <ReauthenticationProvider>[
      if (availability.google && linkedProviderIds.contains('google.com'))
        ReauthenticationProvider.google,
      if (availability.apple && linkedProviderIds.contains('apple.com'))
        ReauthenticationProvider.apple,
    ];
    return ReauthenticationScreen(
      viewModel: ReauthenticationViewModel(
        currentEmail: user.email ?? 'Current account',
        availableProviders: providers,
        isEmailSubmitting: _isEmailSubmitting,
        activeProvider: _activeProvider,
        passwordError: _passwordError,
        errorMessage: _errorMessage,
      ),
      onEmailPasswordReauthenticate: _hasPasswordProvider(user)
          ? _reauthenticateWithPassword
          : null,
      onProviderReauthenticate: _reauthenticateWithProvider,
      onCancel: () => GoRouter.of(context).pop(false),
    );
  }

  bool _hasPasswordProvider(User user) =>
      user.providerData.any((provider) => provider.providerId == 'password');
}
