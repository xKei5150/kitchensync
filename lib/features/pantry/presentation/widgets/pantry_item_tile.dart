import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

class PantryItemTile extends ConsumerWidget {
  const PantryItemTile({required this.item, this.onTap, super.key});

  final PantryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(getIngredientProvider)(item.ingredientId),
      builder: (context, snapshot) {
        final name = switch (snapshot.data) {
          Success(:final value) =>
            value.displayNames['en'] ?? item.ingredientId,
          _ => item.ingredientId,
        };

        final qty = QuantityFormatter.format(item.quantity);
        final unit = item.unit.name;
        final semanticLabel = '$name $qty $unit';

        return Semantics(
          label: semanticLabel,
          button: onTap != null,
          child: ListTile(
            leading: _LeadingImage(imageUrl: item.imageUrl),
            title: Text(name),
            subtitle: _buildSubtitle(context, qty, unit),
            onTap: onTap,
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(BuildContext context, String qty, String unit) {
    final expiry = item.expiryDate;
    final base = '$qty $unit';
    final label = expiry != null
        ? '$base • expires ${expiry.year.toString().padLeft(4, '0')}'
              '-${expiry.month.toString().padLeft(2, '0')}'
              '-${expiry.day.toString().padLeft(2, '0')}'
        : base;
    return Text(label);
  }
}

class _LeadingImage extends StatelessWidget {
  const _LeadingImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    const radius = BorderRadius.all(Radius.circular(8));
    if (imageUrl case final url?) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(size),
          errorWidget: (_, __, ___) => _placeholder(size),
        ),
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: const Icon(Icons.kitchen),
    );
  }
}
