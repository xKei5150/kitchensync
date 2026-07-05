import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';

/// Screen 13 · Onboarding — a warm front door.
///
/// A produce-tinted hero with the wordmark, then provider + email sign in.
/// Email/password is live; OAuth buttons stay disabled until provider
/// credentials are explicitly enabled for the build.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  static const _appleAuthEnabled = bool.fromEnvironment('ENABLE_APPLE_AUTH');
  static const _googleAuthEnabled = bool.fromEnvironment('ENABLE_GOOGLE_AUTH');

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueWithProvider(String provider) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in is not configured yet.')),
    );
  }

  Future<void> _continueWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password.')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final auth = ref.read(firebaseAuthProvider);
    try {
      if (auth != null && auth.currentUser == null) {
        try {
          await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (error) {
          if (error.code != 'user-not-found' &&
              error.code != 'invalid-credential' &&
              error.code != 'wrong-password') {
            rethrow;
          }
          await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not sign in: $error')));
      return;
    }
    if (!mounted) return;
    await context.push('/onboarding/household');
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: Column(
        children: [
          const _BrandHero(),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  KsTokens.space24,
                  22,
                  22,
                ),
                children: [
                  _ProviderButton(
                    label: 'Continue with Apple',
                    icon: Icons.apple,
                    background: ks.textPrimary,
                    foreground: ks.surfaceBase,
                    onTap: _appleAuthEnabled
                        ? () => _continueWithProvider('Apple')
                        : null,
                  ),
                  const SizedBox(height: KsTokens.space10),
                  _ProviderButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata_rounded,
                    background: ks.surfaceRaised,
                    foreground: ks.textPrimary,
                    border: ks.borderStrong,
                    onTap: _googleAuthEnabled
                        ? () => _continueWithProvider('Google')
                        : null,
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const _OrRule(),
                  const SizedBox(height: KsTokens.space16),
                  _EmailField(controller: _emailController),
                  const SizedBox(height: KsTokens.space10),
                  _PasswordField(controller: _passwordController),
                  const SizedBox(height: KsTokens.space10),
                  FilledButton(
                    onPressed: _saving ? null : _continueWithEmail,
                    child: Text(
                      _saving ? 'Continuing...' : 'Continue with email',
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

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

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
  const _PasswordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextField(
      controller: controller,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      style: KsTokens.bodyMedium.copyWith(color: ks.textPrimary),
      decoration: InputDecoration(
        hintText: 'Password',
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
