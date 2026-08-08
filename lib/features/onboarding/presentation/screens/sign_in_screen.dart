import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/controllers/authentication_controller.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';

/// Screen 13 · Onboarding — a warm front door.
///
/// A produce-tinted hero with the wordmark, then provider + email sign in.
/// Provider availability is tied to the real native Firebase/OAuth build
/// configuration; it never falls back to an anonymous session.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

/// The single auth route is state-aware: a signed-in identity without a
/// confirmed membership enters household recovery here, while a signed-out
/// identity sees the real Login/Register surface. Keeping this on one route
/// prevents a second route from racing Firebase's initial auth event.
class OnboardingEntryScreen extends ConsumerWidget {
  const OnboardingEntryScreen({this.showHouseholdPicker = false, super.key});

  final bool showHouseholdPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(appSessionStateProvider).phase;
    final shouldShowHouseholdPicker =
        phase == AppSessionPhase.needsHouseholdSetup ||
        (showHouseholdPicker && phase == AppSessionPhase.ready);
    return shouldShowHouseholdPicker
        ? const HouseholdSetupScreen()
        : const SignInScreen();
  }
}

enum _EmailAuthMode { signIn, register }

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _EmailAuthMode _emailMode = _EmailAuthMode.signIn;
  bool _saving = false;
  String? _emailError;
  String? _passwordError;
  AuthCredential? _pendingLinkCredential;
  String? _pendingLinkProvider;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() => _runAuthentication(
    () => ref.read(authenticationControllerProvider).signInWithGoogle(),
  );

  Future<void> _continueWithApple() => _runAuthentication(
    () => ref.read(authenticationControllerProvider).signInWithApple(),
  );

  Future<void> _continueWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailError = validateEmailAddress(email);
    final passwordError = validatePassword(
      value: password,
      isRegistration: _emailMode == _EmailAuthMode.register,
    );
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
      });
      return;
    }
    await _runAuthentication(() {
      final auth = ref.read(firebaseAuthProvider);
      if (auth == null) {
        throw const AuthenticationConfigurationException(
          'Firebase Authentication is unavailable in this build.',
        );
      }
      return switch (_emailMode) {
        _EmailAuthMode.signIn => auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        _EmailAuthMode.register => auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      };
    }, registrationRequested: _emailMode == _EmailAuthMode.register);
  }

  Future<void> _runAuthentication(
    Future<UserCredential> Function() authenticate, {
    bool registrationRequested = false,
  }) async {
    if (_saving) return;
    // A successful Firebase credential immediately changes the authoritative
    // session stream. The router is allowed to replace this screen with the
    // explicit auth-loading route before post-auth provisioning finishes, so
    // capture every non-UI dependency before the first await. In particular,
    // reading `ref` in `finally` after the route replacement throws because
    // this ConsumerState has already been disposed.
    final authenticationOperation = ref.read(
      authenticationOperationInProgressProvider.notifier,
    );
    final onboarding = ref.read(householdOnboardingControllerProvider);
    setState(() {
      _saving = true;
      _emailError = null;
      _passwordError = null;
    });
    authenticationOperation.state = true;
    try {
      final credential = await authenticate();
      final pendingCredential = _pendingLinkCredential;
      if (pendingCredential != null) {
        final user = credential.user;
        if (user == null) {
          throw StateError('The existing account could not be restored.');
        }
        await user.linkWithCredential(pendingCredential);
        _pendingLinkCredential = null;
        _pendingLinkProvider = null;
      }
      if (registrationRequested) {
        // Keep the identity signed in so the verification route can own
        // resend/reload/sign-out, but do not provision a household yet.
        await ref
            .read(authenticationControllerProvider)
            .sendEmailVerification();
      }
      await _finishAuthentication(
        credential,
        onboarding: onboarding,
        registrationRequested: registrationRequested,
      );
    } catch (error) {
      _capturePendingLinkIfNeeded(error);
      _showAuthenticationError(error);
    } finally {
      authenticationOperation.state = false;
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_saving) return;
    final email = _emailController.text.trim();
    final emailError = validateEmailAddress(email);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }
    setState(() {
      _saving = true;
      _emailError = null;
    });
    ref.read(authenticationOperationInProgressProvider.notifier).state = true;
    try {
      await ref
          .read(authenticationControllerProvider)
          .sendPasswordResetEmail(email: email);
      if (mounted) {
        // The phone keyboard can consume the entire short emulator viewport.
        // Dismiss it before showing the confirmation so a floating snackbar
        // is neither clipped nor reported as off-screen by Scaffold.
        FocusManager.instance.primaryFocus?.unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(
              'If this email has an account, we sent password reset '
              'instructions.',
            ),
          ),
        );
      }
    } catch (error) {
      _showAuthenticationError(error);
    } finally {
      ref.read(authenticationOperationInProgressProvider.notifier).state =
          false;
      if (mounted) setState(() => _saving = false);
    }
  }

  void _capturePendingLinkIfNeeded(Object error) {
    if (error is! FirebaseAuthException ||
        error.code != 'account-exists-with-different-credential' ||
        error.credential == null ||
        !mounted) {
      return;
    }
    setState(() {
      _pendingLinkCredential = error.credential;
      _pendingLinkProvider = error.credential!.providerId;
      _emailMode = _EmailAuthMode.signIn;
      if (error.email != null && error.email!.isNotEmpty) {
        _emailController.text = error.email!;
      }
    });
  }

  Future<void> _finishAuthentication(
    UserCredential credential, {
    required HouseholdOnboardingController onboarding,
    required bool registrationRequested,
  }) async {
    final user = credential.user;
    if (user == null) {
      throw StateError('The authenticated account could not be restored.');
    }
    // Existing confirmed-household users can continue using the app while an
    // email claim is pending. This guard only prevents new provisioning.
    if (!user.emailVerified) return;
    final shouldProvision =
        registrationRequested ||
        (credential.additionalUserInfo?.isNewUser ?? false) ||
        await onboarding.needsInitialProvisioning();
    if (shouldProvision) {
      // This transaction is deterministic and idempotent. Crucially, a
      // transient Firestore failure does not delete the Firebase identity;
      // the signed-in user is routed to household recovery and can retry.
      await onboarding.ensureInitialSoloHousehold();
    }
    if (!mounted) return;
    context.go('/today');
  }

  void _showAuthenticationError(Object error) {
    final message = authenticationErrorMessage(error);
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final availability = ref.watch(authenticationProviderAvailabilityProvider);
    final pendingLinkProvider = _pendingLinkProvider;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      // Keep one scrollable surface rather than a fixed-height hero above an
      // Expanded form. Android can temporarily report a zero-height body
      // while the keyboard animates; a Column would then overflow and hide
      // the sign-in controls exactly when a user needs them.
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _BrandHero(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, KsTokens.space24, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (availability.apple) ...[
                    _ProviderButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple,
                      background: ks.textPrimary,
                      foreground: ks.surfaceBase,
                      onTap: _saving ? null : _continueWithApple,
                    ),
                    const SizedBox(height: KsTokens.space10),
                  ],
                  _ProviderButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata_rounded,
                    background: ks.surfaceRaised,
                    foreground: ks.textPrimary,
                    border: ks.borderStrong,
                    onTap: _saving || !availability.google
                        ? null
                        : _continueWithGoogle,
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const _OrRule(),
                  const SizedBox(height: KsTokens.space16),
                  if (pendingLinkProvider != null) ...[
                    _LinkExistingAccountNotice(providerId: pendingLinkProvider),
                    const SizedBox(height: KsTokens.space12),
                  ],
                  SegmentedButton<_EmailAuthMode>(
                    segments: const [
                      ButtonSegment(
                        value: _EmailAuthMode.signIn,
                        icon: Icon(Icons.login_rounded),
                        label: Text('Login'),
                      ),
                      ButtonSegment(
                        value: _EmailAuthMode.register,
                        icon: Icon(Icons.person_add_alt_1_rounded),
                        label: Text('Register'),
                      ),
                    ],
                    selected: {_emailMode},
                    showSelectedIcon: false,
                    onSelectionChanged: _saving
                        ? null
                        : (selection) => setState(() {
                            _emailMode = selection.single;
                            _passwordError = null;
                            _emailError = null;
                          }),
                  ),
                  const SizedBox(height: KsTokens.space12),
                  _EmailField(
                    controller: _emailController,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: KsTokens.space10),
                  _PasswordField(
                    controller: _passwordController,
                    errorText: _passwordError,
                    isRegistration: _emailMode == _EmailAuthMode.register,
                  ),
                  if (_emailMode == _EmailAuthMode.signIn) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _saving ? null : _sendPasswordReset,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ],
                  FilledButton(
                    onPressed: _saving ? null : _continueWithEmail,
                    child: Text(
                      _saving
                          ? 'Continuing...'
                          : switch (_emailMode) {
                              _EmailAuthMode.signIn => 'Login',
                              _EmailAuthMode.register => 'Create account',
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The produce → grain → accent gradient hero carrying the wordmark and the
/// app's italic promise.
class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(ks.surfaceBase, KsTokens.catProduce, 0.34)!,
            Color.lerp(ks.surfaceBase, KsTokens.catGrain, 0.30)!,
            Color.lerp(ks.surfaceBase, KsTokens.brandAccent, 0.22)!,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              left: 24,
              right: 24,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.eco_rounded,
                    size: 34,
                    color: KsTokens.brandPrimaryDark,
                  ),
                  const SizedBox(height: KsTokens.space10),
                  Text(
                    'KitchenSync',
                    style: KsTokens.displayLarge.copyWith(
                      color: ks.textPrimary,
                      fontSize: 38,
                      height: 0.95,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space4),
                  Text(
                    'Run your kitchen as one calm loop.',
                    style: KsTokens.displaySmall.copyWith(
                      color: ks.textSecondary,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
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

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ks = context.ksColors;
    final effectiveBackground = enabled
        ? background
        : Color.alphaBlend(
            Theme.of(context).disabledColor.withValues(alpha: 0.08),
            ks.surfaceRaised,
          );
    final effectiveForeground = enabled ? foreground : ks.textTertiary;
    return Material(
      color: effectiveBackground,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: effectiveForeground),
              const SizedBox(width: KsTokens.space8),
              Text(
                label,
                style: KsTokens.labelLarge.copyWith(
                  color: effectiveForeground,
                  letterSpacing: 0,
                ),
              ),
              if (!enabled) ...[
                const SizedBox(width: KsTokens.space8),
                Text(
                  'Not configured',
                  style: KsTokens.labelSmall.copyWith(
                    color: effectiveForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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

class _LinkExistingAccountNotice extends StatelessWidget {
  const _LinkExistingAccountNotice({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final provider = switch (providerId) {
      'google.com' => 'Google',
      'apple.com' => 'Apple',
      _ => 'that provider',
    };
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius10),
        border: Border.all(color: ks.borderStrong),
      ),
      child: Text(
        'Sign in with your existing account, then $provider will be linked '
        'securely.',
        style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, this.errorText});

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      style: KsTokens.bodyMedium.copyWith(color: ks.textPrimary),
      decoration: InputDecoration(
        hintText: 'you@email.com',
        errorText: errorText,
        filled: true,
        fillColor: ks.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius10),
          borderSide: BorderSide(color: ks.borderStrong),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius10),
          borderSide: BorderSide(color: ks.borderStrong),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.isRegistration,
    this.errorText,
  });

  final TextEditingController controller;
  final bool isRegistration;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextField(
      controller: controller,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      style: KsTokens.bodyMedium.copyWith(color: ks.textPrimary),
      decoration: InputDecoration(
        hintText: isRegistration ? 'Password (12+ characters)' : 'Password',
        errorText: errorText,
        filled: true,
        fillColor: ks.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius10),
          borderSide: BorderSide(color: ks.borderStrong),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius10),
          borderSide: BorderSide(color: ks.borderStrong),
        ),
      ),
    );
  }
}
