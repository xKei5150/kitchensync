// SIZE_OK: pantry detail screen owns the existing item lifecycle surface.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';
import 'package:kitchensync/features/pantry/domain/services/pantry_unit_conversion.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item_photo.dart';
import 'package:kitchensync/features/pantry/domain/usecases/adjust_pantry_quantity.dart';
import 'package:kitchensync/features/pantry/domain/usecases/delete_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_consumption.dart';
import 'package:kitchensync/features/pantry/domain/usecases/update_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/widgets/mark_as_waste_sheet.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

/// Screen 08 · Pantry item detail — one item, fully told.
///
/// A category-tinted hero, freshness front and centre, the quantity stepper,
/// metadata, and the mark-as-waste action in the thumb zone. Wired to the live
/// pantry item stream; the hero doubles as the photo upload affordance.
class PantryItemDetailScreen extends ConsumerWidget {
  const PantryItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final hid = ref.watch(activeHouseholdIdProvider);
    final itemAsync = ref.watch(pantryItemStreamProvider(hid, itemId));

    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _NotFound(),
        data: (item) => item == null ? const _NotFound() : _Body(item: item),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          const Center(child: Text('Item not found.')),
          Padding(
            padding: const EdgeInsets.all(KsTokens.space8),
            child: _ScrimBackButton(onTap: () => context.pop(), onScrim: false),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.item});

  final PantryItem item;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _uploadingPhoto = false;

  Future<void> _pickAndUpload() async {
    if (!_hasFullPantryAccess()) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploadingPhoto = true);

    final hid = ref.read(activeHouseholdIdProvider);
    final useCase = ref.read(addPantryItemPhotoProvider);
    final result = await useCase(
      AddPantryItemPhotoParams(
        householdId: hid,
        itemId: widget.item.id,
        file: File(cropped.path),
      ),
    );

    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    if (result case ResultFailure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }

  Future<void> _adjustQuantity(double delta) async {
    if (!_can(HouseholdCapability.editPantryItems)) return;
    final hid = ref.read(activeHouseholdIdProvider);
    final useCase = ref.read(adjustPantryQuantityProvider);
    final result = await useCase(
      AdjustPantryQuantityParams(
        householdId: hid,
        itemId: widget.item.id,
        delta: delta,
      ),
    );
    if (!mounted) return;
    if (result case ResultFailure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final freshness = FreshnessHelper.fromExpiry(item.expiryDate);
    final expiryLabel = FreshnessHelper.relativeLabel(item.expiryDate);

    final ingredientAsync = ref.watch(
      pantryIngredientProvider(item.ingredientId),
    );
    final ingredient = ingredientAsync.when(
      data: (result) => switch (result) {
        Success(:final value) => value,
        ResultFailure() => null,
      },
      loading: () => null,
      error: (_, __) => null,
    );

    final name = ingredient?.displayNames['en'] ?? item.ingredientId;
    final sourceRecipeId = item.relatedRecipeId;
    final sourceRecipe = sourceRecipeId == null
        ? null
        : ref.watch(recipeRecordProvider(sourceRecipeId)).valueOrNull;
    final qty = QuantityFormatter.format(item.quantity);
    final unit = _unitLabel(
      item.unit,
      item.quantity,
      ingredient?.localUnitDefinitions ?? const <UnitDefinition>[],
    );
    final canConsume = _can(HouseholdCapability.markIngredientsConsumed);
    final canIncrease =
        _hasFullPantryAccess() && item.section != PantrySection.leftover;
    final canManagePhoto = _hasFullPantryAccess();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(
          imageUrl: item.imageUrl,
          uploading: _uploadingPhoto,
          ingredient: ingredient,
          onTapPhoto: canManagePhoto ? _pickAndUpload : null,
          onBack: () => context.pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space20,
            KsTokens.space16,
            KsTokens.space20,
            KsTokens.space32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ingredient != null)
                    KsTag.category(ingredient.category)
                  else
                    const SizedBox.shrink(),
                  if (expiryLabel.isNotEmpty)
                    KsExpiryBadge(freshness: freshness, label: expiryLabel),
                ],
              ),
              const SizedBox(height: KsTokens.space10),
              Text(
                name,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 28,
                  height: 1.05,
                  letterSpacing: -0.6,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: KsTokens.space2),
              Text(
                _subtitle(item),
                style: KsTokens.bodySmall.copyWith(
                  color: context.ksColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
              if (sourceRecipeId != null) ...[
                const SizedBox(height: KsTokens.space6),
                TextButton.icon(
                  onPressed: () => context.push('/recipe/$sourceRecipeId'),
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                  label: Text(
                    'Leftover from ${sourceRecipe?.name ?? sourceRecipeId}',
                  ),
                ),
              ],
              const SizedBox(height: KsTokens.space16),
              _QuantitySummaryCard(item: item, ingredient: ingredient),
              const SizedBox(height: KsTokens.space12),
              KsQuantityStepper(
                qty: qty,
                unit: unit,
                onDecrease: canConsume && item.quantity > 0
                    ? () => _adjustQuantity(-1)
                    : null,
                onIncrease: canIncrease ? () => _adjustQuantity(1) : null,
              ),
              const SizedBox(height: KsTokens.space16),
              _MetadataCard(
                item: item,
                freshness: freshness,
                expiryLabel: expiryLabel,
                ingredient: ingredient,
              ),
              const SizedBox(height: KsTokens.space20),
              _UsedByRecipesSection(item: item, ingredient: ingredient),
              const SizedBox(height: KsTokens.space20),
              _ActionRow(item: item),
            ],
          ),
        ),
      ],
    );
  }

  bool _can(HouseholdCapability capability) {
    final household = ref.read(activeHouseholdContextProvider);
    if (household == null) return false;
    return const HouseholdPolicy().roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    );
  }

  bool _hasFullPantryAccess() {
    final household = ref.read(activeHouseholdContextProvider);
    return household != null &&
        (household.isSolo || household.role == HouseholdRole.admin);
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _subtitle(PantryItem item) {
    final shelf = '${_sectionLabel(item.section)} shelf';
    final added = item.lastPurchaseDate;
    if (added == null) return 'in the $shelf';
    return 'added ${added.day} ${_months[added.month - 1]} · in the $shelf';
  }
}

