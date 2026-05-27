import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo area — 16:9
          Semantics(
            button: true,
            label: item.imageUrl != null ? 'Change photo' : 'Add photo',
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _pickAndUpload,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _uploadingPhoto
                    ? const Center(child: CircularProgressIndicator())
                    : item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 48),
                            SizedBox(height: 8),
                            Text('Tap to add a photo'),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Quantity controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Decrease quantity',
                  icon: const Icon(Icons.remove),
                  onPressed: () => _adjustQuantity(-1),
                ),
                const SizedBox(width: 16),
                Text(
                  '$qty $unit',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  tooltip: 'Increase quantity',
                  icon: const Icon(Icons.add),
                  onPressed: () => _adjustQuantity(1),
                ),
              ],
            ),
          ),

          // Mark as waste
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Mark as waste'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => MarkAsWasteSheet(item: item),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
