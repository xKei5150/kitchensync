import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// The persistent five-tab scaffold wrapping every primary surface
/// (Today · Calendar · Shop · Pantry · Recipes).
///
/// The shell keeps [KsBottomNav] pinned beneath an [IndexedStack] of branch
/// navigators so the app reads as one bound volume — the design's spine. Branch
/// state (scroll position, sub-routes) is preserved across tab switches.
class KsAppShell extends StatelessWidget {
  const KsAppShell({required this.navigationShell, super.key});

  /// The go_router navigation shell driving branch selection + state.
  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) {
    // Tapping the active tab pops it to its initial route; tapping another
    // switches branches without losing the previous branch's state.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
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
            destinations: KsBottomNav.coreTabs,
            currentIndex: navigationShell.currentIndex,
            onSelect: _onSelect,
          ),
        ),
      ),
    );
  }
}
