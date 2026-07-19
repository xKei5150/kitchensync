part of 'recipe_detail_screen.dart';

/// The full-bleed editorial hero — a category-tinted wash, a circular back and
/// bookmark in the safe area, and the eyebrow + serif title riding a bottom
/// scrim.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.tags,
    required this.saved,
    required this.onBack,
    this.onToggleSaved,
  });

  final String title;
  final List<String> tags;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback? onToggleSaved;

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
                      if (onToggleSaved != null)
                        _ScrimButton(
                          icon: saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          tooltip: saved ? 'Unsave recipe' : 'Save recipe',
                          onTap: onToggleSaved,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _eyebrow.toUpperCase(),
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

  String get _eyebrow {
    final tag = tags.isEmpty ? 'Recipe' : tags.first;
    return 'Closer Look · $tag';
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
