import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item_photo.dart';
import 'package:kitchensync/features/pantry/domain/usecases/adjust_pantry_quantity.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/widgets/mark_as_waste_sheet.dart';

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
    final qty = QuantityFormatter.format(item.quantity);
    final unit = item.unit.name;
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(
          imageUrl: item.imageUrl,
          uploading: _uploadingPhoto,
          ingredient: ingredient,
          onTapPhoto: _pickAndUpload,
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
              const SizedBox(height: KsTokens.space16),
              KsQuantityStepper(
                qty: qty,
                unit: unit,
                onDecrease: () => _adjustQuantity(-1),
                onIncrease: () => _adjustQuantity(1),
              ),
              const SizedBox(height: KsTokens.space16),
              _MetadataCard(
                item: item,
                freshness: freshness,
                expiryLabel: expiryLabel,
                ingredient: ingredient,
              ),
              const SizedBox(height: KsTokens.space20),
              _ActionRow(item: item),
            ],
          ),
        ),
      ],
    );
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
  final VoidCallback onTapPhoto;
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
            label: imageUrl != null ? 'Change photo' : 'Add photo',
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
          if (expiryLabel.isNotEmpty) ...[
            const SizedBox(height: KsTokens.space12),
            KsMetadataRow(
              icon: freshness.icon,
              label: 'Freshness',
              value: expiryLabel,
              color: freshness.color,
            ),
          ],
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
              label: 'Note',
              value: item.note!,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// The thumb-zone action row — a calm Edit beside the filled, destructive
/// Mark-as-waste that opens the confirmation sheet.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: () {}, child: const Text('Edit')),
        ),
        const SizedBox(width: KsTokens.space10),
        Expanded(
          child: FilledButton(
            style: KsButtonStyles.destructive(context),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => MarkAsWasteSheet(item: item),
            ),
            child: const Text('Mark as waste'),
          ),
        ),
      ],
    );
  }
}
