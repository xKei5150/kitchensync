import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 09 · Shopping home + Shop Now.
///
/// The Shop tab landing: scheduled shop dates, a slim history, and a prominent
/// Shop Now that opens the "how far ahead?" setup before building a list.
/// Presentational P1 with representative sample data; the in-store checklist
/// lives at `/shop/list`.
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  static const _upcoming = [
    _UpcomingShop(title: 'Weekly shop', when: 'Fri 27 · 11 items'),
    _UpcomingShop(title: 'Next week', when: 'Fri 4 Jul · 9 items'),
  ];

  Future<void> _openShopNow(BuildContext context) async {
    final start = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ShopNowSheet(),
    );
    if ((start ?? false) && context.mounted) {
      unawaited(context.push('/shop/list'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space8,
          KsTokens.space16,
          KsTokens.space24,
        ),
        children: [
          const KsFolioHeader(eyebrow: 'The Shop', title: 'Shopping'),
          const SizedBox(height: KsTokens.space16),
          _ShopNowCard(onStart: () => _openShopNow(context)),
          const SizedBox(height: KsTokens.space20),
          const _SectionLabel('Upcoming'),
          const SizedBox(height: KsTokens.space10),
          for (final shop in _upcoming) ...[
            _UpcomingTile(shop: shop, onTap: () => context.push('/shop/list')),
            const SizedBox(height: KsTokens.space8),
          ],
          const SizedBox(height: KsTokens.space12),
          const _SectionLabel('History'),
          const SizedBox(height: KsTokens.space10),
          const _HistoryRow(label: 'Fri 20 Jun · 13 items · £58'),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: KsTokens.labelSmall.copyWith(
        color: context.ksColors.textTertiary,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1,
      ),
    );
  }
}

/// The prominent Shop Now banner — a brand-green gradient card inviting the
/// household to buy ahead and shrink future lists.
class _ShopNowCard extends StatelessWidget {
  const _ShopNowCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            style: KsTokens.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: KsTokens.space6),
          Text(
            'Knock out next week early?',
            style: KsTokens.displaySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 21,
              height: 1.1,
            ),
          ),
          const SizedBox(height: KsTokens.space4),
          Text(
            'Buy ahead and future lists shrink as you go.',
            style: KsTokens.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 13),
          _OnBrandButton(label: 'Start a shop', onTap: onStart),
        ],
      ),
    );
  }
}

/// A white pill button reading on the brand gradient.
class _OnBrandButton extends StatelessWidget {
  const _OnBrandButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(KsTokens.radius10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Text(
            label,
            style: KsTokens.labelMedium.copyWith(
              color: KsTokens.brandPrimaryDark,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingShop {
  const _UpcomingShop({required this.title, required this.when});

  final String title;
  final String when;
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.shop, required this.onTap});

  final _UpcomingShop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: KsTokens.space12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ks.calShopping.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: ks.calShopping,
                ),
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.title,
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: KsTokens.space2),
                    Text(
                      shop.when,
                      style: KsTokens.labelSmall.copyWith(
                        color: ks.textTertiary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ks.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        const Icon(Icons.check_rounded, size: 16, color: KsTokens.fresh),
        const SizedBox(width: KsTokens.space10),
        Expanded(
          child: Text(
            label,
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The Shop Now setup — "how far ahead?" — a bottom sheet that pulls future
/// lists forward; only what you actually buy is paid down.
class _ShopNowSheet extends StatefulWidget {
  const _ShopNowSheet();

  @override
  State<_ShopNowSheet> createState() => _ShopNowSheetState();
}

class _ShopNowSheetState extends State<_ShopNowSheet> {
  static const _options = [
    _AheadOption(label: 'This week only', items: 11, ahead: 0),
    _AheadOption(label: '+ 1 week ahead', items: 20, ahead: 1),
    _AheadOption(label: '+ 2 weeks ahead', items: 28, ahead: 2),
  ];

  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space12,
          KsTokens.space20,
          KsTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: KsTokens.space16),
                decoration: BoxDecoration(
                  color: ks.borderStrong,
                  borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                ),
              ),
            ),
            Text(
              'Shop how far ahead?',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 21,
                height: 1.15,
              ),
            ),
            const SizedBox(height: KsTokens.space6),
            Text(
              'Pull future lists forward — only what you actually buy is paid '
              'down.',
              style: KsTokens.bodySmall.copyWith(
                color: ks.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            for (var i = 0; i < _options.length; i++) ...[
              _AheadTile(
                option: _options[i],
                selected: i == _selected,
                onTap: () => setState(() => _selected = i),
              ),
              if (i != _options.length - 1) const SizedBox(height: 9),
            ],
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Build the list · ${_options[_selected].items} items',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AheadOption {
  const _AheadOption({
    required this.label,
    required this.items,
    required this.ahead,
  });

  final String label;
  final int items;
  final int ahead;
}

class _AheadTile extends StatelessWidget {
  const _AheadTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _AheadOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final fill = selected
        ? Color.alphaBlend(
            ks.brandPrimary.withValues(alpha: 0.14),
            ks.surfaceRaised,
          )
        : ks.surfaceRaised;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(
              color: selected ? ks.brandPrimary : ks.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 16, color: ks.brandPrimary),
                const SizedBox(width: KsTokens.space8),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
                ),
              ),
              Text(
                '${option.items} items',
                style: KsTokens.labelMedium.copyWith(
                  color: selected ? ks.brandPrimary : ks.textTertiary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
