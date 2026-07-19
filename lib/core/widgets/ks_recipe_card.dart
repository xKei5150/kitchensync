import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

enum KsRecipeVariant { private, public }

/// A recipe card in one of two variants.
///
/// [KsRecipeCard.private] (My Recipes) carries edit / delete affordances;
/// [KsRecipeCard.public] (Discover) carries a per-serving price, a save
/// bookmark, an author byline, and like + comment counts. The two variants are
/// visually distinct so private and shared recipes never blur. From
/// "Components II (Modules)", Recipe card · two variants.
class KsRecipeCard extends StatelessWidget {
  const KsRecipeCard._({
    required this.variant,
    required this.title,
    this.meta,
    this.author,
    this.price,
    this.priceUnit = '/serving',
    this.likeCount,
    this.commentCount,
    this.saved = false,
    this.coverColors,
    this.onEdit,
    this.onDelete,
    this.deleteIcon = Icons.delete_outline,
    this.deleteTooltip = 'Delete',
    this.onSave,
    super.key,
  });

  /// A private card — title, prep meta, and edit / delete actions.
  const KsRecipeCard.private({
    required String title,
    String? meta,
    List<Color>? coverColors,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    IconData deleteIcon = Icons.delete_outline,
    String deleteTooltip = 'Delete',
    Key? key,
  }) : this._(
         variant: KsRecipeVariant.private,
         title: title,
         meta: meta,
         coverColors: coverColors,
         onEdit: onEdit,
         onDelete: onDelete,
         deleteIcon: deleteIcon,
         deleteTooltip: deleteTooltip,
         key: key,
       );

  /// A public card — title, author byline, per-serving price, save bookmark,
  /// and like + comment counts.
  const KsRecipeCard.public({
    required String title,
    required String author,
    required String price,
    String priceUnit = '/serving',
    int likeCount = 0,
    int commentCount = 0,
    bool saved = false,
    List<Color>? coverColors,
    VoidCallback? onSave,
    Key? key,
  }) : this._(
         variant: KsRecipeVariant.public,
         title: title,
         author: author,
         price: price,
         priceUnit: priceUnit,
         likeCount: likeCount,
         commentCount: commentCount,
         saved: saved,
         coverColors: coverColors,
         onSave: onSave,
         key: key,
       );

  final KsRecipeVariant variant;
  final String title;
  final String? meta;
  final String? author;
  final String? price;
  final String priceUnit;
  final int? likeCount;
  final int? commentCount;
  final bool saved;

  /// Two category hues for the cover gradient. Defaults differ per variant.
  final List<Color>? coverColors;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final IconData deleteIcon;
  final String deleteTooltip;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
        boxShadow: KsTokens.elevation1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _cover(context),
            Padding(
              padding: const EdgeInsets.all(13),
              child: variant == KsRecipeVariant.private
                  ? _privateBody(context)
                  : _publicBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(BuildContext context) {
    final ks = context.ksColors;
    final raised = ks.surfaceRaised;
    final defaults = variant == KsRecipeVariant.private
        ? [KsTokens.catGrain, KsTokens.catSpice]
        : [KsTokens.catProduce, KsTokens.catBeverage];
    final base = coverColors ?? defaults;
    final start = Color.lerp(raised, base.first, 0.32)!;
    final end = Color.lerp(raised, base.last, 0.24)!;

    return SizedBox(
      height: 108,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [start, end],
                ),
              ),
            ),
          ),
          if (variant == KsRecipeVariant.private)
            Positioned(top: 10, left: 10, child: _minePill(context))
          else ...[
            Positioned(top: 10, right: 10, child: _saveButton(context)),
            Positioned(bottom: 10, left: 10, child: _pricePill(context)),
          ],
        ],
      ),
    );
  }

  Widget _minePill(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space8,
        vertical: KsTokens.space4,
      ),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
      ),
      child: Text(
        'MINE',
        style: KsTokens.labelSmall.copyWith(
          color: ks.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1,
        ),
      ),
    );
  }

  Widget _saveButton(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSave,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            size: 16,
            color: saved ? ks.brandPrimary : ks.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _pricePill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? KsTokens.brandAccent : KsTokens.brandPrimaryDark;
    final textColor = isDark ? KsTokens.textPrimary : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space10,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            price ?? '',
            style: KsTokens.headlineMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1,
            ),
          ),
          Text(
            ' $priceUnit',
            style: KsTokens.labelSmall.copyWith(
              color: textColor.withValues(alpha: 0.85),
              fontSize: 9,
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _privateBody(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: KsTokens.headlineMedium.copyWith(
            color: ks.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            height: 1.15,
          ),
        ),
        if (meta != null) ...[
          const SizedBox(height: 3),
          Text(
            meta!,
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
        if (onEdit != null || onDelete != null) ...[
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              if (onEdit != null)
                Expanded(
                  child: _CardButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                  ),
                ),
              if (onEdit != null && onDelete != null)
                const SizedBox(width: KsTokens.space8),
              if (onDelete != null)
                _CardButton(
                  icon: deleteIcon,
                  tooltip: deleteTooltip,
                  danger: deleteTooltip == 'Delete',
                  onTap: onDelete,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _publicBody(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: KsTokens.headlineMedium.copyWith(
            color: ks.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'by ${author ?? ''}',
          style: KsTokens.labelSmall.copyWith(
            color: ks.textTertiary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            _Stat(
              icon: Icons.favorite,
              iconColor: ks.danger,
              value: '${likeCount ?? 0}',
            ),
            const SizedBox(width: KsTokens.space16),
            _Stat(
              icon: Icons.mode_comment_outlined,
              iconColor: ks.textSecondary,
              value: '${commentCount ?? 0}',
            ),
          ],
        ),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    this.label,
    this.icon,
    this.tooltip,
    this.danger = false,
    this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final color = danger ? ks.danger : ks.textPrimary;
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: label != null ? KsTokens.space12 : 11,
        vertical: 9,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, size: 13, color: color),
          if (icon != null && label != null)
            const SizedBox(width: KsTokens.space4),
          if (label != null)
            Text(
              label!,
              style: KsTokens.labelMedium.copyWith(
                color: color,
                letterSpacing: 0,
                height: 1,
              ),
            ),
        ],
      ),
    );

    final button = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: ks.borderStrong),
        borderRadius: BorderRadius.circular(KsTokens.radius8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: KsTokens.space4),
        Text(
          value,
          style: KsTokens.labelMedium.copyWith(
            color: ks.textSecondary,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ],
    );
  }
}
