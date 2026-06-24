import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// A rounded image thumbnail with a category-tinted placeholder fallback.
///
/// Used at 56px on pantry tiles and 44px on ingredient list tiles. The
/// placeholder fills with `categoryColor@15%` behind a `categoryColor@70%`
/// glyph. Callers apply their own surrounding padding.
class KsThumbnail extends StatelessWidget {
  const KsThumbnail({
    required this.categoryColor,
    this.imageUrl,
    this.size = 56,
    this.radius = KsTokens.radius12,
    this.icon = Icons.local_dining,
    this.iconSize = 24,
    super.key,
  });

  final Color categoryColor;
  final String? imageUrl;
  final double size;
  final double radius;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return SizedBox(
      width: size,
      height: size,
      child: url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              ),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    decoration: BoxDecoration(
      color: categoryColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(
      icon,
      size: iconSize,
      color: categoryColor.withValues(alpha: 0.7),
    ),
  );
}