String _sectionLabel(PantrySection section) => switch (section) {
  PantrySection.food => 'Food',
  PantrySection.bulk => 'Bulk',
  PantrySection.nonFood => 'Non-food',
  PantrySection.leftover => 'Leftover',
};

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _unitLabel(
  UnitId unit,
  double amount,
  List<UnitDefinition> localUnitDefinitions,
) {
  final definition =
      UnitRegistry.find(unit) ??
      _localUnitDefinition(unit, localUnitDefinitions);
  if (definition == null) return unit.value;
  return amount == 1 ? definition.label : definition.pluralLabel;
}

UnitDefinition? _localUnitDefinition(
  UnitId unit,
  List<UnitDefinition> localUnitDefinitions,
) {
  for (final definition in localUnitDefinitions) {
    if (definition.id == unit) return definition;
  }
  return null;
}

class _QuantitySummaryCard extends ConsumerWidget {
  const _QuantitySummaryCard({required this.item, required this.ingredient});

  final PantryItem item;
  final Ingredient? ingredient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurement = ref.watch(localeFormattersProvider).measurement;
    final value = measurement.formatUnit(
      item.quantity,
      item.unit,
      localUnitDefinitions:
          ingredient?.localUnitDefinitions ?? const <UnitDefinition>[],
    );
    return KsCard(
      child: KsMetadataRow(
        icon: Icons.scale_outlined,
        label: 'Current quantity',
        value: value,
        color: context.ksColors.brandPrimary,
      ),
    );
  }
}

