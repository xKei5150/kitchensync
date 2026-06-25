import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Screen 13 · Onboarding — a warm front door.
///
/// A produce-tinted hero with the wordmark, then OAuth + email sign in. The
/// front door is presentational P2: no auth backend is wired, so each path
/// advances to household setup.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  void _continue(BuildContext context) => context.push('/onboarding/household');

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
                    onTap: () => _continue(context),
                  ),
                  const SizedBox(height: KsTokens.space10),
                  _ProviderButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata_rounded,
                    background: ks.surfaceRaised,
                    foreground: ks.textPrimary,
                    border: ks.borderStrong,
                    onTap: () => _continue(context),
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const _OrRule(),
                  const SizedBox(height: KsTokens.space16),
                  const _EmailField(),
                  const SizedBox(height: KsTokens.space10),
                  FilledButton(
                    onPressed: () => _continue(context),
                    child: const Text('Continue with email'),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
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
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: KsTokens.space8),
              Text(
                label,
                style: KsTokens.labelLarge.copyWith(
                  color: foreground,
                  letterSpacing: 0,
                ),
              ),
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
  const _EmailField();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextField(
      keyboardType: TextInputType.emailAddress,
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
