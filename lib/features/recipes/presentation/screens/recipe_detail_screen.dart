import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 06 · Recipe detail · "Closer Look" — a cookbook spread that scales
/// live.
///
/// Full-bleed and photo-led: a category-tinted hero, a drop-cap intro, then the
/// [KsServingScaler] rescaling the ingredient list in real time. Reused by the
/// calendar when picking a meal. Presentational P1 with representative sample
/// data.
class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key});

  /// The braise carried through from Today / the calendar's tonight card.
  static const _title = 'Tomato & white bean braise';
  static const _intro =
      'weeknight braise that tastes like a Sunday — soft beans, blistered '
      'tomatoes, a slick of good oil. Forgiving, and better the next day.';

  static const _ingredients = [
    KsScalableIngredient(name: 'White beans', baseAmount: 2, unit: 'tins'),
    KsScalableIngredient(name: 'Tomatoes', baseAmount: 800, unit: 'g'),
    KsScalableIngredient(name: 'Spinach', baseAmount: 1, unit: 'bunch'),
    KsScalableIngredient(name: 'Olive oil', baseAmount: 3, unit: 'tbsp'),
  ];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(title: _title, onBack: () => context.pop()),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KsTokens.space20,
              KsTokens.space16,
              KsTokens.space20,
              KsTokens.space24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DropCapIntro(initial: 'A', body: _intro),
                const SizedBox(height: KsTokens.space16),
                const KsServingScaler(
                  baseServings: 4,
                  ingredients: _ingredients,
                ),
                const SizedBox(height: KsTokens.space20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Start cooking'),
                      ),
                    ),
                    const SizedBox(width: KsTokens.space10),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Schedule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-bleed editorial hero — a category-tinted wash, a circular back and
/// bookmark in the safe area, and the eyebrow + serif title riding a bottom
/// scrim.
class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raised = ks.surfaceRaised;
    final accent = isDark ? KsTokens.brandAccent : KsTokens.catSpice;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(raised, KsTokens.catProduce, isDark ? 0.30 : 0.40)!,
        Color.lerp(raised, KsTokens.catGrain, isDark ? 0.26 : 0.34)!,
        Color.lerp(raised, accent, isDark ? 0.24 : 0.30)!,
      ],
    );

    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          // Bottom scrim so the white title stays legible over any wash.
          const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x80000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space16,
                KsTokens.space8,
                KsTokens.space16,
                KsTokens.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ScrimButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: onBack,
                      ),
                      const _ScrimButton(
                        icon: Icons.bookmark_border_rounded,
                        tooltip: 'Save recipe',
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Closer Look · Vegetarian'.toUpperCase(),
                    style: KsTokens.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space4),
                  Text(
                    title,
                    style: KsTokens.displayMedium.copyWith(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.05,
                      letterSpacing: -0.6,
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

/// A circular translucent control on the hero scrim.
class _ScrimButton extends StatelessWidget {
  const _ScrimButton({required this.icon, this.tooltip, this.onTap});

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// A drop-cap editorial intro — an oversized serif initial that the body text
/// wraps around, set via an inline [WidgetSpan].
class _DropCapIntro extends StatelessWidget {
  const _DropCapIntro({required this.initial, required this.body});

  final String initial;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Padding(
              padding: const EdgeInsets.only(right: 9, top: 5),
              child: Text(
                initial,
                style: KsTokens.displayLarge.copyWith(
                  color: isDark
                      ? KsTokens.brandAccent
                      : KsTokens.brandPrimaryDark,
                  fontSize: 46,
                  height: 0.74,
                ),
              ),
            ),
          ),
          TextSpan(
            text: body,
            style: KsTokens.bodyMedium.copyWith(
              color: ks.textSecondary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
