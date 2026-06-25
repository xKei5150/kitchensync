import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 07 · Recipes home — My Recipes & Discover.
///
/// Two tabs over the shared chrome: Discover carries the premium budget +
/// target-servings search and a grid of public recipe cards; My Recipes wears
/// the load-bearing empty state until the household saves its first recipe.
/// Presentational P1 with representative sample data.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

enum _RecipesTab { mine, discover }

class _RecipesScreenState extends State<RecipesScreen> {
  _RecipesTab _tab = _RecipesTab.discover;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              KsTokens.space16,
              KsTokens.space8,
              KsTokens.space16,
              0,
            ),
            child: KsFolioHeader(
              eyebrow: 'The Cookbook',
              title: 'Recipes',
              actions: [KsHeaderAction(icon: Icons.search_rounded)],
            ),
          ),
          const SizedBox(height: KsTokens.space12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KsTokens.space16),
            child: _TabBar(
              tab: _tab,
              onSelect: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _RecipesTab.discover => const _DiscoverTab(),
              _RecipesTab.mine => _MyRecipesTab(
                onAdd: () => setState(() => _tab = _RecipesTab.discover),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// The My Recipes / Discover underline tabs.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final _RecipesTab tab;
  final ValueChanged<_RecipesTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ks.border)),
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'My Recipes',
            selected: tab == _RecipesTab.mine,
            onTap: () => onSelect(_RecipesTab.mine),
          ),
          const SizedBox(width: KsTokens.space20),
          _TabItem(
            label: 'Discover',
            selected: tab == _RecipesTab.discover,
            onTap: () => onSelect(_RecipesTab.discover),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? ks.brandPrimary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: KsTokens.space10),
            child: Text(
              label,
              style: KsTokens.titleSmall.copyWith(
                color: selected ? ks.textPrimary : ks.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One discoverable recipe in the sample feed.
class _DiscoverRecipe {
  const _DiscoverRecipe({
    required this.title,
    required this.author,
    required this.price,
    required this.likes,
    required this.comments,
    required this.colors,
  });

  final String title;
  final String author;
  final String price;
  final int likes;
  final int comments;
  final List<Color> colors;
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();

  static const _recipes = [
    _DiscoverRecipe(
      title: 'Charred greens orzo',
      author: 'mira',
      price: '£3.20',
      likes: 248,
      comments: 12,
      colors: [KsTokens.catProduce, KsTokens.catBeverage],
    ),
    _DiscoverRecipe(
      title: 'Sunday lentil dal',
      author: 'theo',
      price: '£2.10',
      likes: 512,
      comments: 33,
      colors: [KsTokens.catGrain, KsTokens.catSpice],
    ),
    _DiscoverRecipe(
      title: 'Roast squash & sage',
      author: 'priya',
      price: '£3.80',
      likes: 176,
      comments: 8,
      colors: [KsTokens.catSpice, KsTokens.catGrain],
    ),
    _DiscoverRecipe(
      title: 'White bean braise',
      author: 'sam',
      price: '£2.60',
      likes: 401,
      comments: 21,
      colors: [KsTokens.catProduce, KsTokens.catCondiment],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space12,
        KsTokens.space16,
        KsTokens.space24,
      ),
      children: [
        const _SearchPill(),
        const SizedBox(height: KsTokens.space10),
        const Wrap(
          spacing: KsTokens.space8,
          runSpacing: KsTokens.space8,
          children: [
            KsTag(
              label: 'Under £4',
              icon: Icons.bolt_rounded,
              tone: KsTagTone.outline,
            ),
            KsTag(
              label: 'Serves 4',
              icon: Icons.bolt_rounded,
              tone: KsTagTone.outline,
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recipes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: KsTokens.space10,
            mainAxisSpacing: KsTokens.space10,
            childAspectRatio: 0.74,
          ),
          itemBuilder: (context, index) {
            final r = _recipes[index];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/recipe'),
              child: KsRecipeCard.public(
                title: r.title,
                author: r.author,
                price: r.price,
                likeCount: r.likes,
                commentCount: r.comments,
                coverColors: r.colors,
                onSave: () {},
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The tap-to-search field — a calm pill that reads as an affordance.
class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Semantics(
      button: true,
      label: 'Search recipes',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: KsTokens.space10,
        ),
        decoration: BoxDecoration(
          color: ks.surfaceRaised,
          borderRadius: BorderRadius.circular(KsTokens.radius10),
          border: Border.all(color: ks.borderStrong),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: ks.textTertiary),
            const SizedBox(width: 9),
            Text(
              'Search recipes…',
              style: KsTokens.bodyMedium.copyWith(color: ks.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRecipesTab extends StatelessWidget {
  const _MyRecipesTab({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: KsEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'Your shelf of recipes is bare',
        subtitle: 'Save one from Discover, or paste a recipe you already love.',
        action: FilledButton(
          onPressed: onAdd,
          child: const Text('Add a recipe'),
        ),
      ),
    );
  }
}
