import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/freshness_helper.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item_photo.dart';
import 'package:kitchensync/features/pantry/domain/usecases/adjust_pantry_quantity.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/widgets/mark_as_waste_sheet.dart';

class PantryItemDetailScreen extends ConsumerWidget {
  const PantryItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hid = ref.watch(activeHouseholdIdProvider);
    final itemAsync = ref.watch(pantryItemStreamProvider(hid, itemId));

    return Scaffold(
      appBar: AppBar(title: const Text('Item detail')),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Item not found.')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Item not found.'));
          }
          return _Body(item: item);
        },
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroPhoto(
            imageUrl: item.imageUrl,
            uploading: _uploadingPhoto,
            onTap: _pickAndUpload,
          ),
          Padding(
            padding: const EdgeInsets.all(KsTokens.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleRow(
                  name: ingredient?.displayNames['en'] ?? item.ingredientId,
                  ingredient: ingredient,
                ),
                const SizedBox(height: KsTokens.space20),
                _QuantityStepper(
                  qty: qty,
                  unit: unit,
                  onDecrease: () => _adjustQuantity(-1),
                  onIncrease: () => _adjustQuantity(1),
                ),
                const SizedBox(height: KsTokens.space20),
                _MetadataCard(
                  item: item,
                  freshness: freshness,
                  expiryLabel: expiryLabel,
                  ingredient: ingredient,
                ),
                const SizedBox(height: KsTokens.space24),
                _WasteButton(item: item),
                const SizedBox(height: KsTokens.space32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({this.imageUrl, this.uploading = false, this.onTap});

  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: imageUrl != null ? 'Change photo' : 'Add photo',
      child: GestureDetector(
        onTap: uploading ? null : onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: uploading
              ? Container(
                  color: KsTokens.neutralSubtle,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : imageUrl != null
              ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
              : Container(
                  color: KsTokens.neutralSubtle,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: KsTokens.textTertiary,
                      ),
                      const SizedBox(height: KsTokens.space8),
                      Text(
                        'Tap to add a photo',
                        style: KsTokens.bodyMedium.copyWith(
                          color: KsTokens.textTertiary,
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

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.name, this.ingredient});

  final String name;
  final Ingredient? ingredient;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.headlineMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (ingredient != null) ...[
                const SizedBox(height: KsTokens.space6),
                _CategoryTag(category: ingredient!.category),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final IngredientCategory category;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space8,
        vertical: KsTokens.space3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KsTokens.radius6),
      ),
      child: Text(
        category.name,
        style: KsTokens.labelSmall.copyWith(
          color: color.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.qty,
    required this.unit,
    this.onDecrease,
    this.onIncrease,
  });

  final String qty;
  final String unit;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space16,
        vertical: KsTokens.space12,
      ),
      decoration: BoxDecoration(
        color: KsTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: KsTokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: onDecrease,
            isDecrement: true,
          ),
          Column(
            children: [
              Text(qty, style: KsTokens.displayMedium),
              const SizedBox(height: KsTokens.space2),
              Text(
                unit,
                style: KsTokens.labelMedium.copyWith(
                  color: KsTokens.textTertiary,
                ),
              ),
            ],
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: onIncrease,
            isDecrement: false,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap, this.isDecrement = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool isDecrement;

  @override
  Widget build(BuildContext context) {
    final color = isDecrement ? KsTokens.lowStock : KsTokens.brandPrimary;
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: color, size: 22),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: KsTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: KsTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetadataRow(
            label: 'Section',
            value: _sectionLabel(item.section),
            color: item.section.color,
          ),
          if (expiryLabel.isNotEmpty) ...[
            const SizedBox(height: KsTokens.space12),
            _MetadataRow(
              label: 'Freshness',
              value: expiryLabel,
              color: freshness.color,
              showDot: true,
            ),
          ],
          if (item.lastPurchaseDate != null) ...[
            const SizedBox(height: KsTokens.space12),
            _MetadataRow(
              label: 'Last purchased',
              value: _formatDate(item.lastPurchaseDate!),
            ),
          ],
          if (ingredient?.defaultShelfLifeDays != null) ...[
            const SizedBox(height: KsTokens.space12),
            _MetadataRow(
              label: 'Typical shelf life',
              value: '${ingredient!.defaultShelfLifeDays} days',
            ),
          ],
          if (ingredient != null && ingredient!.allergens.isNotEmpty) ...[
            const SizedBox(height: KsTokens.space12),
            _MetadataRow(
              label: 'Allergens',
              value: ingredient!.allergens.map((a) => a.name).join(', '),
            ),
          ],
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: KsTokens.space12),
            _MetadataRow(label: 'Note', value: item.note!),
          ],
        ],
      ),
    );
  }

  String _sectionLabel(PantrySection section) => switch (section) {
    PantrySection.food => 'Food',
    PantrySection.bulk => 'Bulk',
    PantrySection.nonFood => 'Non-food',
    PantrySection.leftover => 'Leftovers',
  };

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.label,
    required this.value,
    this.color,
    this.showDot = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: KsTokens.bodySmall.copyWith(
              color: KsTokens.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (showDot && color != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: KsTokens.space6),
              ],
              Flexible(
                child: Text(
                  value,
                  style: KsTokens.bodyMedium.copyWith(
                    color: color ?? KsTokens.textPrimary,
                    fontWeight: color != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WasteButton extends StatelessWidget {
  const _WasteButton({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.delete_outline, size: 20),
        label: const Text('Mark as waste'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => MarkAsWasteSheet(item: item),
        ),
      ),
    );
  }
}
