import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Providers supported by the provider-reauthentication action.
enum ReauthenticationProvider { google, apple }

/// Presentation state supplied by the integration lane.
///
/// The widget never creates credentials or calls Firebase. The integration
/// lane updates this model after each provider operation and owns all errors.
class ReauthenticationViewModel {
  const ReauthenticationViewModel({
    required this.currentEmail,
    this.availableProviders = const <ReauthenticationProvider>[],
    this.isEmailSubmitting = false,
    this.activeProvider,
    this.passwordError,
    this.errorMessage,
  });

  final String currentEmail;
  final List<ReauthenticationProvider> availableProviders;
  final bool isEmailSubmitting;
  final ReauthenticationProvider? activeProvider;
  final String? passwordError;
  final String? errorMessage;

  bool get isBusy => isEmailSubmitting || activeProvider != null;

  bool isProviderSubmitting(ReauthenticationProvider provider) =>
      activeProvider == provider;
}

/// Presentation-only reauthentication form for sensitive account actions.
///
/// The current email is displayed as read-only context. Password and provider
/// callbacks are typed seams for the later Firebase integration lane; neither
/// callback is awaited or implemented by this widget.
class ReauthenticationScreen extends StatefulWidget {
  const ReauthenticationScreen({
    required this.viewModel,
    this.onEmailPasswordReauthenticate,
    this.onProviderReauthenticate,
    this.onCancel,
    super.key,
  });

  final ReauthenticationViewModel viewModel;
  final ValueChanged<String>? onEmailPasswordReauthenticate;
  final ValueChanged<ReauthenticationProvider>? onProviderReauthenticate;
  final VoidCallback? onCancel;

  @override
  State<ReauthenticationScreen> createState() => _ReauthenticationScreenState();
}

class _ReauthenticationScreenState extends State<ReauthenticationScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _localPasswordError;
  bool _obscurePassword = true;

  ReauthenticationViewModel get _model => widget.viewModel;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submitEmailPassword() {
    if (_model.isBusy || widget.onEmailPasswordReauthenticate == null) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _localPasswordError = 'Enter your password.');
      return;
    }
    setState(() => _localPasswordError = null);
    widget.onEmailPasswordReauthenticate!(password);
  }

  void _clearLocalPasswordError(String value) {
    if (_localPasswordError == null || value.isEmpty) return;
    setState(() => _localPasswordError = null);
  }

  VoidCallback? _enabled(VoidCallback? callback) =>
      _model.isBusy ? null : callback;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final providers = _model.availableProviders.toSet().toList();
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ReauthenticationHeader(),
                      const SizedBox(height: KsTokens.space20),
                      if (_model.errorMessage case final message?) ...[
                        Semantics(
                          liveRegion: true,
                          child: KsErrorAlert(message: message),
                        ),
                        const SizedBox(height: KsTokens.space12),
                      ],
                      _CurrentEmailField(email: _model.currentEmail),
                      const SizedBox(height: KsTokens.space10),
                      _PasswordField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        errorText: _localPasswordError ?? _model.passwordError,
                        onChanged: _clearLocalPasswordError,
                        onSubmitted: _submitEmailPassword,
                        onToggleVisibility: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      const SizedBox(height: KsTokens.space12),
                      FilledButton.icon(
                        key: const Key('reauth-email-password-action'),
                        onPressed: _model.isBusy
                            ? null
                            : widget.onEmailPasswordReauthenticate == null
                            ? null
                            : _submitEmailPassword,
                        icon: _ActionIcon(
                          loading: _model.isEmailSubmitting,
                          icon: Icons.lock_open_outlined,
                        ),
                        label: Text(
                          _model.isEmailSubmitting
                              ? 'Reauthenticating...'
                              : 'Reauthenticate',
                        ),
                      ),
                      if (providers.isNotEmpty) ...[
                        const SizedBox(height: KsTokens.space16),
                        const _OrRule(),
                        const SizedBox(height: KsTokens.space16),
                        for (
                          var index = 0;
                          index < providers.length;
                          index++
                        ) ...[
                          if (index > 0)
                            const SizedBox(height: KsTokens.space10),
                          _ProviderButton(
                            provider: providers[index],
                            loading: _model.isProviderSubmitting(
                              providers[index],
                            ),
                            onPressed:
                                _model.isBusy ||
                                    widget.onProviderReauthenticate == null
                                ? null
                                : () => widget.onProviderReauthenticate!(
                                    providers[index],
                                  ),
                          ),
                        ],
                      ],
                      const SizedBox(height: KsTokens.space24),
                      const Divider(),
                      const SizedBox(height: KsTokens.space8),
                      TextButton.icon(
                        key: const Key('reauth-cancel-action'),
                        onPressed: _enabled(widget.onCancel),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReauthenticationHeader extends StatelessWidget {
  const _ReauthenticationHeader();

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
            color: ks.info.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(KsTokens.radius16),
            border: Border.all(color: ks.info.withValues(alpha: 0.34)),
          ),
          child: Icon(Icons.lock_outline_rounded, size: 28, color: ks.info),
        ),
        const SizedBox(height: KsTokens.space12),
        Semantics(
          header: true,
          child: Text(
            'Confirm your identity',
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
          'Sign in again to continue securely.',
          textAlign: TextAlign.center,
          style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
        ),
      ],
    );
  }
}

class _CurrentEmailField extends StatelessWidget {
  const _CurrentEmailField({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextFormField(
      key: ValueKey('reauth-current-email-$email'),
      initialValue: email,
      readOnly: true,
      enableInteractiveSelection: false,
      style: KsTokens.bodyMedium.copyWith(color: ks.textPrimary),
      decoration: InputDecoration(
        labelText: 'Current email',
        prefixIcon: const Icon(Icons.email_outlined),
        filled: true,
        fillColor: ks.surfaceRaised,
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscureText,
    required this.errorText,
    required this.onChanged,
    required this.onSubmitted,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final bool obscureText;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextFormField(
      key: const Key('reauth-password-field'),
      controller: controller,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.password],
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      scrollPadding: const EdgeInsets.only(bottom: 128),
      onChanged: onChanged,
      onFieldSubmitted: (_) => onSubmitted(),
      style: KsTokens.bodyMedium.copyWith(color: ks.textPrimary),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.password_outlined),
        errorText: errorText,
        filled: true,
        fillColor: ks.surfaceRaised,
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Show password' : 'Hide password',
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.provider,
    required this.loading,
    required this.onPressed,
  });

  final ReauthenticationProvider provider;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (provider) {
      ReauthenticationProvider.google => 'Reauthenticate with Google',
      ReauthenticationProvider.apple => 'Reauthenticate with Apple',
    };
    final icon = switch (provider) {
      ReauthenticationProvider.google => Icons.g_mobiledata_rounded,
      ReauthenticationProvider.apple => Icons.apple,
    };
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: _ActionIcon(loading: loading, icon: icon),
      label: Text(loading ? 'Reauthenticating...' : label),
    );
  }
}

class _OrRule extends StatelessWidget {
  const _OrRule();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: ks.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KsTokens.space10),
          child: Text(
            'or',
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: ks.hairline)),
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
