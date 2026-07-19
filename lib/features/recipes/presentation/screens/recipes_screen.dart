// SIZE_OK: recipes screen is pre-existing broad CRUD/search UI surface.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_social_models.dart';
import 'package:kitchensync/features/recipes/domain/services/recipe_import_parser.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

/// Result of the recipe editor sheet. [fromPaste] is true when the drafts came
/// from the Premium Paste & Parse bulk-import surface (Feature Design 2.4.2),
/// so the caller can route them through the Premium-gated import path.
class RecipeEditorResult {
  const RecipeEditorResult({required this.drafts, required this.fromPaste});

  final List<RecipeDraft> drafts;
  final bool fromPaste;
}

Future<RecipeEditorResult?> showRecipeEditorSheet(
  BuildContext context, {
  Recipe? existingRecipe,
}) {
  return showModalBottomSheet<RecipeEditorResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _RecipeImportSheet(
      existingRecipe: existingRecipe,
      routeContext: context,
    ),
  );
}

/// Screen 07 · Recipes home — My Recipes & Discover.
///
/// Two tabs over the shared chrome: Discover carries the premium budget +
/// target-servings search and a grid of public recipe cards; My Recipes shows
/// repository-backed household recipes and local copies.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

enum _RecipesTab { mine, discover }

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const _policy = HouseholdPolicy();
  _RecipesTab _tab = _RecipesTab.discover;

  Future<void> _openAddRecipeSheet() async {
    final result = await showRecipeEditorSheet(context);
    if (result == null || result.drafts.isEmpty || !mounted) {
      return;
    }
    try {
      final controller = ref.read(recipeImportControllerProvider);
      if (result.fromPaste) {
        await controller.importParsedDrafts(result.drafts);
      } else {
        await controller.importDrafts(result.drafts);
      }
      if (!mounted) {
        return;
      }
      setState(() => _tab = _RecipesTab.mine);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import recipes: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(activeHouseholdContextProvider);
    final canCreate =
        household != null &&
        _policy.roleCan(
          household.role,
          HouseholdCapability.createRecipes,
          isSoloHousehold: household.isSolo,
        );
    final header = KsFolioHeader(
      eyebrow: 'The Cookbook',
      title: 'Recipes',
      actions: [
        if (canCreate)
          KsHeaderAction(
            icon: Icons.add_rounded,
            tooltip: 'Add recipe',
            onTap: _openAddRecipeSheet,
          ),
        const KsHeaderAction(icon: Icons.search_rounded),
      ],
    );
    return SafeArea(
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
            child: header,
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
                onAdd: canCreate ? _openAddRecipeSheet : null,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _MyRecipe {
  const _MyRecipe({
    required this.record,
    required this.id,
    required this.title,
    required this.meta,
    required this.colors,
  });

  factory _MyRecipe.fromRecipe(Recipe recipe) {
    final visibility = recipe.visibility == RecipeVisibility.public
        ? 'Public'
        : 'Private';
    return _MyRecipe(
      record: recipe,
      id: recipe.id,
      title: recipe.name,
      meta: '$visibility · Serves ${recipe.defaultServingSize}',
      colors: _colorsForTags(recipe.recipeTags),
    );
  }

  final Recipe record;
  final String id;
  final String title;
  final String meta;
  final List<Color> colors;

  static List<Color> _colorsForTags(List<String> tags) {
    final joined = tags.join(' ').toLowerCase();
    if (joined.contains('chicken') || joined.contains('meat')) {
      return [KsTokens.catMeat, KsTokens.catSpice];
    }
    if (joined.contains('fried') || joined.contains('comfort')) {
      return [KsTokens.catBaking, KsTokens.catGrain];
    }
    if (joined.contains('lentil') || joined.contains('budget')) {
      return [KsTokens.catGrain, KsTokens.catProduce];
    }
    return [KsTokens.catProduce, KsTokens.catCondiment];
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

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(localeFormattersProvider).currency;
    final filter = ref.watch(publicRecipeSearchFilterProvider);
    final recipesAsync = ref.watch(publicRecipeSearchProvider);
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
        _DiscoverFilterChips(filter: filter),
        const SizedBox(height: KsTokens.space16),
        recipesAsync.when(
          data: (recipes) => _PublicRecipeGrid(
            recipes: recipes,
            filter: filter,
            formatPrice: currency.format,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.only(top: KsTokens.space24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              KsErrorAlert(message: 'Could not search public recipes: $error'),
        ),
      ],
    );
  }
}

class _DiscoverFilterChips extends ConsumerWidget {
  const _DiscoverFilterChips({required this.filter});

  final RecipeSearchFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(localeFormattersProvider).currency;
    if (!filter.isCompletePremiumFilter) {
      return const Wrap(
        spacing: KsTokens.space8,
        runSpacing: KsTokens.space8,
        children: [
          KsTag(
            label: 'Public recipes',
            icon: Icons.public_rounded,
            tone: KsTagTone.outline,
          ),
        ],
      );
    }

    return Wrap(
      spacing: KsTokens.space8,
      runSpacing: KsTokens.space8,
      children: [
        KsTag(
          label: 'Under ${currency.format(filter.budget!, decimals: false)}',
          icon: Icons.bolt_rounded,
          tone: KsTagTone.outline,
        ),
        KsTag(
          label: 'Serves ${filter.targetServings}',
          icon: Icons.bolt_rounded,
          tone: KsTagTone.outline,
        ),
      ],
    );
  }
}

class _PublicRecipeGrid extends StatelessWidget {
  const _PublicRecipeGrid({
    required this.recipes,
    required this.filter,
    required this.formatPrice,
  });

  final List<Recipe> recipes;
  final RecipeSearchFilter filter;
  final String Function(double value, {bool decimals}) formatPrice;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: KsTokens.space32),
        child: KsEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No public recipes found',
          subtitle: 'Try relaxing the budget or serving filters.',
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recipes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: KsTokens.space10,
        mainAxisSpacing: KsTokens.space10,
        childAspectRatio: 0.63,
      ),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _PublicRecipeTile(
          recipe: recipe,
          price: _priceLabel(recipe),
          priceUnit: filter.targetServings == null
              ? '/recipe'
              : 'for ${filter.targetServings}',
        );
      },
    );
  }

  String _priceLabel(Recipe recipe) {
    final servings = filter.targetServings;
    final price = servings == null
        ? recipe.priceEstimate
        : recipe.priceForServings(servings);
    if (price == null) {
      return 'N/A';
    }
    return formatPrice(price);
  }
}

