part of 'shopping_screen.dart';

/// The prominent Shop Now banner inviting the household to buy ahead.
class _ShopNowCard extends StatelessWidget {
  const _ShopNowCard({required this.onStart, this.locked = false});

  final VoidCallback? onStart;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: KsTokens.shoppingHomeHeroPadding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KsTokens.brandPrimary, KsTokens.brandPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(KsTokens.radius16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop Now'.toUpperCase(),
            style: KsTokens.shoppingHomeHeroEyebrow.copyWith(
              color: KsTokens.textOnBrand.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: KsTokens.space6),
          Text(
            'Knock out next week early?',
            style: KsTokens.shoppingHomeHeroTitle.copyWith(
              color: KsTokens.textOnBrand,
            ),
          ),
          const SizedBox(height: KsTokens.space4),
          Text(
            'Buy ahead and future lists shrink as you go.',
            style: KsTokens.bodySmall.copyWith(
              color: KsTokens.textOnBrand.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: KsTokens.shoppingHomeHeroActionGap),
          _OnBrandButton(
            label: locked ? 'Shopper access required' : 'Start a shop',
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

class _OnBrandButton extends StatelessWidget {
  const _OnBrandButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KsTokens.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: KsTokens.shoppingHomeActionPadding,
          child: Text(
            label,
            style: KsTokens.shoppingHomeActionLabel.copyWith(
              color: KsTokens.brandPrimaryDark,
            ),
          ),
        ),
      ),
    );
  }
}