/// The category-tinted hero — the item's photo when present, otherwise a
/// category gradient behind its glyph. Tapping anywhere opens the photo
/// picker; a circular back control rides the top-left.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.imageUrl,
    required this.uploading,
    required this.ingredient,
    required this.onTapPhoto,
    required this.onBack,
  });

  final String? imageUrl;
  final bool uploading;
  final Ingredient? ingredient;
  final VoidCallback? onTapPhoto;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final brightness = Theme.of(context).brightness;
    final category = ingredient?.category;
    final tint = category?.colorFor(brightness) ?? ks.brandPrimary;
    final raised = ks.surfaceRaised;

    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: onTapPhoto == null
                ? 'Pantry item photo'
                : imageUrl != null
                ? 'Change photo'
                : 'Add photo',
            child: GestureDetector(
              onTap: uploading ? null : onTapPhoto,
              child: _heroSurface(context, tint, raised),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(KsTokens.space16),
                child: _ScrimBackButton(
                  onTap: onBack,
                  onScrim: imageUrl != null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroSurface(BuildContext context, Color tint, Color raised) {
    final ks = context.ksColors;
    if (uploading) {
      return ColoredBox(
        color: ks.neutralSubtle,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (imageUrl != null) {
      return CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover);
    }
    final glyphColor = tint.readableInk(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(raised, tint, 0.38)!,
            Color.lerp(raised, tint, 0.16)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          ingredient?.category != null
              ? Icons.eco_outlined
              : Icons.local_dining,
          size: 56,
          color: glyphColor.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

/// A circular back control — translucent over photos, a neutral disc over the
/// category wash.
class _ScrimBackButton extends StatelessWidget {
  const _ScrimBackButton({required this.onTap, required this.onScrim});

  final VoidCallback onTap;
  final bool onScrim;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final bg = onScrim ? Colors.black.withValues(alpha: 0.3) : ks.surfaceRaised;
    final fg = onScrim ? Colors.white : ks.textPrimary;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: 'Back',
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.arrow_back_rounded, size: 18, color: fg),
          ),
        ),
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({
    required this.item,
    required this.freshness,
    required this.expiryLabel,
    this.ingredient,
  });

  final PantryItem item;
  final Freshness freshness;
  final String expiryLabel;
  final Ingredient? ingredient;

  @override
  Widget build(BuildContext context) {
    return KsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KsMetadataRow(
            icon: Icons.inventory_2_outlined,
            label: 'Section',
            value: _sectionLabel(item.section),
            color: item.section.color,
          ),
          if (item.expiryDate != null) ...[
            const SizedBox(height: KsTokens.space12),
            KsMetadataRow(
              icon: Icons.event_busy_outlined,
              label: 'Expiry date',
              value: _formatDate(item.expiryDate!),
            ),
          ],
          if (item.openedAt != null) ...[
            const SizedBox(height: KsTokens.space12),
            KsMetadataRow(
              icon: Icons.event_available_outlined,
              label: 'Opened date',
              value: _formatDate(item.openedAt!),
            ),
          ],
          const SizedBox(height: KsTokens.space12),
          KsMetadataRow(
            icon: freshness.icon,
            label: 'Freshness state',
            value: expiryLabel.isEmpty
                ? freshness.label
                : '${freshness.label} · $expiryLabel',
            color: freshness.color,
          ),
          if (item.lastPurchaseDate != null) ...[
            const SizedBox(height: KsTokens.space12),
            KsMetadataRow(
              icon: Icons.shopping_cart_outlined,
              label: 'Last purchased',
              value: _formatDate(item.lastPurchaseDate!),
            ),
          ],
          if (ingredient?.defaultShelfLifeDays != null) ...[
            const SizedBox(height: KsTokens.space12),
            KsMetadataRow(
              icon: Icons.schedule,
              label: 'Typical shelf life',
              value: '${ingredient!.defaultShelfLifeDays} days',
            ),
          ],
          if (ingredient != null && ingredient!.allergens.isNotEmpty) ...[
            const SizedBox(height: KsTokens.space12),
            KsMetadataRow(
              icon: Icons.warning_amber_rounded,
              label: 'Allergens',
              value: ingredient!.allergens.map((a) => a.name).join(', '),
            ),
          ],
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: KsTokens.space12),
            KsMetadataRow(
              icon: Icons.sticky_note_2_outlined,
              label: 'Notes',
              value: item.note!,
            ),
          ],
        ],
      ),
    );
  }
}

class _UsedByRecipesSection extends ConsumerWidget {
  const _UsedByRecipesSection({required this.item, this.ingredient});

