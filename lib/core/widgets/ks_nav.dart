import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// One destination in the [KsBottomNav].
///
/// [activeIcon] is the filled twin shown when the destination is selected;
/// it falls back to [icon] when omitted.
@immutable
class KsNavDestination {
  const KsNavDestination({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
}

/// The running folio header — an uppercased eyebrow + a folio marker on the
/// same baseline, a Fraunces screen title beneath, and optional trailing
/// [actions] (search, the active member avatar).
///
/// Every primary screen wears this chrome so the app reads as one bound
/// volume. From "Components II (Modules)", Navigation & chrome. The eyebrow
/// takes the brand green on light and the warm accent on dark for contrast.
class KsFolioHeader extends StatelessWidget {
  const KsFolioHeader({
    required this.eyebrow,
    required this.title,
    this.actions = const [],
    super.key,
  });

  /// Uppercased running marker, e.g. `The Kitchen · 04`.
  final String eyebrow;

  /// The screen title, set in the display serif.
  final String title;

  /// Trailing chrome (search affordance, member avatar). Laid out in a row.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: KsTokens.space16,
      ),
      decoration: BoxDecoration(
        color: ks.surfaceBase,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eyebrow.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              if (actions.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions) ...[
                      action,
                      if (action != actions.last)
                        const SizedBox(width: KsTokens.space10),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            title,
            style: KsTokens.displayMedium.copyWith(
              color: ks.textPrimary,
              fontSize: 26,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular header action button — a glyph on a subtle neutral disc.
///
/// The search affordance in the folio header is the canonical use.
class KsHeaderAction extends StatelessWidget {
  const KsHeaderAction({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 30,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final button = Material(
      color: ks.neutralSubtle,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.53, color: ks.textSecondary),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// The five stable core tabs — the plan → shop → track spine that is identical
/// across every role and tier.
///
/// Selected destinations take the brand green with their filled glyph;
/// the rest sit in tertiary. From "Components II (Modules)", Navigation &
/// chrome. The fixed five live in [coreTabs].
class KsBottomNav extends StatelessWidget {
  const KsBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  /// The five stable core tabs shared across roles and tiers.
  static const List<KsNavDestination> coreTabs = [
    KsNavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Today',
    ),
    KsNavDestination(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'Calendar',
    ),
    KsNavDestination(
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      label: 'Shop',
    ),
    KsNavDestination(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Pantry',
    ),
    KsNavDestination(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      label: 'Recipes',
    ),
  ];

  final List<KsNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space6,
        vertical: KsTokens.space10,
      ),
      decoration: BoxDecoration(
        // Dark mode lifts the bar onto a higher surface container so it reads
        // above the scaffold; light mode keeps the clean raised white.
        color: isDark ? const Color(0xFF2F302A) : ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
        boxShadow: KsTokens.elevation1,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < destinations.length; i++)
            _NavItem(
              destination: destinations[i],
              selected: i == currentIndex,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final KsNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final color = selected ? ks.brandPrimary : ks.textTertiary;
    final icon = selected
        ? (destination.activeIcon ?? destination.icon)
        : destination.icon;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KsTokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: KsTokens.space4),
                Text(
                  destination.label,
                  style: KsTokens.labelSmall.copyWith(
                    color: color,
                    fontSize: 10,
                    letterSpacing: 0,
                    height: 1,
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
