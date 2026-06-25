import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 11 · Menu Sets home — a deck of weeks you can re-live.
///
/// A horizontal carousel, deliberately unlike every vertical list in the app:
/// each [KsMenuSetCard] previews its seven days. Premium P2; the content is
/// representative sample data, exactly as the design canvas frames it.
class MenuSetsScreen extends ConsumerStatefulWidget {
  const MenuSetsScreen({super.key});

  @override
  ConsumerState<MenuSetsScreen> createState() => _MenuSetsScreenState();
}

class _MenuSetsScreenState extends ConsumerState<MenuSetsScreen> {
  // viewportFraction keeps the next card peeking, so the row reads as a deck.
  final _controller = PageController(viewportFraction: 0.86);
  int _page = 0;

  static final List<_MenuSetSample> _sets = [
    _MenuSetSample(
      title: 'Cosy autumn week',
      metaPrefix: '7 days · 14 meals',
      priceValue: 61,
      days: const [
        KsMenuDay(weekday: 'M', dishColors: [KsTokens.catGrain]),
        KsMenuDay(weekday: 'T', dishColors: [KsTokens.catMeat]),
        KsMenuDay(weekday: 'W', dishColors: [KsTokens.catProduce]),
        KsMenuDay(weekday: 'T', dishColors: [KsTokens.catSeafood]),
        KsMenuDay(weekday: 'F', dishColors: [KsTokens.catSpice]),
        KsMenuDay(weekday: 'S', dishColors: [KsTokens.catProduce]),
        KsMenuDay(weekday: 'S', dishColors: [KsTokens.catBakery]),
      ],
    ),
    _MenuSetSample(
      title: 'Quick weeknights',
      metaPrefix: '5 days · 10 meals',
      priceValue: 38,
      days: const [
        KsMenuDay(weekday: 'M', dishColors: [KsTokens.catSeafood]),
        KsMenuDay(weekday: 'T', dishColors: [KsTokens.catProduce]),
        KsMenuDay(weekday: 'W', dishColors: [KsTokens.catMeat]),
        KsMenuDay(weekday: 'T', dishColors: [KsTokens.catGrain]),
        KsMenuDay(weekday: 'F', dishColors: [KsTokens.catSpice]),
        KsMenuDay(weekday: 'S', dishColors: []),
        KsMenuDay(weekday: 'S', dishColors: []),
      ],
    ),
    _MenuSetSample(
      title: 'Batch-cook Sunday',
      metaPrefix: '6 days · 12 meals',
      priceValue: 47,
      days: const [
        KsMenuDay(weekday: 'M', dishColors: [KsTokens.catGrain]),
        KsMenuDay(weekday: 'T', dishColors: [KsTokens.catGrain]),
        KsMenuDay(weekday: 'W', dishColors: [KsTokens.catProduce]),
        KsMenuDay(weekday: 'T', dishColors: [KsTokens.catMeat]),
        KsMenuDay(weekday: 'F', dishColors: [KsTokens.catSeafood]),
        KsMenuDay(weekday: 'S', dishColors: [KsTokens.catBakery]),
        KsMenuDay(weekday: 'S', dishColors: []),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openEditor() => context.push('/menu-sets/edit');

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final currency = ref.watch(localeFormattersProvider).currency;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space16,
                KsTokens.space8,
                KsTokens.space16,
                0,
              ),
              child: KsFolioHeader(
                eyebrow: 'Premium · Menu Sets',
                title: 'A deck of weeks',
                actions: [
                  KsHeaderAction(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => context.pop(),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, KsTokens.space12, 20, 0),
              child: _Subhead('Reuse a week you loved.'),
            ),
            const SizedBox(height: KsTokens.space16),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _sets.length,
                itemBuilder: (context, i) {
                  final set = _sets[i];
                  final meta =
                      '${set.metaPrefix} · '
                      '${currency.format(set.priceValue, decimals: false)}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: KsMenuSetCard(
                        title: set.title,
                        meta: meta,
                        days: set.days,
                        onApply: _openEditor,
                        onDuplicate: _openEditor,
                      ),
                    ),
                  );
                },
              ),
            ),
            _PageDots(count: _sets.length, active: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space16,
                KsTokens.space8,
                KsTokens.space16,
                KsTokens.space20,
              ),
              child: _SaveAsSetButton(onTap: _openEditor),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSetSample {
  _MenuSetSample({
    required this.title,
    required this.metaPrefix,
    required this.priceValue,
    required this.days,
  });

  final String title;

  /// Everything in the summary line before the cost, e.g. `7 days · 14 meals`.
  final String metaPrefix;

  /// Estimated set cost; formatted in the active currency at build time.
  final double priceValue;
  final List<KsMenuDay> days;
}

class _Subhead extends StatelessWidget {
  const _Subhead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: KsTokens.displaySmall.copyWith(
        color: context.ksColors.textSecondary,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        height: 1.3,
      ),
    );
  }
}

/// The carousel pager — a stretched pill for the active page, dots otherwise.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: KsTokens.durationFast,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == active ? ks.brandPrimary : ks.borderStrong,
              borderRadius: BorderRadius.circular(KsTokens.radiusFull),
            ),
          ),
      ],
    );
  }
}

/// The dashed "Save this week as a set" call to action.
class _SaveAsSetButton extends StatelessWidget {
  const _SaveAsSetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return KsDashedBorder(
      color: ks.borderStrong,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: ks.textSecondary),
                const SizedBox(width: KsTokens.space8),
                Text(
                  'Save this week as a set',
                  style: KsTokens.labelLarge.copyWith(
                    color: ks.textSecondary,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