  final PantryItem item;
  final Ingredient? ingredient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(activeHouseholdRecipesProvider);
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final mealsAsync = ref.watch(
      activeCalendarMealsProvider((start: DateTime(2000), end: end)),
    );

    return recipesAsync.when(
      loading: () => const _RecipeUsageLoadingCard(),
      error: (error, _) =>
          KsErrorAlert(message: 'Could not load recipe usage: $error'),
      data: (recipes) => mealsAsync.when(
        loading: () => const _RecipeUsageLoadingCard(),
        error: (error, _) =>
            KsErrorAlert(message: 'Could not load cooking history: $error'),
        data: (meals) => _RecipeUsageCard(
          usages: _buildUsages(recipes, meals),
          substituteIngredientIds:
              ingredient?.substituteIngredientIds ?? const [],
        ),
      ),
    );
  }

  List<_RecipeUsage> _buildUsages(
    List<Recipe> recipes,
    List<MealScheduleEntry> meals,
  ) {
    final cookedMeals = meals
        .where((meal) => meal.state == ScheduledMealState.cooked)
        .toList(growable: false);
    final usages = <_RecipeUsage>[];

    for (final recipe in recipes) {
      final usesIngredient = recipe.ingredients.any(
        (ingredient) => ingredient.ingredientId == item.ingredientId,
      );
      final relevantMeals = cookedMeals
          .where((meal) => meal.recipeId == recipe.id)
          .toList(growable: false);
      final usedSubstitutes = <String>{};

      for (final meal in relevantMeals) {
        for (final override in meal.ingredientOverrides) {
          if (override.originalIngredientId == item.ingredientId) {
            usedSubstitutes.add(override.substituteIngredientId);
          }
        }
      }

      if (!usesIngredient && usedSubstitutes.isEmpty) continue;

      usages.add(
        _RecipeUsage(
          recipe: recipe,
          lastCooked: _latestCookedDate(relevantMeals),
          substituteIngredientIds: usedSubstitutes.toList(growable: false),
        ),
      );
    }

    usages.sort((a, b) {
      final aDate = a.lastCooked;
      final bDate = b.lastCooked;
      if (aDate == null && bDate == null) {
        return a.recipe.name.compareTo(b.recipe.name);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return usages;
  }

  DateTime? _latestCookedDate(List<MealScheduleEntry> meals) {
    DateTime? latest;
    for (final meal in meals) {
      if (latest == null || meal.date.isAfter(latest)) {
        latest = meal.date;
      }
    }
    return latest;
  }
}

class _RecipeUsage {
  const _RecipeUsage({
    required this.recipe,
    required this.lastCooked,
    required this.substituteIngredientIds,
  });

  final Recipe recipe;
  final DateTime? lastCooked;
  final List<String> substituteIngredientIds;
}

class _RecipeUsageLoadingCard extends StatelessWidget {
  const _RecipeUsageLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const KsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KsSkeleton(width: 140, height: 16),
          SizedBox(height: KsTokens.space12),
          KsSkeleton(width: double.infinity, height: 44),
        ],
      ),
    );
  }
}

class _RecipeUsageCard extends StatelessWidget {
  const _RecipeUsageCard({
    required this.usages,
    required this.substituteIngredientIds,
  });

  final List<_RecipeUsage> usages;
  final List<String> substituteIngredientIds;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return KsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 18, color: ks.brandPrimary),
              const SizedBox(width: KsTokens.space8),
              Text(
                'Used by Recipes',
                style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          if (usages.isEmpty)
            Text(
              'No saved recipes use this pantry item yet.',
              style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
            )
          else
            for (final usage in usages) ...[
              _RecipeUsageTile(usage: usage),
              if (usage != usages.last)
                const SizedBox(height: KsTokens.space10),
            ],
          if (substituteIngredientIds.isNotEmpty) ...[
            const SizedBox(height: KsTokens.space12),
            _SubstituteOptions(ids: substituteIngredientIds),
          ],
        ],
      ),
    );
  }
}

class _RecipeUsageTile extends StatelessWidget {
  const _RecipeUsageTile({required this.usage});