class _PublicRecipeTile extends ConsumerWidget {
  const _PublicRecipeTile({
    required this.recipe,
    required this.price,
    required this.priceUnit,
  });

  final Recipe recipe;
  final String price;
  final String priceUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialAsync = ref.watch(recipeSocialStateProvider(recipe.id));
    final social = socialAsync.valueOrNull ?? RecipeSocialState.empty;
    final savedRecipe = ref.watch(savedRecipeForSourceProvider(recipe.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/recipe/${recipe.id}'),
            child: KsRecipeCard.public(
              key: ValueKey('public-recipe-${recipe.id}'),
              title: recipe.name,
              author: recipe.authorUserId,
              price: price,
              priceUnit: priceUnit,
              saved: savedRecipe != null,
              coverColors: _MyRecipe._colorsForTags(recipe.recipeTags),
              onSave: () => _toggleSaved(context, ref, savedRecipe),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: Row(
            children: [
              IconButton(
                onPressed: socialAsync.hasError
                    ? null
                    : () => _setLiked(context, ref, !social.likedByViewer),
                tooltip: social.likedByViewer ? 'Unlike recipe' : 'Like recipe',
                icon: Icon(
                  social.likedByViewer
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
              ),
              Text('${social.likeCount}'),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/recipe/${recipe.id}'),
                tooltip: 'View comments',
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              ),
              Text('${social.commentCount}'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setLiked(
    BuildContext context,
    WidgetRef ref,
    bool liked,
  ) async {
    try {
      await ref
          .read(recipeSocialControllerProvider)
          .setLiked(recipeId: recipe.id, liked: liked);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update like: $error')),
        );
      }
    }
  }

  Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    SavedRecipe? savedRecipe,
  ) async {
    try {
      if (savedRecipe == null) {
        await ref
            .read(recipeDiscoveryControllerProvider)
            .savePublicRecipe(recipe);
      } else {
        await ref
            .read(recipeDiscoveryControllerProvider)
            .unsavePublicRecipe(savedRecipe);
      }
      ref.invalidate(activeHouseholdRecipesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedRecipe == null
                ? '${recipe.name} saved to My Recipes'
                : '${recipe.name} removed from My Recipes',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update saved recipe: $error')),
      );
    }
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

class _MyRecipesTab extends ConsumerWidget {
  const _MyRecipesTab({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(activeHouseholdRecipesProvider);
    final savedRecipes =
        ref.watch(activeSavedRecipesProvider).valueOrNull ?? const [];
    final household = ref.watch(activeHouseholdContextProvider);
    const policy = HouseholdPolicy();
    final canManage =
        household != null &&
        policy.roleCan(
          household.role,
          HouseholdCapability.editRecipes,
          isSoloHousehold: household.isSolo,
        );
    return recipesAsync.when(
      data: (recipes) => _MyRecipeGrid(
        recipes: recipes.map(_MyRecipe.fromRecipe).toList(growable: false),
        onAdd: onAdd,
        canManage: canManage,
        savedRecipes: savedRecipes,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(KsTokens.space16),
        child: KsErrorAlert(message: 'Could not load recipes: $error'),
      ),
    );
  }
}

class _MyRecipeGrid extends ConsumerWidget {
  const _MyRecipeGrid({
    required this.recipes,
    required this.onAdd,
    required this.canManage,
    required this.savedRecipes,
  });

  final List<_MyRecipe> recipes;
  final VoidCallback? onAdd;
  final bool canManage;
  final List<SavedRecipe> savedRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (recipes.isEmpty) {
      return Center(
        child: KsEmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Your shelf of recipes is bare',
          subtitle:
              'Save one from Discover, or paste a recipe you already love.',
          action: onAdd == null
              ? null
              : FilledButton(
                  onPressed: onAdd,
                  child: const Text('Add a recipe'),
                ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space12,
        KsTokens.space16,
        KsTokens.space24,
      ),
      children: [
        if (onAdd != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add a recipe'),
            ),
          ),
          const SizedBox(height: KsTokens.space12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recipes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: KsTokens.space10,
            mainAxisSpacing: KsTokens.space10,
            childAspectRatio: 0.76,
          ),
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            final savedRecipe = _savedRecipeForLocalCopy(recipe.record);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/recipe/${recipe.id}'),
              child: KsRecipeCard.private(
                title: recipe.title,
                meta: recipe.meta,
                coverColors: recipe.colors,
                onEdit: canManage
                    ? () => _editRecipe(context, ref, recipe.record)
                    : null,
                onDelete: savedRecipe != null
                    ? () => _unsaveRecipe(
                        context,
                        ref,
                        recipe.record,
                        savedRecipe,
                      )
                    : canManage
                    ? () => _deleteRecipe(context, ref, recipe.record)
                    : null,
                deleteIcon: savedRecipe == null
                    ? Icons.delete_outline
                    : Icons.bookmark_remove_outlined,
                deleteTooltip: savedRecipe == null ? 'Delete' : 'Unsave',
              ),
            );
          },
        ),
      ],
    );
  }

  SavedRecipe? _savedRecipeForLocalCopy(Recipe recipe) {
    if (recipe.sourceRecipeId == null) return null;
    for (final saved in savedRecipes) {
      if (saved.localRecipeId == recipe.id &&
          saved.sourceRecipeId == recipe.sourceRecipeId) {
        return saved;
      }
    }
    return null;
  }

  Future<void> _unsaveRecipe(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    SavedRecipe savedRecipe,
  ) async {
    try {
      await ref
          .read(recipeDiscoveryControllerProvider)
          .unsavePublicRecipe(savedRecipe);
      ref.invalidate(activeHouseholdRecipesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${recipe.name} removed from My Recipes')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unsave recipe: $error')),
      );
    }
  }

