import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';

/// The persistent dashboard scaffold wrapping every primary surface
/// (Today · Recipes · Calendar · Shopping List · Pantry · Menu Sets ·
/// Settings).
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final household = ref.watch(activeHouseholdContextProvider);
    const policy = HouseholdPolicy();
    final showMenuSets = policy.canShowMenuSetsTab(
      householdHasPremium: household?.hasPremium ?? false,
    );
    final branchIndexes = [
      for (var i = 0; i < KsBottomNav.coreTabs.length; i++)
        if (showMenuSets || KsBottomNav.coreTabs[i].label != 'Menu Sets') i,
    ];
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