  final _RecipeUsage usage;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final recipe = usage.recipe;
    final meta = [
      'Serves ${recipe.defaultServingSize}',
      if (recipe.mealTimeTags.isNotEmpty) recipe.mealTimeTags.first,
      if (usage.lastCooked != null)
        'Last cooked ${_formatDate(usage.lastCooked!)}',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/recipe/${recipe.id}'),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Container(
          padding: const EdgeInsets.all(KsTokens.space12),
          decoration: BoxDecoration(
            color: ks.surfaceSunken,
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: KsTokens.space8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ks.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space4),
              Text(
                meta,
                style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
              ),
              if (usage.substituteIngredientIds.isNotEmpty) ...[
                const SizedBox(height: KsTokens.space8),
                _UsedSubstitutes(ids: usage.substituteIngredientIds),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UsedSubstitutes extends ConsumerWidget {
  const _UsedSubstitutes({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: KsTokens.space6,
      runSpacing: KsTokens.space6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const KsTag(
          label: 'Used substitutes',
          icon: Icons.swap_horiz_rounded,
          tone: KsTagTone.outline,
          size: KsTagSize.sm,
        ),
        for (final id in ids) KsTag.alias(_ingredientName(ref, id)),
      ],
    );
  }
}

class _SubstituteOptions extends ConsumerWidget {
  const _SubstituteOptions({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: KsTokens.space6,
      runSpacing: KsTokens.space6,
      children: [
        const KsTag(
          label: 'Ingredient substitutes',
          icon: Icons.swap_calls_rounded,
          tone: KsTagTone.outline,
          size: KsTagSize.sm,
        ),
        for (final id in ids) KsTag.alias(_ingredientName(ref, id)),
      ],
    );
  }
}

String _ingredientName(WidgetRef ref, String id) {
  final async = ref.watch(pantryIngredientProvider(id));
  return async.when(
    data: (result) => switch (result) {
      Success(:final value) => value.displayNames['en'] ?? value.name,
      ResultFailure() => id,
    },
    loading: () => id,
    error: (_, __) => id,
  );
}

/// The thumb-zone action row — a calm Edit beside the filled, destructive
/// Mark-as-waste that opens the confirmation sheet.
class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(activeHouseholdContextProvider);
    const policy = HouseholdPolicy();
    bool can(HouseholdCapability capability) =>
        household == null ||
        policy.roleCan(
          household.role,
          capability,
          isSoloHousehold: household.isSolo,
        );
    final canEdit =
        item.section != PantrySection.leftover &&
        can(HouseholdCapability.editPantryItems);
    final canFullyEdit =
        household != null &&
        (household.isSolo || household.role == HouseholdRole.admin);
    final ingredient = switch (ref
        .watch(pantryIngredientProvider(item.ingredientId))
        .valueOrNull) {
      Success(:final value) => value,
      _ => null,
    };
    final canConsume = can(HouseholdCapability.markIngredientsConsumed);
    final canWaste = can(HouseholdCapability.markPantryWaste);
    final canDelete = can(HouseholdCapability.removePantryItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: canEdit
              ? () => _showEditDialog(
                  context,
                  ref,
                  ingredient: ingredient,
                  fullEdit: canFullyEdit,
                )
              : null,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit item'),
        ),
        const SizedBox(height: KsTokens.space8),
        OutlinedButton.icon(
          onPressed: canConsume && item.quantity > 0
              ? () => _markFullyUsed(context, ref)
              : null,
          icon: const Icon(Icons.done_all_rounded),
          label: const Text('Mark fully used'),
        ),
        const SizedBox(height: KsTokens.space8),
        OutlinedButton.icon(
          onPressed: () => context.push(
            '/ingredient/${item.ingredientId}'
            '?householdId=${Uri.encodeQueryComponent(item.householdId)}',
          ),
          icon: const Icon(Icons.info_outline_rounded),
          label: const Text('Ingredient details'),
        ),
        const SizedBox(height: KsTokens.space8),
        FilledButton.icon(
          style: KsButtonStyles.destructive(context),
          onPressed: canWaste
              ? () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => MarkAsWasteSheet(item: item),
                )
              : null,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Mark as waste'),
        ),
        const SizedBox(height: KsTokens.space8),
        TextButton.icon(
          onPressed: canDelete ? () => _delete(context, ref) : null,
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Delete item'),
        ),
      ],
    );
  }

  Future<void> _markFullyUsed(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Mark fully used?',
      body: 'This records ${item.quantity} ${item.unit.value} as consumption.',
      confirmLabel: 'Mark used',
    );
    if (!confirmed || !context.mounted) return;
    final result = await ref.read(recordConsumptionProvider)(
      RecordConsumptionParams(
        householdId: item.householdId,
        pantryItemId: item.id,
        quantity: item.quantity,
      ),
    );
    if (!context.mounted) return;
    _showResult(context, result, success: 'Usage recorded.');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete pantry item?',
      body: 'This removes the inventory record and cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final result = await ref.read(deletePantryItemProvider)(
      DeletePantryItemParams(
        householdId: item.householdId,
        itemId: item.id,
        force: true,
      ),
    );
    if (!context.mounted) return;
    if (result case Success<void>()) {
      context.pop();
    } else {
      _showResult(context, result, success: 'Deleted.');
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref, {
    required Ingredient? ingredient,
    required bool fullEdit,
  }) async {
    final quantity = TextEditingController(text: item.quantity.toString());
    final note = TextEditingController(text: item.note ?? '');
    var unit = item.unit;
    var section = item.section;
    var expiry = item.expiryDate;
    var opened = item.openedAt;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit pantry item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Quantity (${item.unit.value})',
                  ),
                ),
                if (fullEdit) ...[
                  DropdownButtonFormField<UnitId>(
                    initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [
                      for (final value
                          in ingredient?.allowedUnits ?? [item.unit])
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            _unitLabel(
                              value,
                              double.tryParse(quantity.text) ?? item.quantity,
                              ingredient?.localUnitDefinitions ?? const [],
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == unit) return;
                      final currentQuantity =
                          double.tryParse(quantity.text.trim()) ??
                          item.quantity;
                      final converted = PantryUnitConversion.preserveAmount(
                        quantity: currentQuantity,
                        from: unit,
                        to: value,
                      );
                      setState(() {
                        unit = value;
                        quantity.text = _editableQuantity(converted);
                      });
                    },
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  DropdownButtonFormField<PantrySection>(
                    initialValue: section,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: [
                      for (final value in PantrySection.values.where(
                        (value) => value != PantrySection.leftover,
                      ))
                        DropdownMenuItem(
                          value: value,
                          child: Text(_sectionLabel(value)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => section = value ?? section),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiry date'),
                    subtitle: Text(
                      expiry == null ? 'Unknown' : _formatDate(expiry!),
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: expiry ?? DateTime.now(),
                      );
                      if (picked != null) setState(() => expiry = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Opened date'),
                    subtitle: Text(
                      opened == null ? 'Not recorded' : _formatDate(opened!),
                    ),
                    trailing: const Icon(Icons.event_available_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: opened ?? DateTime.now(),
                      );
                      if (picked != null) setState(() => opened = picked);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final parsed = double.tryParse(quantity.text.trim());
    if (saved != true || parsed == null || !context.mounted) return;
    final household = ref.read(activeHouseholdContextProvider);
    if (household?.role == HouseholdRole.cook && parsed > item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cooks can record usage but cannot add pantry stock.'),
        ),
      );
      return;
    }
    final decreaseAudit = household?.role == HouseholdRole.shopper
        ? QuantityDecreaseAudit.correction
        : QuantityDecreaseAudit.consumption;
    final result = await ref.read(updatePantryItemProvider)(
      UpdatePantryItemParams(
        item: item.copyWith(
          quantity: parsed,
          unit: unit,
          section: section,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          expiryDate: expiry,
          openedAt: opened,
          updatedAt: DateTime.now(),
        ),
        decreaseAudit: decreaseAudit,
      ),
    );
    if (context.mounted) _showResult(context, result, success: 'Item updated.');
  }

  static String _editableQuantity(double value) =>
      value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  static void _showResult<T>(
    BuildContext context,
    Result<T> result, {
    required String success,
  }) {
    final message = switch (result) {
      Success<T>() => success,
      ResultFailure<T>(:final failure) => failure.toString(),
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