  Future<void> _editRecipe(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final result = await showRecipeEditorSheet(context, existingRecipe: recipe);
    if (result == null || result.drafts.isEmpty) {
      return;
    }
    try {
      final updated = await ref
          .read(recipeLibraryControllerProvider)
          .updateLocalRecipe(recipe: recipe, draft: result.drafts.single);
      ref.invalidate(activeHouseholdRecipesProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${updated.name} updated')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update recipe: $error')),
      );
    }
  }

  Future<void> _deleteRecipe(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    try {
      await ref.read(recipeLibraryControllerProvider).deleteLocalRecipe(recipe);
      ref.invalidate(activeHouseholdRecipesProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${recipe.name} deleted from My Recipes')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete recipe: $error')),
      );
    }
  }
}

class _RecipeImportSheet extends ConsumerStatefulWidget {
  const _RecipeImportSheet({this.existingRecipe, required this.routeContext});

  final Recipe? existingRecipe;
  final BuildContext routeContext;

  @override
  ConsumerState<_RecipeImportSheet> createState() => _RecipeImportSheetState();
}

class _RecipeImportSheetState extends ConsumerState<_RecipeImportSheet> {
  static const _template = '''
=== RECIPE START ===
Name: Fried Chicken
Servings: 4
Time Tags: Lunch, Dinner
Recipe Tags: Chicken, Fried, Comfort Food
Price Estimate: 250
Ingredients:
- Chicken Thighs | 1 kg | pcs
- Flour | 2 cups | cup
- Salt | 1 tbsp | tbsp
- Oil | 500 ml | ml
Instructions:
1. Mix flour and salt.
2. Coat chicken.
3. Fry until golden.
YouTube: https://youtu.be/example
Access: Private
=== RECIPE END ===''';

