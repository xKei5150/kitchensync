import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// The persistent dashboard scaffold wrapping every primary surface
/// (Today · Recipes · Calendar · Shopping List · Pantry · Settings).
///
/// The shell keeps [KsBottomNav] pinned beneath an [IndexedStack] of branch
/// navigators so the app reads as one bound volume — the design's spine. Branch
/// state (scroll position, sub-routes) is preserved across tab switches.
class KsAppShell extends ConsumerWidget {
  const KsAppShell({required this.navigationShell, super.key});

  /// The go_router navigation shell driving branch selection + state.
  final StatefulNavigationShell navigationShell;

  void _onSelect(int branchIndex) {
    // Tapping the active tab pops it to its initial route; tapping another
    // switches branches without losing the previous branch's state.
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  /// Branch indexes for the destinations a household may see.
  ///
  /// Spec 1.7: "Menu Sets tab → show only if household has premium".
  @visibleForTesting
  static List<int> visibleBranchIndexes({required bool hasPremium}) => [
    for (var i = 0; i < KsBottomNav.coreTabs.length; i++)
      if (hasPremium || KsBottomNav.coreTabs[i].label != 'Menu Sets') i,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    // Spec 1.2 Step 5 lists Menu Sets among the dashboard tabs and spec 1.7
    // qualifies it: "Menu Sets tab → show only if household has premium". So
    // the destination is premium-gated rather than removed outright — a free
    // household still sees no Menu Sets tab (matching the intent of dropping it
    // from the primary nav), while a Premium household gets the tab the
    // specification requires. It also stays reachable by route from the
    // Calendar entry point and the Premium surface either way, and
    // `router_core.dart` independently redirects non-premium households away
    // from `/menu-sets`.
    //
    // Keeping the branch index (`i`) preserves the 1:1 alignment between
    // [KsBottomNav.coreTabs] and the shell branches.
    final household = ref.watch(activeHouseholdContextProvider);
    final branchIndexes = visibleBranchIndexes(
      hasPremium: household?.hasPremium ?? false,
    );
    final destinations = [
      for (final i in branchIndexes) KsBottomNav.coreTabs[i],
    ];
    final selectedIndex = branchIndexes.indexOf(navigationShell.currentIndex);
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space12,
            0,
            KsTokens.space12,
            KsTokens.space8,
          ),
          child: KsBottomNav(
            destinations: destinations,
            currentIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onSelect: (index) => _onSelect(branchIndexes[index]),
          ),
        ),
      ),
    );
  }
}