  final _parser = const RecipeImportParser();
  late final TextEditingController _pasteController;
  late final TextEditingController _nameController;
  late final TextEditingController _servingsController;
  late final TextEditingController _timeTagsController;
  late final TextEditingController _recipeTagsController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _priceController;
  late final TextEditingController _youtubeController;
  final List<_ManualIngredientInput> _ingredientRows = [];
  int _nextIngredientRowId = 0;
  RecipeVisibility _visibility = RecipeVisibility.private;
  bool _pasteMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final recipe = widget.existingRecipe;
    _pasteController = TextEditingController(text: _template.trim());
    _nameController = TextEditingController(text: recipe?.name ?? '');
    _servingsController = TextEditingController(
      text: '${recipe?.defaultServingSize ?? 4}',
    );
    _timeTagsController = TextEditingController(
      text: recipe?.mealTimeTags.join(', ') ?? 'Dinner',
    );
    _recipeTagsController = TextEditingController(
      text: recipe?.recipeTags.join(', ') ?? '',
    );
    _descriptionController = TextEditingController(
      text: recipe?.description ?? '',
    );
    _instructionsController = TextEditingController(
      text: recipe?.instructions.join('\n') ?? '',
    );
    _priceController = TextEditingController(
      text: recipe?.priceEstimate?.toString() ?? '',
    );
    _youtubeController = TextEditingController(
      text: recipe?.youtubeEmbedUrl?.toString() ?? '',
    );
    _visibility = recipe?.visibility ?? RecipeVisibility.private;
    if (recipe == null || recipe.ingredients.isEmpty) {
      _ingredientRows.add(_createIngredientRow());
    } else {
      for (final ingredient in recipe.ingredients) {
        _ingredientRows.add(_createIngredientRow(ingredient: ingredient));
      }
      _hydrateExistingIngredientUnits();
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    _nameController.dispose();
    _servingsController.dispose();
    _timeTagsController.dispose();
    _recipeTagsController.dispose();
    _descriptionController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    _instructionsController.dispose();
    _priceController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_pasteMode || widget.existingRecipe != null) {
      _saveManual();
      return;
    }
    final result = _parser.parse(_pasteController.text);
    if (result.drafts.isEmpty) {
      setState(() => _error = result.errors.join('\n'));
      return;
    }
    Navigator.of(
      context,
    ).pop(RecipeEditorResult(drafts: result.drafts, fromPaste: true));
  }

  void _saveManual() {
    final name = _nameController.text.trim();
    final servings = int.tryParse(_servingsController.text.trim());
    final ingredientDrafts = <RecipeIngredientDraft>[];
    var ingredientError = false;
    for (final row in _ingredientRows) {
      final ingredientName = row.nameController.text.trim();
      final quantityText = row.quantityController.text.trim();
      final ingredientQuantity = double.tryParse(quantityText);
      final hasAnyInput =
          ingredientName.isNotEmpty ||
          quantityText.isNotEmpty ||
          row.noteController.text.trim().isNotEmpty ||
          row.ingredientId != null;
      if (!hasAnyInput) {
        continue;
      }
      if (ingredientName.isEmpty) {
        ingredientError = true;
        setState(() => _error = 'Every ingredient needs a name.');
        break;
      }
      if (ingredientQuantity == null || ingredientQuantity <= 0) {
        ingredientError = true;
        setState(
          () => _error = 'Every ingredient quantity must be a positive number.',
        );
        break;
      }
      ingredientDrafts.add(
        RecipeIngredientDraft(
          ingredientId: row.linkedIngredientIdFor(ingredientName),
          name: ingredientName,
          quantity: ingredientQuantity,
          unit: row.unit,
          preparationNote: row.noteController.text.trim().isEmpty
              ? null
              : row.noteController.text.trim(),
        ),
      );
    }
    final instructions = _splitLines(_instructionsController.text);
    final price = _priceController.text.trim().isEmpty
        ? null
        : double.tryParse(_priceController.text.trim());
    final youtube = _youtubeController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    if (servings == null || servings <= 0) {
      setState(
        () => _error = 'Default serving size must be a positive number.',
      );
      return;
    }
    if (ingredientError) {
      return;
    }
    if (ingredientDrafts.isEmpty) {
      setState(() => _error = 'At least one ingredient name is required.');
      return;
    }
    if (instructions.isEmpty) {
      setState(() => _error = 'At least one instruction is required.');
      return;
    }
    if (_priceController.text.trim().isNotEmpty && price == null) {
      setState(() => _error = 'Price estimate must be numeric.');
      return;
    }
    if (_visibility == RecipeVisibility.public && price == null) {
      setState(() => _error = 'Public recipes require a price estimate.');
      return;
    }

    final draft = RecipeDraft(
      name: name,
      defaultServingSize: servings,
      timeTags: _splitCsv(_timeTagsController.text),
      recipeTags: _splitCsv(_recipeTagsController.text),
      description: _descriptionController.text.trim(),
      ingredients: List.unmodifiable(ingredientDrafts),
      instructions: instructions,
      visibility: _visibility,
      priceEstimate: price,
      youtubeUrl: youtube.isEmpty ? null : Uri.tryParse(youtube),
    );
    Navigator.of(
      context,
    ).pop(RecipeEditorResult(drafts: [draft], fromPaste: false));
  }

  _ManualIngredientInput _createIngredientRow({RecipeIngredient? ingredient}) {
    return _ManualIngredientInput(
      id: _nextIngredientRowId++,
      ingredientId: ingredient?.ingredientId,
      linkedName: ingredient?.description,
      nameController: TextEditingController(
        text: ingredient?.description ?? '',
      ),
      quantityController: TextEditingController(
        text: ingredient == null ? '1' : '${ingredient.quantity}',
      ),
      noteController: TextEditingController(
        text: ingredient?.preparationNote ?? '',
      ),
      unit: ingredient?.unit ?? UnitId.g,
      localUnits: _unitDefinitionsForIngredient(ingredient),
    );
  }

  void _addIngredientRow() {
    setState(() {
      _ingredientRows.add(_createIngredientRow());
      _error = null;
    });
  }

  void _removeIngredientRow(_ManualIngredientInput row) {
    if (_ingredientRows.length == 1) {
      return;
    }
    setState(() {
      _ingredientRows.remove(row);
      row.dispose();
      _error = null;
    });
  }

  Future<void> _pickIngredient(_ManualIngredientInput row) async {
    final ingredient = await widget.routeContext.push<Ingredient>(
      '/ingredient/pick',
    );
    if (!mounted || ingredient == null) {
      return;
    }
    setState(() {
      final displayName = ingredient.displayNames['en'] ?? ingredient.name;
      row
        ..ingredientId = ingredient.id
        ..nameController.text = displayName
        ..linkedName = displayName
        ..unit = ingredient.defaultUnit
        ..localUnits = _unitDefinitionsFor(ingredient);
      _error = null;
    });
  }

  Future<void> _hydrateExistingIngredientUnits() async {
    final rows = _ingredientRows
        .where(
          (row) => row.ingredientId != null && row.ingredientId!.isNotEmpty,
        )
        .toList(growable: false);
    if (rows.isEmpty) {
      return;
    }
    final repository = ref.read(ingredientRepositoryProvider);
    final householdId = ref.read(activeHouseholdIdProvider);
    for (final row in rows) {
      final ingredient = await repository.getById(
        row.ingredientId!,
        householdId: householdId,
      );
      if (!mounted || ingredient == null) {
        continue;
      }
      setState(() {
        row.localUnits = _unitDefinitionsFor(ingredient);
      });
    }
  }

  List<UnitDefinition> _unitDefinitionsForIngredient(
    RecipeIngredient? ingredient,
  ) {
    final ingredientId = ingredient?.ingredientId;
    if (ingredientId == null || ingredientId.isEmpty) {
      return const [];
    }
    final unit = ingredient!.unit;
    final fallback =
        UnitRegistry.find(unit) ??
        UnitDefinition(
          id: unit,
          label: unit.value,
          pluralLabel: unit.value,
          dimension: UnitDimension.informal,
          family: UnitSystemFamily.local,
        );
    return [fallback];
  }

  List<UnitDefinition> _unitDefinitionsFor(Ingredient ingredient) {
    final byId = <UnitId, UnitDefinition>{
      for (final unit in ingredient.localUnitDefinitions) unit.id: unit,
    };
    return [
      for (final unit in ingredient.allowedUnits)
        byId[unit] ??
            UnitRegistry.find(unit) ??
            UnitDefinition(
              id: unit,
              label: unit.value,
              pluralLabel: unit.value,
              dimension: UnitDimension.informal,
              family: UnitSystemFamily.local,
            ),
    ];
  }

  List<String> _splitCsv(String value) => value
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);

  List<String> _splitLines(String value) => value
      .split('\n')
      .map((line) => line.trim().replaceFirst(RegExp(r'^\d+\.\s*'), ''))
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space12,
          KsTokens.space20,
          KsTokens.space20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ks.borderStrong,
                  borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            Text(
              widget.existingRecipe == null ? 'Add a recipe' : 'Edit recipe',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: KsTokens.space12),
            if (widget.existingRecipe == null) ...[
              _ImportModeRow(
                icon: Icons.edit_note_rounded,
                title: 'Manual recipe',
                subtitle: 'Name, servings, tags, ingredients and instructions',
                selected: !_pasteMode,
                onTap: () => setState(() {
                  _pasteMode = false;
                  _error = null;
                }),
              ),
              const SizedBox(height: KsTokens.space8),
              _ImportModeRow(
                icon: Icons.auto_awesome_rounded,
                title: 'Paste & Parse',
                subtitle: 'Bulk import one or more marked recipe blocks',
                selected: _pasteMode,
                onTap: () => setState(() {
                  _pasteMode = true;
                  _error = null;
                }),
              ),
              const SizedBox(height: KsTokens.space12),
            ],
            if (_pasteMode)
              TextField(
                controller: _pasteController,
                minLines: 10,
                maxLines: 14,
                style: KsTokens.bodySmall.copyWith(
                  color: ks.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: _inputDecoration(context),
              )
            else
              _ManualRecipeFields(
                nameController: _nameController,
                servingsController: _servingsController,
                timeTagsController: _timeTagsController,
                recipeTagsController: _recipeTagsController,
                descriptionController: _descriptionController,
                ingredientRows: _ingredientRows,
                instructionsController: _instructionsController,
                priceController: _priceController,
                youtubeController: _youtubeController,
                visibility: _visibility,
                onAddIngredient: _addIngredientRow,
                onRemoveIngredient: _removeIngredientRow,
                onPickIngredient: _pickIngredient,
                onUnitChanged: (row, unit) => setState(() => row.unit = unit),
                onVisibilityChanged: (visibility) =>
                    setState(() => _visibility = visibility),
              ),
            if (_error != null) ...[
              const SizedBox(height: KsTokens.space10),
              KsErrorAlert(message: _error!),
            ],
            const SizedBox(height: KsTokens.space12),
            FilledButton(
              onPressed: _save,
              child: Text(
                _pasteMode && widget.existingRecipe == null
                    ? 'Import recipes'
                    : widget.existingRecipe == null
                    ? 'Save recipe'
                    : 'Update recipe',
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final ks = context.ksColors;
    return InputDecoration(
      filled: true,
      fillColor: ks.surfaceBase,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
    );
  }
}

class _ManualIngredientInput {
  _ManualIngredientInput({
    required this.id,
    TextEditingController? nameController,
    TextEditingController? quantityController,
    TextEditingController? noteController,
    this.unit = UnitId.g,
    List<UnitDefinition> localUnits = const [],
    this.ingredientId,
    this.linkedName,
  }) : nameController = nameController ?? TextEditingController(),
       quantityController = quantityController ?? TextEditingController(),
       noteController = noteController ?? TextEditingController(),
       localUnits = List<UnitDefinition>.unmodifiable(localUnits);

  final int id;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController noteController;
  UnitId unit;
  List<UnitDefinition> localUnits;
  String? ingredientId;
  String? linkedName;

  String? linkedIngredientIdFor(String currentName) {
    final id = ingredientId;
    final name = linkedName;
    if (id == null || name == null) {
      return null;
    }
    return currentName.trim().toLowerCase() == name.trim().toLowerCase()
        ? id
        : null;
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    noteController.dispose();
  }
}

class _ImportModeRow extends StatelessWidget {
  const _ImportModeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return InkWell(
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(KsTokens.space12),
        decoration: BoxDecoration(
          color: selected
              ? ks.brandPrimary.withValues(alpha: 0.08)
              : ks.surfaceSunken,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          border: Border.all(color: selected ? ks.brandPrimary : ks.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ks.brandPrimary),
            const SizedBox(width: KsTokens.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KsTokens.labelMedium.copyWith(
                      color: ks.textPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: KsTokens.bodySmall.copyWith(
                      color: ks.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: ks.brandPrimary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _ManualRecipeFields extends StatelessWidget {
  const _ManualRecipeFields({
    required this.nameController,
    required this.servingsController,
    required this.timeTagsController,
    required this.recipeTagsController,
    required this.descriptionController,
    required this.ingredientRows,
    required this.instructionsController,
    required this.priceController,
    required this.youtubeController,
    required this.visibility,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
    required this.onPickIngredient,
    required this.onUnitChanged,
    required this.onVisibilityChanged,
  });

  final TextEditingController nameController;
  final TextEditingController servingsController;
  final TextEditingController timeTagsController;
  final TextEditingController recipeTagsController;
  final TextEditingController descriptionController;
  final List<_ManualIngredientInput> ingredientRows;
  final TextEditingController instructionsController;
  final TextEditingController priceController;
  final TextEditingController youtubeController;
  final RecipeVisibility visibility;
  final VoidCallback onAddIngredient;
  final ValueChanged<_ManualIngredientInput> onRemoveIngredient;
  final ValueChanged<_ManualIngredientInput> onPickIngredient;
  final void Function(_ManualIngredientInput row, UnitId unit) onUnitChanged;
  final ValueChanged<RecipeVisibility> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ManualTextField(controller: nameController, label: 'Name'),
        const SizedBox(height: KsTokens.space8),
        Row(
          children: [
            Expanded(
              child: _ManualTextField(
                controller: servingsController,
                label: 'Default serving size',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: KsTokens.space8),
            Expanded(
              child: _ManualTextField(
                controller: priceController,
                label: 'Price estimate',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space8),
        _ManualTextField(
          controller: timeTagsController,
          label: 'Time tags',
          hintText: 'Breakfast, Lunch, Dinner',
        ),
        const SizedBox(height: KsTokens.space8),
        _ManualTextField(
          controller: recipeTagsController,
          label: 'Recipe tags',
          hintText: 'Cuisine, diet, category',
        ),
        const SizedBox(height: KsTokens.space8),
        _ManualTextField(
          controller: descriptionController,
          label: 'Description',
          minLines: 2,
          maxLines: 3,
        ),
        const SizedBox(height: KsTokens.space8),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ingredients',
                  style: KsTokens.labelMedium.copyWith(letterSpacing: 0),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAddIngredient,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add ingredient'),
            ),
          ],
        ),
        for (final row in ingredientRows) ...[
          _ManualIngredientFields(
            row: row,
            canRemove: ingredientRows.length > 1,
            onRemove: () => onRemoveIngredient(row),
            onPick: () => onPickIngredient(row),
            onUnitChanged: (unit) => onUnitChanged(row, unit),
          ),
          const SizedBox(height: KsTokens.space8),
        ],
        const SizedBox(height: KsTokens.space8),
        _ManualTextField(
          controller: instructionsController,
          label: 'Instructions',
          hintText: 'One step per line',
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: KsTokens.space8),
        _ManualTextField(
          controller: youtubeController,
          label: 'YouTube embed',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: KsTokens.space8),
        SegmentedButton<RecipeVisibility>(
          segments: const [
            ButtonSegment(
              value: RecipeVisibility.private,
              label: Text('Private'),
              icon: Icon(Icons.lock_outline_rounded),
            ),
            ButtonSegment(
              value: RecipeVisibility.public,
              label: Text('Public'),
              icon: Icon(Icons.public_rounded),
            ),
          ],
          selected: {visibility},
          onSelectionChanged: (selection) =>
              onVisibilityChanged(selection.single),
        ),
      ],
    );
  }
}

class _ManualIngredientFields extends StatelessWidget {
  const _ManualIngredientFields({
    required this.row,
    required this.canRemove,
    required this.onRemove,
    required this.onPick,
    required this.onUnitChanged,
  });

  final _ManualIngredientInput row;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPick;
  final ValueChanged<UnitId> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ManualTextField(
                controller: row.nameController,
                label: 'Ingredient name',
              ),
            ),
            const SizedBox(width: KsTokens.space8),
            IconButton.filledTonal(
              tooltip: 'Pick ingredient',
              onPressed: onPick,
              icon: const Icon(Icons.search_rounded, size: 18),
            ),
            if (canRemove) ...[
              const SizedBox(width: KsTokens.space4),
              IconButton(
                tooltip: 'Remove ingredient',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ],
        ),
        const SizedBox(height: KsTokens.space8),
        Row(
          children: [
            Expanded(
              child: _ManualTextField(
                controller: row.quantityController,
                label: 'Quantity',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: KsTokens.space8),
            Expanded(
              child: DropdownButtonFormField<UnitId>(
                key: ValueKey('ingredient-unit-${row.id}-${row.unit.value}'),
                initialValue: row.unit,
                decoration: _manualDecoration(context, 'Unit'),
                items: [
                  for (final unit in _unitOptions(row))
                    DropdownMenuItem(value: unit.id, child: Text(unit.label)),
                ],
                onChanged: (unit) {
                  if (unit != null) {
                    onUnitChanged(unit);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: KsTokens.space8),
        _ManualTextField(
          controller: row.noteController,
          label: 'Preparation note',
        ),
      ],
    );
  }
}

List<UnitDefinition> _unitOptions(_ManualIngredientInput row) {
  final selectedUnit = row.unit;
  final byId =
      <UnitId, UnitDefinition>{
        for (final unit in UnitRegistry.builtIns) unit.id: unit,
        for (final unit in row.localUnits) unit.id: unit,
      }..putIfAbsent(
        selectedUnit,
        () =>
            UnitRegistry.find(selectedUnit) ??
            UnitDefinition(
              id: selectedUnit,
              label: selectedUnit.value,
              pluralLabel: selectedUnit.value,
              dimension: UnitDimension.informal,
              family: UnitSystemFamily.local,
            ),
      );
  return List<UnitDefinition>.unmodifiable(byId.values);
}

class _ManualTextField extends StatelessWidget {
  const _ManualTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: _manualDecoration(context, label, hintText: hintText),
    );
  }
}

InputDecoration _manualDecoration(
  BuildContext context,
  String label, {
  String? hintText,
}) {
  final ks = context.ksColors;
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    filled: true,
    fillColor: ks.surfaceBase,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(KsTokens.radius12),
    ),
  );
}
